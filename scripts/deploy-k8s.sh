#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/dev-config}"
IMAGE="${IMAGE:-devops-demo:latest}"
REMOTE="${REMOTE:-}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/devops-demo-key.pem}"
NAMESPACE="dev"

SSH_OPTS=(-o StrictHostKeyChecking=no -o BatchMode=yes)
if [[ -f "${SSH_KEY_PATH}" ]]; then
  SSH_OPTS+=(-i "${SSH_KEY_PATH}")
fi

remote_kubectl() {
  ssh "${SSH_OPTS[@]}" "${REMOTE}" "sudo k3s kubectl $*"
}

if [[ -n "${REMOTE}" ]]; then
  echo "Importing image to k3s on ${REMOTE}..."
  docker save "${IMAGE}" | ssh "${SSH_OPTS[@]}" "${REMOTE}" 'sudo k3s ctr images import -'
  ssh "${SSH_OPTS[@]}" "${REMOTE}" \
    "sudo k3s ctr images tag docker.io/library/${IMAGE} ${IMAGE} 2>/dev/null || true"
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
    ssh "${SSH_OPTS[@]}" "${REMOTE}" "sudo k3s kubectl apply -f -" < "${manifest}"
  else
    kubectl apply -f "${manifest}"
  fi
done

if [[ -n "${IMAGE}" ]]; then
  if [[ -n "${REMOTE:-}" ]]; then
    remote_kubectl -n "${NAMESPACE}" set image deployment/devops-demo "app=${IMAGE}"
  else
    kubectl -n "${NAMESPACE}" set image deployment/devops-demo app="${IMAGE}"
  fi
fi

if [[ -n "${REMOTE:-}" ]]; then
  remote_kubectl -n "${NAMESPACE}" rollout status deployment/devops-demo --timeout=120s
  remote_kubectl -n "${NAMESPACE}" get pods,svc,ingress,hpa
else
  kubectl -n "${NAMESPACE}" rollout status deployment/devops-demo --timeout=120s
  kubectl -n "${NAMESPACE}" get pods,svc,ingress,hpa
fi

echo ""
echo "Kubernetes deployment complete."
