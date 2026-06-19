#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/dev-config}"
IMAGE="${IMAGE:-devops-demo:latest}"
REMOTE="${REMOTE:-}"
NAMESPACE="dev"

if [[ -n "${REMOTE}" ]]; then
  echo "Importing image to k3s on ${REMOTE}..."
  docker save "${IMAGE}" | ssh "${REMOTE}" 'sudo k3s ctr images import -'
fi

export KUBECONFIG

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/service-nodeport.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

kubectl -n "${NAMESPACE}" rollout status deployment/devops-demo --timeout=120s
kubectl -n "${NAMESPACE}" get pods,svc,ingress,hpa

echo ""
echo "Kubernetes deployment complete."
