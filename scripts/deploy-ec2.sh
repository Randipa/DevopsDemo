#!/usr/bin/env bash
set -euo pipefail

# Deploy Docker image to a remote EC2 host via SSH
# Usage: ./scripts/deploy-ec2.sh user@ec2-host /path/to/image.tar

REMOTE_HOST="${1:?Remote host required (e.g. ec2-user@1.2.3.4)}"
IMAGE_TAR="${2:-artifacts/devops-demo-latest.tar}"
APP_NAME="devops-demo"
REMOTE_DIR="/opt/devops-demo"

echo "Deploying ${APP_NAME} to ${REMOTE_HOST}"

scp "${IMAGE_TAR}" "${REMOTE_HOST}:/tmp/${APP_NAME}.tar"
scp docker-compose.yml "${REMOTE_HOST}:${REMOTE_DIR}/docker-compose.yml"

ssh "${REMOTE_HOST}" bash -s <<EOF
set -euo pipefail
sudo mkdir -p ${REMOTE_DIR}
cd ${REMOTE_DIR}
docker load -i /tmp/${APP_NAME}.tar
docker compose down || true
APP_VERSION=\$(date +%Y%m%d%H%M) docker compose up -d
curl -sf http://localhost:3000/health
EOF

echo "Deployment to ${REMOTE_HOST} completed."
