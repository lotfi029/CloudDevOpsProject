# 5. Container Orchestration with Kubernetes

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Create `ivolve` namespace | ✅ Done — `kubernetes/namespace.yml` |
| Deployment with 2 replicas | ✅ Done — `kubernetes/deployment.yml` |
| Each replica on a separate node | ✅ Done — `podAntiAffinity` with `requiredDuringScheduling` |
| Service for accessing the application | ✅ Done — `kubernetes/service.yml` |
| Ingress for accessing the application | ✅ Done — `kubernetes/ingress.yml` |
| YAML files committed to repository | ✅ Done |

---

## Manifests

### `kubernetes/namespace.yml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ivolve
```

---

### `kubernetes/deployment.yml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ivolve-app
  namespace: ivolve
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ivolve-app
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values: [ivolve-app]
              topologyKey: "kubernetes.io/hostname"
      containers:
        - name: ivolve-app
          image: 108782058667.dkr.ecr.us-east-1.amazonaws.com/clouddevops-app:<TAG>
          ports:
            - containerPort: 5000
```

**Key design — Pod Anti-Affinity:**
`requiredDuringSchedulingIgnoredDuringExecution` with `topologyKey: kubernetes.io/hostname` forces Kubernetes to place each replica on a **different node**. If only one node is available, the second pod stays `Pending` — this is intentional to guarantee node-level HA.

**Image tag** is automatically updated by the Jenkins pipeline on every build via `sed` in `updateManifests.groovy`.

---

### `kubernetes/service.yml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ivolve-app-service
  namespace: ivolve
spec:
  selector:
    app: ivolve-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 5000
  type: ClusterIP
```

ClusterIP exposes the app internally — traffic enters through the Ingress.

---

### `kubernetes/ingress.yml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ivolve-app-ingress
  namespace: ivolve
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: a003b45b6f46f4faebe59ef344206b1c-fc4fbd4976084767.elb.us-east-1.amazonaws.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ivolve-app-service
                port:
                  number: 80
```

**LoadBalancer hostname** is from the NGINX Ingress Controller deployed on EKS.

---

## Deployment Commands

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name clouddevops-eks

# Deploy
kubectl apply -f kubernetes/namespace.yml
kubectl apply -f kubernetes/deployment.yml
kubectl apply -f kubernetes/service.yml
kubectl apply -f kubernetes/ingress.yml

# Verify
kubectl get all -n ivolve
kubectl get ingress -n ivolve
kubectl describe pods -n ivolve
```

## Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/aws/deploy.yaml

# Get LoadBalancer hostname
kubectl get svc -n ingress-nginx
```

## Access the Application

```
http://a003b45b6f46f4faebe59ef344206b1c-fc4fbd4976084767.elb.us-east-1.amazonaws.com
```

## Verify Pods on Separate Nodes

```bash
kubectl get pods -n ivolve -o wide
# NODE column should show different node names for each pod
```