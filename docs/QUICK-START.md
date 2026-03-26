# Quick Start Guide

Fast-track guide to deploying and managing the API Deployment Demo with Kustomize + Ansible.

## 🚀 Deploy in 3 Commands

```bash
make build    # Build Docker images
make cluster  # Create Kind cluster
make deploy   # Deploy everything
```

Access your application:

- **Web (HTTPS):** https://localhost:30443
- **API:** http://localhost:30800
- **Grafana:** http://localhost:30300 (admin/admin)
- **Prometheus:** http://localhost:30900

## 📋 Common Commands

### Deployment

```bash
make deploy               # Full deployment (production)
make deploy ENV=staging   # Deploy staging environment
make status               # Check pod status
make health               # Run health checks
make urls                 # Show all access URLs
```

### Management

```bash
make restart COMPONENT=api     # Restart API pods
make logs-api                  # View API logs
make logs-nginx                # View Nginx logs
make events                    # View cluster events
make get-secrets               # Display passwords/secrets
```

### Monitoring

```bash
make verify-monitoring    # Check monitoring stack
make verify-metrics       # Verify metrics collection
make dashboard            # Generate traffic for demos
```

### Cleanup

```bash
make destroy     # Remove deployment (keep cluster)
make clean       # Full cleanup (delete cluster)
```

## 🏗️ Architecture

```text
┌─────────────────────────────────────────┐
│          MAKE (Orchestration)           │
│   Simple interface for all operations   │
└─────────────────────────────────────────┘
                  │
     ┌────────────┴──────────────┐
     ▼                           ▼
┌──────────┐              ┌─────────────┐
│ Kustomize│              │   Ansible   │
│ Manifests│───apply────▶ │Orchestration│
│  Source  │              │   & Deploy  │
└──────────┘              └─────────────┘
                                │
                                ▼
                    ┌────────────────────┐
                    │  Kind Cluster      │
                    │  • API (2 pods)    │
                    │  • Nginx (2 pods)  │
                    │  • PostgreSQL      │
                    │  • Monitoring      │
                    └────────────────────┘
```

## 📁 Key Directories

```text
api-deployment-demo/
├── kustomize/                  # Kubernetes manifests (SOURCE OF TRUTH)
│   ├── base/                   # Common resources
│   └── overlays/
│       ├── production/         # Production environment
│       └── staging/            # Staging environment
│
├── ansible/                    # Deployment orchestration
│   ├── deploy.yml              # Main deployment playbook
│   ├── destroy.yml             # Cleanup playbook
│   └── roles/
│       └── deployment-orchestrator/  # Kustomize + validation
│
├── scripts/                    # Utility scripts
│   ├── generate-secrets.sh     # Create secrets
│   ├── generate-tls-secrets.sh # Create TLS certificates
│   └── get-passwords.sh        # Display credentials
│
└── Makefile                    # Command interface
```

## 🔧 Configuration

### Change Replicas

```bash
# Edit kustomize/overlays/production/kustomization.yaml
replicas:
  - name: api-deployment
    count: 5

# Redeploy
make deploy
```

### Update Environment Variables

```bash
# Edit kustomize/base/configmaps.yaml or overlay-specific patches
# Then redeploy
make deploy
```

### Switch Environments

```bash
ENV=staging make deploy      # Deploy staging
ENV=production make deploy   # Deploy production (default)
```

## 🔐 Secrets Management

### Generate Secrets

```bash
# Generate all secrets
./scripts/generate-secrets.sh production

# Generate TLS certificates
./scripts/generate-tls-secrets.sh

# View current secrets
make get-secrets
```

### Manual Secret Management

```bash
# Create/update secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  -n api-deployment-demo-ns \
  --dry-run=client -o yaml | kubectl apply -f -

# View secrets
kubectl get secrets -n api-deployment-demo-ns
```

## 🐛 Troubleshooting

### Check Pod Status

```bash
make status                              # All pods
kubectl get pods -n api-deployment-demo-ns  # Direct kubectl
kubectl describe pod <pod-name> -n api-deployment-demo-ns
```

### View Logs

```bash
make logs-api                            # API logs
make logs-nginx                          # Nginx logs
kubectl logs -f deployment/api-deployment -n api-deployment-demo-ns
```

### Check Events

```bash
make events                              # Recent events
kubectl get events -n api-deployment-demo-ns --sort-by='.lastTimestamp'
```

### Pod Not Starting?

```bash
# Check events
kubectl describe pod <pod-name> -n api-deployment-demo-ns

# Check resource constraints
kubectl top pods -n api-deployment-demo-ns

# Check HPA
kubectl get hpa -n api-deployment-demo-ns
```

### Service Not Accessible?

```bash
# Check services
kubectl get svc -n api-deployment-demo-ns

# Test internal connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -n api-deployment-demo-ns -- sh
  # Inside the pod:
  wget -qO- http://api-service:8000/health
```

### Deployment Stuck?

```bash
# Check deployment status
kubectl rollout status deployment/api-deployment -n api-deployment-demo-ns

# View rollout history
kubectl rollout history deployment/api-deployment -n api-deployment-demo-ns

# Rollback if needed
kubectl rollout undo deployment/api-deployment -n api-deployment-demo-ns
```

## 🔄 Common Workflows

### Update Application Code

```bash
# 1. Build new images
make build

# 2. Load into cluster
make load-images

# 3. Restart pods to use new images
make restart COMPONENT=api
```

### Scale Application

```bash
# Edit kustomize/overlays/production/kustomization.yaml
# Change replicas count
# Then:
make deploy
```

### Update Configuration

```bash
# Edit kustomize/base/configmaps.yaml
# Then:
make deploy

# Or just apply ConfigMap changes
kubectl apply -f kustomize/base/configmaps.yaml
```

### Add New Service

```bash
# 1. Add deployment YAML to kustomize/base/
# 2. Add service YAML to kustomize/base/
# 3. Reference in kustomize/base/kustomization.yaml
# 4. Deploy
make deploy
```

## 📊 Monitoring Access

### Grafana

- URL: http://localhost:30300
- Username: `admin`
- Password: `admin` (or check `make get-secrets`)

**Pre-configured dashboards:**

- API Performance
- Database Metrics
- Infrastructure Overview
- Nginx Traffic

### Prometheus

- URL: http://localhost:30900
- Query examples:
  - `rate(http_requests_total[5m])` - Request rate
  - `up` - Service health
  - `container_cpu_usage_seconds_total` - CPU usage

## 🧪 Validation

```bash
# Run all validations
make validate

# Individual checks
make health              # Health endpoints
make verify-monitoring   # Monitoring stack
make verify-metrics      # Metrics collection
```

## 🆘 Getting Help

```bash
make help                # List all available commands
make urls                # Show access URLs
make get-secrets         # Display credentials
```

## 📚 Next Steps

- **[MONITORING.md](MONITORING.md)** - Configure dashboards and alerts
- **[SECRETS-SECURITY.md](SECRETS-SECURITY.md)** - Security best practices
- **[../README.md](../README.md)** - Detailed architecture and features
