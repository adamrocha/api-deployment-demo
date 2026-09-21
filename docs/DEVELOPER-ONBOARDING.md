# Developer Onboarding

This guide covers the supported first-run workflow for a fresh clone of this repository.

## Prerequisites

Install the following before running the project:

- Docker
- Kind
- kubectl
- Ansible
- Python 3.12+
- Poetry

## First-run setup

From the project root:

```bash
make bootstrap
```

This creates local defaults if they are missing and generates the required Kustomize secret env files before validation.

## Validate the repo

```bash
make validate
```

This checks:

- Docker Compose config
- Kustomize app overlays
- Kustomize monitoring overlays
- Ansible syntax
- shell script syntax

## Cluster and deployment flow

```bash
make cluster
make deploy
```

For staging:

```bash
make deploy ENV=staging
```

## Operational checks

Check status:

```bash
make status
```

Show access endpoints:

```bash
make urls
```

Runtime smoke test:

```bash
make smoke-test
```

This validates the live API and confirms the app is actually responding at runtime.

## Useful commands

```bash
make logs
make logs-api
make health
make get-secrets
make destroy
```

## Security notes

- Never commit real secrets
- Keep generated secret files local to the repo
- Use `make bootstrap` instead of relying on hidden manual setup
- Prefer `make validate` before deployment changes
