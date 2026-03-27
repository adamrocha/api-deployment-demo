# Kustomize Overview

Kustomize defines all Kubernetes resources for this project.

## Layout

- `base/`: shared resources
- `overlays/staging`: staging customizations
- `overlays/production`: production customizations

## Build and Apply

```bash
kubectl kustomize kustomize/overlays/production
kubectl apply -k kustomize/overlays/production
```

## Secrets

Secret generation details are documented in:

- `kustomize/SECRET-MANAGEMENT.md`

## Recommended Operational Path

Use Make + Ansible for full deployment orchestration:

```bash
make deploy
make deploy ENV=staging
```
