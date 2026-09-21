# API Deployment Demo

Kubernetes deployment demo using Kustomize overlays for manifests and Ansible for orchestration.

## Quick Start

Prerequisites: Docker, Kind, kubectl, Ansible, Python 3.12+, Poetry.

Fresh clone workflow:

```bash
make bootstrap
make validate
make cluster
make deploy
make smoke-test
```

If you already have a configured repo, the shorter path still works:

```bash
make cluster
make deploy
make smoke-test
```

Access URLs:

- Web: <https://localhost:8443>
- API: <http://localhost:8000>
- API Docs: <http://localhost:8000/docs>
- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>

## Deployment Model

- Kustomize (`kustomize/base` + `kustomize/overlays/{production,staging}`) is the Kubernetes source of truth.
- Ansible (`ansible/deploy.yml`) handles pre-tasks, apply flow, and verification.
- Makefile provides operational commands.

## Common Commands

```bash
make bootstrap              # set up local env and generated secrets
make validate               # validate repo before deployment
make deploy                 # production
make deploy ENV=staging     # staging
make smoke-test             # verify live API response
make status
make logs-api
make destroy
```

## Documentation

Primary documentation is intentionally consolidated:

- docs/INDEX.md
- docs/QUICK-START.md
- docs/DEVELOPER-ONBOARDING.md
- docs/SECRETS-SECURITY.md
- docs/MONITORING.md
- kustomize/SECRET-MANAGEMENT.md

Legacy and historical docs remain in `docs/archive/`.
