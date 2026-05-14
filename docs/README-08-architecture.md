# 8. Architecture & Full Project Summary

## ✅ Overall Requirement Status

| # | Topic | Status |
|---|-------|--------|
| 1 | GitHub Repository Setup | ✅ Complete |
| 2 | Containerization with Docker | ✅ Complete |
| 3 | Infrastructure with Terraform | ✅ Complete |
| 4 | Configuration Management with Ansible | ✅ Complete |
| 5 | Container Orchestration with Kubernetes | ✅ Complete |
| 6 | Continuous Integration with Jenkins | ✅ Complete |
| 7 | Continuous Deployment with ArgoCD | ✅ Complete |
| 8 | Documentation | ✅ Complete |

---

## Architecture Diagram

```
Developer pushes code
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│                    GitHub                                 │
│         lotfi029/CloudDevOpsProject (main)                │
│    Source code + K8s manifests + Pipeline config          │
└──────────────┬────────────────────────────┬──────────────┘
               │ SCM trigger                │ ArgoCD polls (3 min)
               ▼                            ▼
┌──────────────────────┐      ┌────────────────────────────┐
│   Jenkins (EC2)      │      │   ArgoCD (in EKS)          │
│   3.219.168.162:8080 │      │   Watches kubernetes/ dir  │
│                      │      └──────────────┬─────────────┘
│  1. Build Image      │                     │ kubectl apply
│  2. Scan (Trivy)     │                     ▼
│  3. Push → ECR       │      ┌────────────────────────────┐
│  4. Delete local     │      │  EKS Cluster               │
│  5. Update manifest  │      │  clouddevops-eks           │
│  6. Push → GitHub ───┼─────▶│                            │
└──────────────────────┘      │  Namespace: ivolve         │
               │              │  Pod 1 → Node 1 (AZ-a)    │
               │ push image   │  Pod 2 → Node 2 (AZ-b)    │
               ▼              │  ClusterIP Service         │
┌──────────────────────┐      │  NGINX Ingress             │
│    Amazon ECR        │      └────────────────────────────┘
│  clouddevops-app     │                     │
│  :1, :2, :3...       │                     │
└──────────────────────┘                     ▼
                              http://a003b45b6f46f4faebe59ef344206b1c-
                                     fc4fbd4976084767.elb.us-east-1.amazonaws.com
```

---

## AWS Infrastructure

```
AWS Account: 108782058667
Region: us-east-1

VPC: vpc-0fe5e6f40d47e98b1  (10.0.0.0/16)
├── Public Subnet  us-east-1a  10.0.1.0/24   Jenkins EC2 (t3.small)
├── Public Subnet  us-east-1b  10.0.2.0/24   Load Balancer
├── Private Subnet us-east-1a  10.0.3.0/24   EKS Node 1
└── Private Subnet us-east-1b  10.0.4.0/24   EKS Node 2

Internet Gateway  → Public subnets
NAT Gateway       → Private subnets (outbound only)
Network ACL       → All subnets (allow all)

EKS: clouddevops-eks  (k8s 1.32)
ECR: clouddevops-app
Jenkins: 3.219.168.162:8080
```

---

## Technology Stack

| Tool | Version | Role |
|------|---------|------|
| GitHub | — | Source control & GitOps store |
| Docker | CE latest | Application containerization |
| Python | 3.11-slim | App base image |
| Flask | 3.1.3 | Web framework |
| Amazon ECR | — | Container image registry |
| Terraform | ≥ 1.5 | Infrastructure as Code |
| AWS Provider | 5.100.0 | Terraform AWS provider |
| Amazon EKS | 1.32 | Kubernetes cluster |
| Amazon EC2 | t3.small | Jenkins server |
| Ansible | ≥ 2.14 | Configuration management |
| Jenkins | LTS | CI server |
| Trivy | latest | Container vulnerability scanning |
| Kubernetes | 1.32 | Container orchestration |
| NGINX Ingress | 1.10.0 | Ingress controller |
| ArgoCD | stable | GitOps CD |

