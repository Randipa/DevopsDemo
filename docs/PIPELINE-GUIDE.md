# Real-World DevOps Pipeline Guide

End-to-end flow: **GitHub → Jenkins → Build/Test → AWS Dev → Kubernetes → ALB → Grafana monitoring**

Region used in examples: `eu-north-1` (change if needed).

---

## Architecture

```
Developer
   │
   ▼
GitHub (push main/develop)
   │
   ├── GitHub Actions ──► build + test (CI mirror)
   │
   └── Jenkins Pipeline
           │
           ├── npm ci / npm test
           ├── docker build
           ├── container validate (/health, /metrics)
           ├── archive image (.tar)
           └── deploy to k3s on AWS
                    │
         ┌──────────┴──────────┐
         │                     │
    AWS ALB (load balancer)   Security Groups + NACL (firewall)
         │                     │
    k3s Kubernetes (2 pods)   NodePort 30080
         │
    Prometheus ──► Grafana
```

---

## Phase 1 — Push project to GitHub

```bash
cd /home/saliya/Documents/DevopsDemo
git init
git add .
git commit -m "feat: add full DevOps pipeline with K8s, ALB, Grafana"
```

Create a repo on GitHub, then:

```bash
git remote add origin https://github.com/<your-user>/devops-demo.git
git branch -M main
git push -u origin main
```

---

## Phase 2 — Run Jenkins locally (see pipeline stages)

```bash
cd jenkins
docker compose -f docker-compose.jenkins.yml up -d
```

Open: http://localhost:8080

1. Install suggested plugins on first start (or use pre-configured image)
2. **Manage Jenkins → Credentials** — add SSH key for k3s EC2 if deploying remotely
3. **New Item → Pipeline**
   - Definition: Pipeline script from SCM
   - SCM: Git → your GitHub repo URL
   - Script Path: `Jenkinsfile`
4. **Manage Jenkins → System → Global environment variables** (optional):

| Variable | Example |
|----------|---------|
| `K8S_SSH_HOST` | `ec2-user@13.48.x.x` |
| `ALB_DNS` | `devops-dev-alb-xxx.eu-north-1.elb.amazonaws.com` |
| `KUBECONFIG` | `/var/jenkins_home/.kube/dev-config` |

5. **Build Now** — open **Stage View** to see each Jenkins stage:
   - Checkout → Install → Test → Lint → Docker Build → Validate → Archive → Deploy → Post-Deploy

---

## Phase 3 — Deploy AWS development environment

### Prerequisites

- AWS CLI configured (`aws configure`)
- EC2 key pair created in console
- Your public IP:

```bash
curl -s ifconfig.me
# Example: 123.45.67.89 → use 123.45.67.89/32
```

### Deploy stack (VPC + firewall + ALB + k3s)

```bash
export KEY_NAME=devops-demo-key
export ADMIN_CIDR=<YOUR_IP>/32
export AWS_REGION=eu-north-1

chmod +x scripts/*.sh
./scripts/deploy-dev-env.sh
```

This creates:
- **VPC** with public subnets (2 AZs for ALB)
- **Network ACL** (subnet firewall layer)
- **Security Groups** (instance firewall):
  - ALB: ports 80, 443 from internet
  - k3s node: SSH/6443/Jenkins/Grafana from your IP; port 30080 from ALB only
- **Application Load Balancer** → target group → NodePort 30080
- **EC2** with k3s installed

Save outputs: `LoadBalancerDNS`, `K8sNodePublicIP`

### Copy kubeconfig

```bash
scp -i ~/Downloads/devops-demo-key.pem \
  ec2-user@<K8sNodePublicIP>:/etc/rancher/k3s/k3s.yaml \
  ~/.kube/dev-config

# Fix server URL — replace 127.0.0.1 with public IP
sed -i "s/127.0.0.1/<K8sNodePublicIP>/" ~/.kube/dev-config
export KUBECONFIG=~/.kube/dev-config
kubectl get nodes
```

---

## Phase 4 — Deploy app to Kubernetes

From your local machine:

```bash
cd /home/saliya/Documents/DevopsDemo
docker build -t devops-demo:latest .

export REMOTE=ec2-user@<K8sNodePublicIP>
export KUBECONFIG=~/.kube/dev-config
./scripts/deploy-k8s.sh
```

