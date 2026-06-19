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
MANIFESTS=(
  k8s/namespace.yaml
  k8s/deployment.yaml
  k8s/service.yaml
  k8s/service-nodeport.yaml
  k8s/ingress.yaml
  k8s/hpa.yaml
)

for manifest in "${MANIFESTS[@]}"; do
  if [[ -n "${REMOTE:-}" ]]; then
    ssh -i "${SSH_KEY_PATH:-$HOME/.ssh/devops-demo-key.pem}" "${REMOTE}" \
      "sudo k3s kubectl apply -f -" < "${manifest}"
  else
    kubectl apply -f "${manifest}"
  fi
done

if [[ -n "${IMAGE}" ]]; then
  kubectl -n "${NAMESPACE}" set image deployment/devops-demo app="${IMAGE}"
fi

kubectl -n "${NAMESPACE}" rollout status deployment/devops-demo --timeout=120s
kubectl -n "${NAMESPACE}" get pods,svc,ingress,hpa

echo ""
echo "Kubernetes deployment complete."
