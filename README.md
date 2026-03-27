# API Deployment Demo

Kubernetes deployment demo using Kustomize overlays for manifests and Ansible for orchestration.

## Quick Start

Prerequisites: Docker, Kind, kubectl, Ansible.

```bash
make cluster
make deploy
make get-secrets
```

Access URLs:

- Web: https://localhost
- API: https://localhost:8000
- API Docs: https://localhost:8000/docs
- Grafana: https://localhost:3000
- Prometheus: https://localhost:9090

## Deployment Model

- Kustomize (`kustomize/base` + `kustomize/overlays/{production,staging}`) is the Kubernetes source of truth.
- Ansible (`ansible/deploy.yml`) handles pre-tasks, apply flow, and verification.
- Makefile provides operational commands.

## Common Commands

```bash
make deploy                 # production
make deploy ENV=staging     # staging
make status
make logs-api
make validate
make destroy
```

## Documentation

Primary documentation is intentionally consolidated:

- docs/INDEX.md
- docs/QUICK-START.md
- docs/SECRETS-SECURITY.md
- docs/MONITORING.md
- kustomize/SECRET-MANAGEMENT.md

Legacy and historical docs remain in `docs/archive/`.
