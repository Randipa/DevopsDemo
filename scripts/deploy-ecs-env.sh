#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

REGION="${AWS_REGION:-eu-north-1}"
STACK_NAME="${STACK_NAME:-devops-ecs-simple}"
APP_NAME="${APP_NAME:-devops-demo}"

echo "==> Deploying ECS Fargate stack to ${REGION}..."
aws cloudformation deploy \
  --region "${REGION}" \
  --template-file infra/cloudformation-ecs-simple.yaml \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides AppName="${APP_NAME}" \
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

echo ""
echo "==> Building and pushing first Docker image to ECR..."
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${ECR_URI}"

docker build -t "${APP_NAME}:latest" .
docker tag "${APP_NAME}:latest" "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"

echo ""
echo "==> Forcing ECS service deployment..."
aws ecs update-service \
  --region "${REGION}" \
  --cluster "${CLUSTER}" \
  --service "${SERVICE}" \
  --force-new-deployment \
  --query 'service.serviceName' \
  --output text

echo ""
echo "Stack deployed."
echo "  ECR:  ${ECR_URI}"
echo "  ALB:  http://${ALB_DNS}/health"
echo ""
echo "Next: add GitHub secrets and push to main for auto deploy."
echo "  See: docs/ECS-SIMPLE-GUIDE.md or Note/ecs-start.html"
