# Kubernetes Manifests Migration Guide

## Overview

This project has evolved through multiple iterations:

1. **Terraform-managed** Kubernetes resources (now legacy)
2. **Native Kubernetes manifests** with kubectl (now legacy)
3. **✅ Current: Kustomize overlays + Ansible orchestration** (consolidated approach)

### Current Benefits

- ✅ Single source of truth (Kustomize manifests)
- ✅ Environment-specific configurations (production/staging overlays)
- ✅ GitOps-ready (ArgoCD, Flux compatible)
- ✅ Ansible orchestration for deployment workflow
- ✅ No Terraform state management
- ✅ No imperative vs declarative conflicts

## Current Architecture

```
kustomize/
├── base/                    # Base manifests (shared across all environments)
│   ├── api-deployment.yaml
│   ├── nginx-deployment.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml             # PodDisruptionBudgets for HA
│   └── ...
└── overlays/
    ├── production/          # Production-specific config
    └── staging/             # Staging-specific config

ansible/
└── roles/
    └── deployment-orchestrator/    # Applies Kustomize, handles workflow
```

## Directory Structure

```
kubernetes/
├── namespace.yaml                  # Application namespace
├── secrets.yaml                    # Database and API secrets
├── configmaps.yaml                 # Nginx and application config
├── nginx-html-configmap.yaml       # Static HTML content
├── tls-secret.yaml                 # SSL/TLS certificates (generated)
├── postgres-deployment.yaml        # PostgreSQL database
├── postgres-service.yaml           # Database services
├── api-deployment.yaml             # Python API application
├── api-service.yaml                # API services
├── nginx-deployment.yaml           # Nginx reverse proxy
├── nginx-service.yaml              # Nginx LoadBalancer
├── hpa.yaml                        # Horizontal Pod Autoscaler
└── monitoring/                     # Monitoring stack
    ├── namespace.yaml              # Monitoring namespace
    ├── grafana-secret.yaml         # Grafana credentials
    ├── prometheus-config.yaml      # Prometheus scrape config
    ├── grafana-config.yaml         # Grafana datasource config
    ├── grafana-dashboards.yaml     # Dashboard definitions
    ├── prometheus.yaml             # Prometheus deployment + RBAC
    ├── grafana.yaml                # Grafana deployment
    ├── kube-state-metrics.yaml     # Cluster state metrics
    └── metrics-server.yaml         # Resource metrics (HPA)
```

## Deployment Commands

### Quick Start

```bash
# Full deployment (creates cluster, builds images, deploys everything)
make deploy

# Check status
make status

# View logs
make logs
```

### Step-by-Step Deployment

```bash
# 1. Create Kind cluster
make cluster

# 2. Build and load Docker images
make build
make load-images

# 3. Deploy infrastructure
make apply

# 4. Check deployment
kubectl get pods -n api-deployment-demo
kubectl get pods -n monitoring
```

### Manual Deployment (if not using Makefile)

```bash
# Apply in order:
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/monitoring/namespace.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/configmaps.yaml
kubectl apply -f kubernetes/monitoring/metrics-server.yaml
kubectl apply -f kubernetes/monitoring/prometheus.yaml
kubectl apply -f kubernetes/postgres-deployment.yaml
kubectl apply -f kubernetes/postgres-service.yaml
kubectl apply -f kubernetes/api-deployment.yaml
kubectl apply -f kubernetes/api-service.yaml
kubectl apply -f kubernetes/nginx-deployment.yaml
kubectl apply -f kubernetes/nginx-service.yaml
kubectl apply -f kubernetes/hpa.yaml
kubectl apply -f kubernetes/monitoring/grafana.yaml
kubectl apply -f kubernetes/monitoring/kube-state-metrics.yaml
```

## Migration Notes

### What Changed

1. **Deployment Method**: Switched from `terraform apply` to `kubectl apply`
2. **State Management**: No more Terraform state files
3. **Makefile**: Updated targets to use kubectl instead of Terraform
4. **Secrets**: Now managed via Kubernetes manifest files (update `kubernetes/secrets.yaml`)

### Backward Compatibility

Legacy Terraform commands are still available (deprecated):

```bash
make terraform-apply  # Old Terraform deployment
make init            # Terraform initialization
make plan            # Terraform planning
```

### Updating Secrets

**Before (Terraform)**:

```bash
# Edit terraform/terraform.tfvars
db_password = "newsecret"
terraform apply
```

**Now (Kubernetes)**:

```bash
# Generate base64-encoded secret
echo -n "newsecret" | base64

# Edit kubernetes/secrets.yaml and update the base64 value
# Then apply:
kubectl apply -f kubernetes/secrets.yaml

# Or use kubectl directly:
kubectl create secret generic database-credentials \
  --from-literal=db-password=newsecret \
  --namespace=api-deployment-demo \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Resource Cleanup

```bash
# Delete all resources
make destroy

# Or manually:
kubectl delete namespace api-deployment-demo
kubectl delete namespace monitoring
```

## Benefits of This Migration

1. **Simpler Workflow**: No Terraform state to manage
2. **GitOps Ready**: Manifests can be directly applied by Argo CD, Flux, etc.
3. **Declarative**: Standard Kubernetes YAML for all resources
4. **Troubleshooting**: Direct `kubectl` commands work immediately
5. **Portability**: Works on any Kubernetes cluster (Kind, EKS, GKE, AKS)

## Access URLs

After deployment:

- **Web**: <https://localhost>
- **API**: <http://localhost:8000>
- **API Docs**: <http://localhost:8000/docs>
- **Grafana**: <http://localhost:3000> (admin/admin)
- **Prometheus**: <http://localhost:9090>

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n api-deployment-demo
kubectl get pods -n monitoring

# View logs
kubectl logs -n api-deployment-demo -l app=api-demo

# Describe resources
kubectl describe pod <pod-name> -n api-deployment-demo

# Check events
kubectl get events -n api-deployment-demo --sort-by='.lastTimestamp'

# Verify HPA
kubectl get hpa -n api-deployment-demo

# Check metrics
kubectl top pods -n api-deployment-demo
```

## Next Steps

1. Review and update secrets in `kubernetes/secrets.yaml`
2. Customize resource limits if needed
3. Add custom dashboards to `monitoring/dashboards/`
4. Set up CI/CD pipeline with `kubectl apply`
5. Consider using Kustomize or Helm for environment-specific configs
