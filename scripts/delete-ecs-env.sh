#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-north-1}"
STACK_NAME="${STACK_NAME:-devops-ecs-simple}"

echo "Deleting stack ${STACK_NAME} in ${REGION}..."
aws cloudformation delete-stack \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}"

echo "Wait for DELETE_COMPLETE in AWS Console or run:"
echo "  aws cloudformation wait stack-delete-complete --region ${REGION} --stack-name ${STACK_NAME}"
