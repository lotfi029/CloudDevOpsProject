# 2. Containerization with Docker

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Dockerfile for building the application image | ✅ Done |
| Source code from Ibrahim-Adel15/FinalProject | ✅ Done — app.py, requirements.txt, templates/, static/ copied to repo root |
| Dockerfile committed to repository | ✅ Done |

---

## Source Application

Cloned from: https://github.com/Ibrahim-Adel15/FinalProject

A Flask web app serving a single HTML page on **port 5000** with NTI × iVolve branding.

---

## `Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
```

### Design Decisions

| Choice | Reason |
|--------|--------|
| `python:3.11-slim` | Minimal base image — smaller size, reduced attack surface |
| Copy `requirements.txt` first | Leverages Docker layer cache — pip only reruns when dependencies change |
| `--no-cache-dir` | Avoids storing pip cache inside the image layer |
| `EXPOSE 5000` | Documents the port Flask listens on |

---

## `.dockerignore`

Excludes DevOps infrastructure files from the image — keeps the image clean and small:

```
terraform/
ansible/
kubernetes/
jenkins/
argocd/
docs/
.git/
*.md
```

---

## Build & Run Locally

```bash
# Build
docker build -t clouddevops-app:latest .

# Run
docker run -p 5000:5000 clouddevops-app:latest

# Visit
open http://localhost:5000
```

---

## Trivy Scan Results (Build #6)

The image was scanned by Trivy in the Jenkins pipeline with `--severity HIGH,CRITICAL`:

| Category | Total | Notes |
|----------|-------|-------|
| Debian OS packages | 7 HIGH | No fix available yet (affected status) |
| Python packages | 3 HIGH | Fix available — `jaraco.context` → 6.1.0, `wheel` → 0.46.2 |
| Secrets | 0 | ✅ Clean (after removing jenkins-key.pem from repo) |

> The scan uses `--exit-code 0` so the pipeline continues even with findings — vulnerabilities are reported but don't block the build.

---

## ECR Repository

Images are pushed to:
```
108782058667.dkr.ecr.us-east-1.amazonaws.com/clouddevops-app:<BUILD_NUMBER>
```