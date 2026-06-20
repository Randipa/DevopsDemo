# GitHub IAM User — Required Permissions

The CloudFormation stack creates ECS **TaskRole** and **TaskExecutionRole**.
The `github-devops` IAM user must be allowed to create IAM roles.

## Quick fix (learning account)

AWS Console → **IAM** → **Users** → **github-devops** → **Add permissions**

Attach policy: **`IAMFullAccess`**

(Keep `PowerUserAccess` if already attached.)

Then:

1. CloudFormation → delete failed stack `devops-ecs-simple`
2. GitHub Actions → Re-run workflow

## Minimum custom policy (alternative)

If you prefer not to use IAMFullAccess, create inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "*"
    }
  ]
}
```

PowerUserAccess alone is **not enough** for this stack.
