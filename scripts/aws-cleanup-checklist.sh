#!/usr/bin/env bash
# Print AWS Console cleanup checklist (old k3s + new ECS stacks)
set -euo pipefail

cat <<'EOF'
========================================
AWS CLEANUP CHECKLIST (Console)
Region: eu-north-1 (Stockholm)
========================================

1. EC2 → Instances
   - devops-k3s-node → must be "Terminated" (not Shutting-down)
   - If still running: Instance state → Terminate

2. CloudFormation → Stacks → DELETE these if exist:
   - devops-dev-env      (OLD k3s setup)
   - devops-ecs-simple   (NEW ECS setup - only if starting over)

3. Wait for Status: DELETE_COMPLETE (5-15 min)

4. Verify empty:
   - EC2 → Load Balancers
   - EC2 → Target Groups
   - ECS → Clusters
   - VPC → (optional) leftover devops VPCs

5. Billing → check no running resources

OR use GitHub Actions workflow: "Delete AWS Cloud Stack" (after secrets set)

Local PC: already cleaned via ./scripts/cleanup-local.sh
EOF
