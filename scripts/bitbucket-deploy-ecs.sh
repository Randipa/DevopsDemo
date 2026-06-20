#!/usr/bin/env bash
# Shared ECS deploy script for Bitbucket Pipelines (and local CLI)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

ENV_KEY="${1:-dev}"
case "${ENV_KEY}" in
  dev|development) ENV_KEY=dev; DEPLOY_ENV=development ;;
  test|testing) ENV_KEY=test; DEPLOY_ENV=testing ;;
  stage|staging) ENV_KEY=stage; DEPLOY_ENV=stage ;;
  prod|production) ENV_KEY=prod; DEPLOY_ENV=production ;;
  *)
    echo "Usage: BUILD_IMAGE=true|false IMAGE_TAG=tag $0 [dev|test|stage|prod]"
    exit 1
    ;;
esac

AWS_REGION="${AWS_REGION:-eu-north-1}"
export AWS_DEFAULT_REGION="${AWS_REGION}"
STACK_NAME="devops-ecs-${ENV_KEY}"
APP_NAME="devops-demo-${ENV_KEY}"
BASE_ECR_REPO="devops-demo"
ECS_CLUSTER="devops-demo-${ENV_KEY}-cluster"
ECS_SERVICE="devops-demo-${ENV_KEY}-service"
CONTAINER_NAME="app"
BUILD_IMAGE="${BUILD_IMAGE:-false}"
IMAGE_TAG="${IMAGE_TAG:-dev-latest}"
COMMIT_TAG="${BITBUCKET_COMMIT:-${GITHUB_SHA:-local}}"

echo "==> Bitbucket/ECS deploy: ${DEPLOY_ENV} (${STACK_NAME})"

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  echo "ERROR: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (Bitbucket repository variables)."
  exit 1
fi

ensure_ecr() {
  if aws ecr describe-repositories \
    --region "${AWS_REGION}" \
    --repository-names "${BASE_ECR_REPO}" >/dev/null 2>&1; then
    echo "ECR repository ${BASE_ECR_REPO} exists."
  else
    echo "Creating ECR repository ${BASE_ECR_REPO}..."
    aws ecr create-repository \
      --region "${AWS_REGION}" \
      --repository-name "${BASE_ECR_REPO}" \
      --image-scanning-configuration scanOnPush=true
  fi
}

ensure_stack() {
  set +e
  STATUS=$(aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null)
  if [[ "${STATUS}" == "ROLLBACK_COMPLETE" ]] || [[ "${STATUS}" == "ROLLBACK_FAILED" ]] || [[ "${STATUS}" == "CREATE_FAILED" ]]; then
    echo "Stack ${STACK_NAME} failed (${STATUS}). Delete in CloudFormation and retry."
    exit 1
  fi
  set -e

  aws cloudformation deploy \
    --region "${AWS_REGION}" \
    --template-file infra/cloudformation-ecs-simple.yaml \
    --stack-name "${STACK_NAME}" \
    --parameter-overrides \
      AppName="${APP_NAME}" \
      Environment="${ENV_KEY}" \
      BaseECRRepo="${BASE_ECR_REPO}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset

  aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].Outputs' \
    --output table
}

ecr_login() {
  ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
  ECR_REGISTRY="${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REGISTRY}"
  echo "${ECR_REGISTRY}"
}

build_and_push_image() {
  local registry="$1"
  npm ci
  npm test
  docker build -t "${registry}/${BASE_ECR_REPO}:${COMMIT_TAG}" .
  docker tag "${registry}/${BASE_ECR_REPO}:${COMMIT_TAG}" \
    "${registry}/${BASE_ECR_REPO}:dev-latest"
  docker push "${registry}/${BASE_ECR_REPO}:${COMMIT_TAG}"
  docker push "${registry}/${BASE_ECR_REPO}:dev-latest"
  echo "${registry}/${BASE_ECR_REPO}:${COMMIT_TAG}"
}

resolve_promoted_image() {
  local registry="$1"
  aws ecr describe-images \
    --region "${AWS_REGION}" \
    --repository-name "${BASE_ECR_REPO}" \
    --image-ids "imageTag=${IMAGE_TAG}" >/dev/null
  echo "${registry}/${BASE_ECR_REPO}:${IMAGE_TAG}"
}

register_task_and_deploy() {
  local image_uri="$1"

  aws ecs describe-task-definition \
    --region "${AWS_REGION}" \
    --task-definition "${APP_NAME}" \
    --query taskDefinition > task-def.json

  python3 <<PY
import json
with open("task-def.json") as f:
    td = json.load(f)
for key in (
    "taskDefinitionArn", "revision", "status", "requiresAttributes",
    "compatibilities", "registeredAt", "registeredBy",
):
    td.pop(key, None)
for container in td.get("containerDefinitions", []):
    if container.get("name") == "${CONTAINER_NAME}":
        container["image"] = "${image_uri}"
with open("new-task-def.json", "w") as f:
    json.dump(td, f)
PY

  NEW_TASK_ARN=$(aws ecs register-task-definition \
    --region "${AWS_REGION}" \
    --cli-input-json file://new-task-def.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

  aws ecs update-service \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --task-definition "${NEW_TASK_ARN}" \
    --desired-count 1 \
    --force-new-deployment >/dev/null

  aws ecs wait services-stable \
    --region "${AWS_REGION}" \
    --cluster "${ECS_CLUSTER}" \
    --services "${ECS_SERVICE}"
}

print_urls() {
  ALB=$(aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
    --output text)
  HEALTH="http://${ALB}/health"
  INFO="http://${ALB}/api/info"
  echo ""
  echo "=========================================="
  echo " Environment : ${DEPLOY_ENV}"
  echo " Health URL  : ${HEALTH}"
  echo " Info URL    : ${INFO}"
  echo "=========================================="
  curl -sf "${HEALTH}" | head -c 500 || true
  echo ""
}

ensure_ecr
ensure_stack

if [[ "${SETUP_INFRA_ONLY:-false}" == "true" ]]; then
  echo "Infra-only setup complete for ${DEPLOY_ENV}."
  exit 0
fi

REGISTRY="$(ecr_login)"

if [[ "${BUILD_IMAGE}" == "true" ]]; then
  IMAGE_URI="$(build_and_push_image "${REGISTRY}")"
else
  IMAGE_URI="$(resolve_promoted_image "${REGISTRY}")"
fi

register_task_and_deploy "${IMAGE_URI}"
print_urls
