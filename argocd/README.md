# 7. Continuous Deployment with ArgoCD

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Configure ArgoCD to sync and deploy app into cluster | ✅ Done |
| ArgoCD Application committed to repository | ✅ Done — `argocd/application.yml` |

---

## GitOps Flow

```
Jenkins pushes updated kubernetes/deployment.yml to GitHub
                    ↓
        ArgoCD detects diff (polls every 3 min)
                    ↓
        ArgoCD applies changes to EKS cluster
                    ↓
        Kubernetes rolling update → new pods with new image
```

---

## `argocd/application.yml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ivolve-app
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/lotfi029/CloudDevOpsProject.git
    targetRevision: main
    path: kubernetes

  destination:
    server: https://kubernetes.default.svc
    namespace: ivolve

  syncPolicy:
    automated:
      prune: true        # Delete resources removed from Git
      selfHeal: true     # Revert manual cluster changes to match Git
    syncOptions:
      - CreateNamespace=true
```

---

## Install ArgoCD on EKS

```bash
kubectl create namespace argocd

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=180s
```

## Access ArgoCD UI

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Open: **https://localhost:8080** — Login: `admin` / `<password>`

## Deploy the Application

```bash
kubectl apply -f argocd/application.yml
```

ArgoCD immediately syncs `kubernetes/` to the `ivolve` namespace.

---

## Sync Policy Explained

| Option | Effect |
|--------|--------|
| `automated.prune: true` | Resources deleted from Git are removed from the cluster |
| `automated.selfHeal: true` | Manual `kubectl` changes are automatically reverted to match Git |
| `CreateNamespace=true` | Creates `ivolve` namespace automatically if it doesn't exist |

---

## End-to-End CD Verification

After a Jenkins build completes:

```bash
# Check ArgoCD sync status
kubectl get application ivolve-app -n argocd

# Check rollout status
kubectl rollout status deployment/ivolve-app -n ivolve

# Verify new image is running
kubectl get pods -n ivolve -o jsonpath='{.items[*].spec.containers[*].image}'
```

---

## Optional: GitHub Webhook for Instant Sync

Instead of waiting for the 3-minute poll interval:

1. GitHub → repo → **Settings → Webhooks → Add webhook**
2. Payload URL: `https://<argocd-server>/api/webhook`
3. Content type: `application/json`
4. Events: **Just the push event**