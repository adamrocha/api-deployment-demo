# Documentation Index

This project uses a small set of canonical docs to reduce duplication.

## Start Here

1. [README](../README.md): project overview and entry commands
2. [Quick Start](./QUICK-START.md): operational runbook
3. [Secrets and Security](./SECRETS-SECURITY.md): security expectations and guardrails

## Topic Guides

- [Monitoring](./MONITORING.md): Prometheus and Grafana operations
- [Kustomize Secret Management](../kustomize/SECRET-MANAGEMENT.md): Kustomize secret workflow details

## Canonical Rules

- Command references should match `Makefile`.
- Secret workflow references should match `scripts/generate-kustomize-secrets.sh`.
- Kubernetes manifest behavior should match files under `kustomize/`.

## Archived Material

Historical docs are in [archive](./archive/) and are not the current operational source.
