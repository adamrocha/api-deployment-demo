# Secrets and Security

This document defines the current secrets workflow and security rules.

## Non-Negotiable Rules

- Never commit real secrets.
- Keep generated secret files gitignored.
- Rotate secrets after incidents or credential exposure.

## Current Secret Flow

### 1. Root `.env` is the input source

Secrets are read from `.env` at repository root.

### 2. Kustomize overlay env files are generated

Script:

```bash
./scripts/generate-kustomize-secrets.sh staging
./scripts/generate-kustomize-secrets.sh production
```

Generated files include:

- `kustomize/overlays/<env>/database-credentials.env`
- `kustomize/overlays/<env>/api-secrets.env`
- `kustomize/overlays/<env>/grafana-secrets.env`
- `kustomize/overlays/production/production-secrets.env`

### 3. Kustomize secretGenerator consumes env files

Overlays use `secretGenerator.envs` in:

- `kustomize/overlays/staging/kustomization.yaml`
- `kustomize/overlays/production/kustomization.yaml`

### 4. Ansible pre-task generates secrets during deploy

Deployment playbook runs the generator before apply.

## Secret Name Behavior

Kustomize appends hash suffixes to generated Secret names by default.

Example:

- `database-credentials-h8h487fmgc`

Operational scripts should resolve secrets by prefix, not exact name.

## Rotation

Force regeneration:

```bash
./scripts/generate-kustomize-secrets.sh production --rotate
make deploy ENV=production
```

## Validation

```bash
make validate
make get-secrets
kubectl get secrets -n api-deployment-demo-ns
```

## Hardening Recommendations

For production beyond local demo use:

- External Secrets Operator
- Sealed Secrets
- Cloud secret managers (AWS/GCP/Azure)
