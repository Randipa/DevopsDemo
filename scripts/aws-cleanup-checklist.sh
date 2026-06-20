#!/usr/bin/env bash
# Print AWS Console cleanup checklist
set -euo pipefail

cat <<'EOF'
AWS cleanup checklist (eu-north-1):

1) CloudFormation → Stacks
   - devops-ecs-simple     (current ECS setup) → Delete when done learning
   - devops-dev-env        (OLD — delete if still exists from previous k3s setup)

2) EC2 → Instances
   - Any devops-k3s-node   → must be Terminated (old setup only)

3) ECR → devops-demo repository (removed with ECS stack delete)

4) CloudWatch → Log groups → /ecs/devops-demo (optional delete)

GitHub: Actions → "Delete AWS Cloud Stack" workflow deletes devops-ecs-simple
and attempts devops-dev-env if present.
EOF