This applies:
- `k8s/deployment.yaml` — **2 replicas** (load balancing inside cluster)
- `k8s/service.yaml` — ClusterIP
- `k8s/service-nodeport.yaml` — **NodePort 30080** (ALB backend)
- `k8s/ingress.yaml` — Traefik ingress (k3s default)
- `k8s/hpa.yaml` — auto-scale 2–4 pods on CPU

Verify:

```bash
kubectl -n dev get pods -o wide
curl http://<LoadBalancerDNS>/health
curl http://<LoadBalancerDNS>/api/info
```

---

## Phase 5 — Firewall and telnet/connectivity testing

```bash
./scripts/test-connectivity.sh <LoadBalancerDNS>
./scripts/test-connectivity.sh <K8sNodePublicIP>
```

The script checks ports with **nc**, **telnet**, or `/dev/tcp`:
- 22 SSH, 80 HTTP, 443 HTTPS
- 30080 K8s NodePort (ALB backend)
- 6443 Kubernetes API
- 8080 Jenkins, 9090 Prometheus, 3001 Grafana

Expected after full setup:
- ALB DNS: port **80 OPEN**, `/health` OK
- k3s node: port **22 OPEN** (your IP only), **30080 OPEN** from ALB

To test telnet manually:

```bash
telnet <LoadBalancerDNS> 80
# or
nc -zv <LoadBalancerDNS> 80
```

---

## Phase 6 — Grafana monitoring

### Option A — Local (app + monitoring stack)

```bash
# Terminal 1 — app
docker compose up -d

# Terminal 2 — monitoring
cd monitoring
docker compose -f docker-compose.monitoring.yml up -d
docker compose -f docker-compose.app.yml up -d
```

- Grafana: http://localhost:3001 (admin / admin)
- Prometheus: http://localhost:9090
- App metrics: http://localhost:3000/metrics

### Option B — On k3s node (SSH)

```bash
scp -r monitoring ec2-user@<K8sNodePublicIP>:/opt/devops-demo/
ssh ec2-user@<K8sNodePublicIP>
cd /opt/devops-demo/monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

Open (from your IP only — SG allows 3001):
- http://<K8sNodePublicIP>:3001

Pre-built dashboard: **DevOps Demo Overview** (HTTP requests, CPU, memory)

---

## Phase 7 — Jenkins automated deploy (full loop)

1. Push code to GitHub `develop` branch
2. Jenkins webhook or poll SCM triggers pipeline
3. Jenkins stages run automatically
4. If `K8S_SSH_HOST` and `ALB_DNS` are set, deploy + connectivity tests run

GitHub webhook (optional):
- GitHub repo → Settings → Webhooks → `http://<jenkins-host>:8080/github-webhook/`

---

## Free Tier cost tips

| Resource | Note |
|----------|------|
| t3.small k3s node | Not always free — t3.micro works but tight for K8s |
| ALB | ~$16/month — largest cost; stop stack when not learning |
| EBS | 8–30 GB within free tier |
| Data transfer | Keep traffic low |

**Save money:**
```bash
aws cloudformation delete-stack --region eu-north-1 --stack-name devops-dev-env
```

Stop Jenkins locally:
```bash
cd jenkins && docker compose -f docker-compose.jenkins.yml down
```

---

## Quick reference

| Task | Command |
|------|---------|
| Local test | `npm test` |
| Build image | `docker build -t devops-demo:latest .` |
| Deploy AWS env | `./scripts/deploy-dev-env.sh` |
| Deploy K8s | `./scripts/deploy-k8s.sh` |
| Firewall test | `./scripts/test-connectivity.sh <host>` |
| Start Jenkins | `cd jenkins && docker compose -f docker-compose.jenkins.yml up -d` |
| Start Grafana | `cd monitoring && docker compose -f docker-compose.monitoring.yml up -d` |
| kubectl pods | `kubectl -n dev get pods` |
| ALB health | `curl http://<ALB_DNS>/health` |

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| ALB unhealthy target | Check NodePort 30080 service and pods: `kubectl -n dev get svc,pods` |
| kubectl connection refused | Fix kubeconfig server IP; SG port 6443 open for your IP |
| Grafana no data | Prometheus target must reach app `/metrics` |
| Jenkins deploy skipped | Set `K8S_SSH_HOST` in Jenkins global env |
| telnet command not found | Script falls back to `nc` or `/dev/tcp` |
