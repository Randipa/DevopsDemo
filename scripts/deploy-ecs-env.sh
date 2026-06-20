#!/usr/bin/env bash
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
    echo "Usage: $0 [dev|test|stage|prod]"
    exit 1
    ;;
esac

REGION="${AWS_REGION:-eu-north-1}"
STACK_NAME="devops-ecs-${ENV_KEY}"
APP_NAME="devops-demo-${ENV_KEY}"
BASE_ECR_REPO="devops-demo"
IMAGE_TAG="${IMAGE_TAG:-dev-latest}"

echo "==> Deploying ${DEPLOY_ENV} (${STACK_NAME}) to ${REGION}..."

if aws ecr describe-repositories \
  --region "${REGION}" \
  --repository-names "${BASE_ECR_REPO}" >/dev/null 2>&1; then
  echo "ECR repository ${BASE_ECR_REPO} exists."
else
  echo "Creating ECR repository ${BASE_ECR_REPO}..."
  aws ecr create-repository \
    --region "${REGION}" \
    --repository-name "${BASE_ECR_REPO}" \
    --image-scanning-configuration scanOnPush=true
fi

aws cloudformation deploy \
  --region "${REGION}" \
  --template-file infra/cloudformation-ecs-simple.yaml \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides \
    AppName="${APP_NAME}" \
    Environment="${ENV_KEY}" \
    BaseECRRepo="${BASE_ECR_REPO}" \
  --capabilities CAPABILITY_NAMED_IAM

ECR_URI="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" \
  --output text)"

ALB_DNS="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
  --output text)"

CLUSTER="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ECSClusterName'].OutputValue" \
  --output text)"

SERVICE="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ECSServiceName'].OutputValue" \
  --output text)"

if [[ "${ENV_KEY}" == "dev" ]]; then
  echo ""
  echo "==> Building and pushing Docker image to ECR..."
  aws ecr get-login-password --region "${REGION}" \
    | docker login --username AWS --password-stdin "${ECR_URI}"
  npm ci
  npm test
  docker build -t "${BASE_ECR_REPO}:latest" .
  docker tag "${BASE_ECR_REPO}:latest" "${ECR_URI}:dev-latest"
  docker tag "${BASE_ECR_REPO}:latest" "${ECR_URI}:latest"
  docker push "${ECR_URI}:dev-latest"
  docker push "${ECR_URI}:latest"
  IMAGE_TAG=dev-latest
else
  echo ""
  echo "==> Promoting existing image tag: ${IMAGE_TAG}"
  aws ecr describe-images \
    --region "${REGION}" \
    --repository-name "${BASE_ECR_REPO}" \
    --image-ids "imageTag=${IMAGE_TAG}" >/dev/null
fi

FULL_IMAGE="${ECR_URI}:${IMAGE_TAG}"

echo ""
echo "==> Updating ECS service..."
TASK_ARN=$(aws ecs describe-task-definition \
  --region "${REGION}" \
  --task-definition "${APP_NAME}" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

aws ecs update-service \
  --region "${REGION}" \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --force-new-deployment \
  --desired-count 1 >/dev/null

echo ""
echo "${DEPLOY_ENV} stack updated."
echo "  Environment: ${DEPLOY_ENV}"
echo "  Health:      http://${ALB_DNS}/health"
echo "  Info:        http://${ALB_DNS}/api/info"
echo ""
echo "GitHub: push main → dev auto | Actions → Promote to Environment → manual test/stage/prod"
