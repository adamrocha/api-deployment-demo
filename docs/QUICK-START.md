# Quick Start

Operational runbook for deploying and managing this repository.

## Prerequisites

- Docker
- Kind
- kubectl
- Ansible
- Python 3.12+
- Poetry

## First Deployment

For a fresh clone, bootstrap and validate before deploying:

```bash
make bootstrap
make validate
make cluster
make deploy
make smoke-test
```

## Core Commands

```bash
make bootstrap
make validate
make deploy
make deploy ENV=staging
make status
make urls
make logs-api
make logs-nginx
make smoke-test
make get-secrets
make destroy
```

## Access Endpoints

- Web: <https://localhost>:8443
- API: <http://localhost:8000>
- API Docs: <http://localhost:8000/docs>
- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>

## Configuration Changes

### Scale via overlays

Edit the relevant overlay and redeploy:

- `kustomize/overlays/production/kustomization.yaml`
- `kustomize/overlays/staging/kustomization.yaml`

Then run:

```bash
make deploy ENV=production
```

### Update env/config

Edit base config maps and redeploy:

```bash
make deploy
```

## Troubleshooting

```bash
make status
kubectl get pods -n api-deployment-demo-ns
kubectl get events -n api-deployment-demo-ns --sort-by='.lastTimestamp' | tail -20
make logs-api
make logs-nginx
```

If a rollout is stuck:

```bash
kubectl rollout status deployment/api-deployment -n api-deployment-demo-ns
kubectl rollout history deployment/api-deployment -n api-deployment-demo-ns
```
