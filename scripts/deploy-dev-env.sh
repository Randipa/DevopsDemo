#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-north-1}"
STACK_NAME="${STACK_NAME:-devops-dev-env}"
TEMPLATE="infra/cloudformation-dev-env.yaml"

KEY_NAME="${KEY_NAME:?Set KEY_NAME (EC2 key pair name)}"
ADMIN_CIDR="${ADMIN_CIDR:?Set ADMIN_CIDR (e.g. $(curl -sf ifconfig.me)/32)}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.small}"

echo "Deploying development environment to ${REGION}..."

aws cloudformation deploy \
  --region "${REGION}" \
  --template-file "${TEMPLATE}" \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides \
    KeyName="${KEY_NAME}" \
    AdminCidr="${ADMIN_CIDR}" \
    InstanceType="${INSTANCE_TYPE}" \
  --capabilities CAPABILITY_IAM

aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs' \
  --output table

echo ""
echo "Next: copy kubeconfig, deploy app, run connectivity tests."
echo "  scp -i key.pem ec2-user@<K8sNodePublicIP>:/etc/rancher/k3s/k3s.yaml ~/.kube/dev-config"
echo "  REMOTE=ec2-user@<IP> ./scripts/deploy-k8s.sh"
echo "  ./scripts/test-connectivity.sh <LoadBalancerDNS>"
