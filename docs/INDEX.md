# Documentation Index

This project uses a small set of canonical docs to reduce duplication.

## Start Here

1. [README](../README.md): project overview and entry commands
2. [Quick Start](./QUICK-START.md): operational runbook including bootstrap and smoke testing
3. [Developer Onboarding](./DEVELOPER-ONBOARDING.md): first-run and contributor setup
4. [Secrets and Security](./SECRETS-SECURITY.md): security expectations and guardrails

## Fresh-Setup Checklist

- Run `make bootstrap` on a new clone
- Confirm `.env` and `terraform/terraform.tfvars` were created from templates if missing
- Validate the repo with `make validate`
- Create the cluster with `make cluster`
- Deploy with `make deploy` or `make deploy ENV=staging`
- Run `make smoke-test` against the live API

## Topic Guides

- [Monitoring](./MONITORING.md): Prometheus and Grafana operations
- [Kustomize Secret Management](../kustomize/SECRET-MANAGEMENT.md): Kustomize secret workflow details

## Canonical Rules

- Command references should match `Makefile`.
- Secret workflow references should match `scripts/generate-kustomize-secrets.sh`.
- Kubernetes manifest behavior should match files under `kustomize/`.

## Archived Material

Historical docs are in [archive](./archive/) and are not the current operational source.
