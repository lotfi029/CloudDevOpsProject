# 1. GitHub Repository Setup

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Repository named `CloudDevOpsProject` | ✅ Done — https://github.com/lotfi029/CloudDevOpsProject |
| Initialized with README | ✅ Done |

---

## Repository URL

> **https://github.com/lotfi029/CloudDevOpsProject**

---

## Repository Structure

```
CloudDevOpsProject/
├── Dockerfile                        ← Application container definition
├── Jenkinsfile                       ← (inside jenkins/ folder)
├── README.md
├── .dockerignore                     ← Excludes non-app files from image
├── .gitignore                        ← Excludes .terraform, *.pem, *.tfvars
├── app.py                            ← Flask application
├── requirements.txt                  ← Python dependencies
├── templates/index.html              ← App HTML template
├── static/style.css                  ← App CSS
│
├── terraform/                        ← Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
│       ├── network/
│       ├── server/
│       ├── eks/
│       └── ecr/
│
├── ansible/                          ← Configuration Management
│   ├── ansible.cfg
│   ├── inventory/aws_ec2.yml
│   ├── playbooks/configure_jenkins.yml
│   └── roles/
│       ├── java/tasks/main.yml
│       ├── jenkins/tasks/main.yml
│       └── packages/tasks/main.yml
│
├── kubernetes/                       ← K8s Manifests
│   ├── namespace.yml
│   ├── deployment.yml
│   ├── service.yml
│   └── ingress.yml
│
├── jenkins/
│   ├── Jenkinsfile                   ← CI Pipeline
│   └── shared-library/vars/          ← Shared Library Groovy functions
│       ├── buildImage.groovy
│       ├── scanImage.groovy
│       ├── pushImage.groovy
│       ├── deleteLocalImage.groovy
│       ├── updateManifests.groovy
│       └── pushManifests.groovy
│
├── argocd/
│   └── application.yml               ← CD GitOps Application
│
└── docs/                             ← Per-topic documentation
```

---

## Security Notes

- `terraform/*.pem` is excluded via `.gitignore` — never commit private keys
- `*.tfvars` excluded — never commit secrets or variable files with credentials
- The `.dockerignore` excludes `terraform/`, `ansible/`, `kubernetes/`, `jenkins/`, `argocd/` from the Docker image