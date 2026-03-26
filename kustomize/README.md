# Kustomize Deployment README

## Overview

Kustomize provides a template-free way to customize Kubernetes configurations. This setup uses a base + overlays pattern for different environments.

## Directory Structure

```
kustomize/
├── base/
│   └── kustomization.yaml          # Base resources (common to all environments)
└── overlays/
    ├── production/
    │   ├── kustomization.yaml      # Production-specific customizations
    │   └── namespace.yaml          # Production namespace
    └── staging/
        ├── kustomization.yaml      # Staging-specific customizations
        └── namespace.yaml          # Staging namespace
```

## Quick Start

### Deploy Production

```bash
# Preview what will be deployed
kubectl kustomize kustomize/overlays/production

# Apply to cluster
kubectl apply -k kustomize/overlays/production

# Or use Kustomize directly
kustomize build kustomize/overlays/production | kubectl apply -f -
```

### Deploy Staging

```bash
kubectl apply -k kustomize/overlays/staging
```

### Delete Deployment

```bash
kubectl delete -k kustomize/overlays/production
```

## Features

### Base Configuration

The `base/` directory contains all common resources:

- Deployments (API, Nginx, PostgreSQL)
- Services
- ConfigMaps
- Secrets
- HPA
- Monitoring stack (Prometheus, Grafana, metrics-server)

### Overlays

Each overlay customizes the base for specific environments:

**Production** (`overlays/production/`):

- Higher replica counts (API: 2, Nginx: 2)
- Increased resource limits (1Gi memory, 1000m CPU)
- HPA max replicas: 10
- Production labels and annotations

**Staging** (`overlays/staging/`):

- Lower replica counts (all: 1)
- Reduced resource limits (512Mi memory, 500m CPU)
- HPA max replicas: 3
- Name prefix: `staging-`
- Debug mode enabled

## Advanced Usage

### Customize Image Tags

```bash
# Use specific image version
cd kustomize/overlays/production
kustomize edit set image api-deployment-demo-api:v1.2.3
kustomize edit set image api-deployment-demo-nginx:v1.2.3
```

### Add Custom Patches

Create a patch file in the overlay directory:

```yaml
# overlays/production/replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 5
```

Add to `kustomization.yaml`:

```yaml
patchesStrategicMerge:
  - replicas.yaml
```

### Preview Before Applying

```bash
# See the final rendered YAML
kubectl kustomize kustomize/overlays/production > preview.yaml

# Use diff to see changes
kubectl diff -k kustomize/overlays/production
```

### Validate Configuration

```bash
# Validate with kubectl
kubectl kustomize kustomize/overlays/production --validate=true

# Dry-run
kubectl apply -k kustomize/overlays/production --dry-run=client
```

## Integration with CI/CD

### GitOps (ArgoCD/Flux)

Point your GitOps tool to the overlay directory:

```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-demo-production
spec:
  source:
    repoURL: https://github.com/your-org/api-deployment-demo
    targetRevision: main
    path: kustomize/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: api-deployment-demo
```

### GitHub Actions

```yaml
- name: Deploy with Kustomize
  run: |
    kubectl apply -k kustomize/overlays/production
```

## Common Kustomize Commands

```bash
# Build without applying
kustomize build kustomize/overlays/production

# Apply
kubectl apply -k kustomize/overlays/production

# Delete
kubectl delete -k kustomize/overlays/production

# Diff
kubectl diff -k kustomize/overlays/production

# Edit images
kustomize edit set image api-deployment-demo-api:v2.0.0

# Add resource
kustomize edit add resource new-resource.yaml

# Add configmap from file
kustomize edit add configmap my-config --from-file=config.json
```

## Comparison with Make Deploy

| Feature              | make deploy | kustomize       |
| -------------------- | ----------- | --------------- |
| Declarative          | Partial     | Full            |
| Environment variants | Manual      | Native overlays |
| Version control      | Scripts     | YAML configs    |
| CI/CD friendly       | Medium      | High            |
| GitOps support       | Limited     | Excellent       |
| Learning curve       | Low         | Medium          |
| Flexibility          | High        | High            |

## Migration from Make

The Makefile can still orchestrate Kustomize:

```makefile
deploy-kustomize: build load-images
	kubectl apply -k kustomize/overlays/production

destroy-kustomize:
	kubectl delete -k kustomize/overlays/production
```

## Best Practices

1. **Keep base minimal** - Only common resources in base
2. **Use overlays for variants** - Environment-specific changes in overlays
3. **Version control everything** - Commit all kustomization.yaml files
4. **Test locally first** - Use `kubectl kustomize` to preview
5. **Use strategic merge** - Prefer patches over full resource duplication
6. **Document customizations** - Add comments in kustomization.yaml

## Troubleshooting

### Resource not found

```bash
# Check if path is correct
ls -la kustomize/overlays/production/

# Verify base path in overlay
grep "bases:" kustomize/overlays/production/kustomization.yaml
```

### Image not updating

```bash
# Explicitly set images in overlay
cd kustomize/overlays/production
kustomize edit set image api-deployment-demo-api:latest
```

### Namespace conflicts

Ensure namespace is consistent:

```yaml
# In kustomization.yaml
namespace: api-deployment-demo
```

## Learn More

- [Kustomize Official Docs](https://kustomize.io/)
- [Kubernetes SIG](https://github.com/kubernetes-sigs/kustomize)
- [ArgoCD + Kustomize](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
