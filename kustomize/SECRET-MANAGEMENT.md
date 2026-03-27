# Kustomize Secret Management

Canonical reference for Kustomize secrets in this repository.

## Summary

- Source input: root `.env`
- Generator: `scripts/generate-kustomize-secrets.sh`
- Consumption: `secretGenerator.envs` in each overlay
- Deployment integration: Ansible pre-task in `ansible/deploy.yml`

## Files

### Generated (gitignored)

- `kustomize/overlays/staging/database-credentials.env`
- `kustomize/overlays/staging/api-secrets.env`
- `kustomize/overlays/staging/grafana-secrets.env`
- `kustomize/overlays/production/database-credentials.env`
- `kustomize/overlays/production/api-secrets.env`
- `kustomize/overlays/production/grafana-secrets.env`
- `kustomize/overlays/production/production-secrets.env`

### Declarative manifests

- `kustomize/overlays/staging/kustomization.yaml`
- `kustomize/overlays/production/kustomization.yaml`

## Commands

Generate secrets:

```bash
./scripts/generate-kustomize-secrets.sh staging
./scripts/generate-kustomize-secrets.sh production
```

Rotate secrets:

```bash
./scripts/generate-kustomize-secrets.sh production --rotate
```

Preview manifests:

```bash
kubectl kustomize kustomize/overlays/production
```

Deploy:

```bash
make deploy ENV=production
```

## Important Notes

- Kustomize generated secret names may include hash suffixes.
- Tooling that reads secrets should resolve by prefix if exact names are not present.
- Do not store real secret literals in tracked YAML.
