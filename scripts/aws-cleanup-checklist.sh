#!/usr/bin/env bash
# Print AWS Console cleanup checklist
set -euo pipefail

cat <<'EOF'
AWS cleanup checklist (eu-north-1):

1) CloudFormation → Stacks (delete when done)
   - devops-ecs-dev
   - devops-ecs-test
   - devops-ecs-stage
   - devops-ecs-prod
   - devops-ecs-simple      (legacy — delete if exists)
   - devops-dev-env         (old k3s — delete if exists)

2) ECR → devops-demo repository (shared image store)

3) CloudWatch → Log groups → /ecs/devops-demo-*

GitHub: Actions → "Delete AWS Cloud Stacks" removes all environment stacks.
EOF
