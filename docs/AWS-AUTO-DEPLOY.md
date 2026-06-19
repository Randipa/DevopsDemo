# AWS Auto-Deploy from Jenkins

## Prerequisites

- AWS account (region: `eu-north-1`)
- EC2 key pair created in AWS Console
- AWS CLI configured locally: `aws configure`

---

## Step 1 — Create AWS infrastructure (one time)

```bash
cd DevopsDemo
export KEY_NAME=devops-demo-key          # your EC2 key name
export ADMIN_CIDR=$(curl -s ifconfig.me)/32
export AWS_REGION=eu-north-1

./scripts/deploy-dev-env.sh
```

Save outputs:
- **K8sNodePublicIP**
- **LoadBalancerDNS**

---

## Step 2 — SSH key + kubeconfig on your PC

```bash
# Key file (download from AWS when you created key pair)
chmod 400 ~/Downloads/devops-demo-key.pem
mkdir -p ~/.ssh
cp ~/Downloads/devops-demo-key.pem ~/.ssh/devops-demo-key.pem

# kubeconfig from k3s node
mkdir -p ~/.kube
scp -i ~/.ssh/devops-demo-key.pem \
  ec2-user@<K8sNodePublicIP>:/etc/rancher/k3s/k3s.yaml \
  ~/.kube/dev-config

# Replace localhost with public IP
sed -i "s/127.0.0.1/<K8sNodePublicIP>/" ~/.kube/dev-config

# Test
kubectl --kubeconfig ~/.kube/dev-config get nodes
ssh -i ~/.ssh/devops-demo-key.pem ec2-user@<K8sNodePublicIP> "sudo k3s kubectl get nodes"
```

---

## Step 3 — Rebuild Jenkins (kubectl + SSH support)

```bash
cd jenkins
docker compose -f docker-compose.jenkins.yml up -d --build
```

This mounts:
- `~/.ssh` → SSH to EC2
- `~/.kube` → kubectl to k3s

---

## Step 4 — Jenkins environment variables

**Manage Jenkins → System → Global properties → Environment variables**

| Name | Example value |
|------|----------------|
| `K8S_SSH_HOST` | `ec2-user@13.48.x.x` |
| `SSH_KEY_PATH` | `/root/.ssh/devops-demo-key.pem` |
| `ALB_DNS` | `devops-dev-alb-123456.eu-north-1.elb.amazonaws.com` |
| `AWS_REGION` | `eu-north-1` |
| `KUBECONFIG` | `/root/.kube/dev-config` |

Save.

---

## Step 5 — First manual deploy test

```bash
export KUBECONFIG=~/.kube/dev-config
docker build -t devops-demo:test .
# ... or let Jenkins build

# From project root after Jenkins build #8 image exists:
docker save devops-demo:8 | ssh -i ~/.ssh/devops-demo-key.pem ec2-user@<IP> 'sudo k3s ctr images import -'
IMAGE=devops-demo:latest ./scripts/deploy-k8s.sh
curl http://<LoadBalancerDNS>/health
```

---

## Step 6 — Auto deploy

Push to `main` or click **Build Now** in Jenkins.

Pipeline will:
1. Build + test
2. Docker build
3. SSH image to EC2 k3s
4. `kubectl apply` + rollout
5. Validate via ALB (`ALB_DNS` set)

---

## Verify

```bash
curl http://<LoadBalancerDNS>/health
curl http://<LoadBalancerDNS>/api/info
./scripts/test-connectivity.sh <LoadBalancerDNS>
```

Browser: `http://<LoadBalancerDNS>/health`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Deploy stage fails immediately | Set `K8S_SSH_HOST` in Jenkins global env |
| SSH permission denied | Key in `~/.ssh/`, chmod 400, `SSH_KEY_PATH` correct |
| kubectl connection refused | Fix `~/.kube/dev-config` server IP |
| ALB unhealthy | Run `./scripts/deploy-k8s.sh`, check NodePort 30080 |
| Post-Deploy skipped | Set `ALB_DNS` in Jenkins env |

---

## Cost reminder

ALB + EC2 cost money. Delete when done:

```bash
aws cloudformation delete-stack --region eu-north-1 --stack-name devops-dev-env
```
