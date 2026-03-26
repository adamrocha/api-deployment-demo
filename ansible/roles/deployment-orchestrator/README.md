# Deployment Orchestrator Role

Orchestrates Kubernetes deployments using Kustomize overlays.

## Purpose

This role provides a high-level deployment workflow that:

- Applies Kustomize manifests for the target environment
- Waits for deployments to become ready
- Verifies HPA, PDB, and service configurations
- Provides detailed deployment status

## Dependencies

- `kubectl` installed and configured
- Kustomize overlays at `kustomize/overlays/{environment}/`
- Access to target Kubernetes cluster

## Variables

| Variable               | Default                 | Description                                    |
| ---------------------- | ----------------------- | ---------------------------------------------- |
| `deployment_env`       | `production`            | Target environment (production/staging)        |
| `k8s_namespace`        | `api-deployment-demo`   | Kubernetes namespace                           |
| `k8s_context`          | `kind-api-demo-cluster` | Kubectl context                                |
| `dry_run`              | `false`                 | If true, only build manifests without applying |
| `wait_for_ready`       | `true`                  | Wait for deployments to be ready               |
| `strict_context_check` | `false`                 | Fail if context doesn't match exactly          |
| `deployments_to_wait`  | See defaults            | List of deployments to wait for                |

## Example Usage

```yaml
- hosts: localhost
  roles:
    - role: deployment-orchestrator
      vars:
        deployment_env: production
        wait_for_ready: true
```

## Tasks Performed

1. Verify kubectl and context
2. Build Kustomize manifests (validation)
3. Apply manifests to cluster
4. Wait for deployments to be ready
5. Display status of deployments, pods, services, HPA, PDB

## Notes

- This role uses Kustomize as the single source of truth
- All Kubernetes resource definitions come from `kustomize/base/` and overlays
- This replaces imperative kubectl commands from legacy roles
