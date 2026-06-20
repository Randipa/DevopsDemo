#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-north-1}"

if [[ "${1:-}" == "all" ]]; then
  for STACK in devops-ecs-dev devops-ecs-test devops-ecs-stage devops-ecs-prod; do
    echo "Deleting ${STACK}..."
    aws cloudformation delete-stack --region "${REGION}" --stack-name "${STACK}" || true
  done
else
  ENV_KEY="${1:-dev}"
  STACK_NAME="devops-ecs-${ENV_KEY}"
  echo "Deleting stack ${STACK_NAME} in ${REGION}..."
  aws cloudformation delete-stack --region "${REGION}" --stack-name "${STACK_NAME}"
fi

echo "Wait for DELETE_COMPLETE in AWS Console."