---

## Step-by-Step Setup Guide

### Prerequisites
- AWS CLI configured with admin credentials
- Terraform ≥ 1.5
- Ansible ≥ 2.14 in a Python venv
- kubectl installed
- Docker installed

### Step 1 — Provision Infrastructure
```bash
cd terraform/

# Create S3 backend (one-time)
aws s3api create-bucket --bucket clouddevops-tfstate --region us-east-1
aws s3api put-bucket-versioning --bucket clouddevops-tfstate \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name clouddevops-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1

terraform init
terraform apply -var="key_name=jenkins-key"
```

### Step 2 — Configure Jenkins with Ansible
```bash
source ~/.ansible-venv/bin/activate
cd ansible/
ansible-playbook -i inventory/aws_ec2.yml \
  playbooks/configure_jenkins.yml \
  --private-key ~/.ssh/jenkins-key.pem
```

### Step 3 — Connect kubectl to EKS
```bash
aws eks update-kubeconfig --region us-east-1 --name clouddevops-eks
kubectl get nodes
```

### Step 4 — Install NGINX Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/aws/deploy.yaml
kubectl get svc -n ingress-nginx  # Note the EXTERNAL-IP
```

### Step 5 — Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/application.yml
```

### Step 6 — Configure Jenkins
1. Open `http://<jenkins_ip>:8080`
2. Enter the initial admin password from Ansible output
3. Install suggested plugins + Docker Pipeline, Pipeline plugins
4. Add `github-credentials` (username + GitHub token with `repo` scope)
5. Register shared library: name=`clouddevops-shared-library`, path=`jenkins/shared-library`
6. Create Pipeline job → SCM → Script Path: `jenkins/Jenkinsfile`
7. Attach `JenkinsEC2Role` IAM instance profile to the Jenkins EC2

### Step 7 — Trigger the Pipeline
Click **Build Now** — the full pipeline runs:
```
Build → Scan → Push to ECR → Delete local → Update manifest → Push to GitHub
```
ArgoCD detects the manifest change and deploys automatically to EKS.

---

## Known Issues & Resolutions

| Issue | Root Cause | Fix Applied |
|-------|-----------|-------------|
| `t3.medium` not free tier eligible | AWS free tier restriction | Changed to `t3.small` |
| EKS k8s 1.29 AMI not supported | AWS deprecated old AMI | Bumped to `1.32` |
| Jenkins requires Java 21 | Jenkins LTS dropped Java 17 support | Changed from OpenJDK 17 → 21 |
| Jenkins GPG key expired (2026-03-26) | Jenkins key rotation | Used `gpg --dearmor` + keyserver to fetch new key `7198F4B714ABFC68` |
| `apt_key` module deprecated | Ubuntu 22.04+ requires signed-by | Replaced with `get_url` + `gpg --dearmor` |
| Dynamic inventory: `AuthFailure` | AWS credentials not configured | Ran `aws configure` in venv |
| Dynamic inventory: roles not found | `roles_path` not set | Added to `ansible.cfg` |
| `kubectl` exec plugin `v1alpha1` | Old AWS CLI v1 generating kubeconfig | Removed v1, used AWS CLI v2 |
| Jenkins can't reach EKS API | Jenkins in public subnet, EKS in private | Added SG rule allowing Jenkins SG → EKS SG port 443 |
| `requirements.txt` not found in Docker | Source code not committed | Copied app files from FinalProject repo |
| Push manifests: `src refspec main does not match` | Jenkins detached HEAD | Added `git checkout -B main` in `pushManifests.groovy` |
| Push manifests: 403 Forbidden | GitHub token missing `repo` scope | Regenerated token with full `repo` scope |
| Private key in repo | `terraform/jenkins-key.pem` committed | Added `terraform/*.pem` to `.gitignore`, removed from tracking |