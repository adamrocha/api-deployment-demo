# Quick Reference: Make → Ansible Command Mapping

This guide shows how to replace `make` commands with equivalent Ansible playbook commands.

## Setup & Prerequisites

```bash
# Install Ansible collections (one-time setup)
cd ansible && ./install-collections.sh

# Or manually
ansible-galaxy collection install -r ansible/requirements.yml
```

## Environment Deployments

### Staging Environment

| Make Command | Ansible Command |
|--------------|-----------------|
| `make staging` | `ansible-playbook ansible/deploy-staging.yml` |
| `make staging-build` | `ansible-playbook ansible/deploy-staging.yml -e rebuild=true` |
| `make staging-status` | `docker compose ps` (native Docker command) |
| `make staging-logs` | `docker compose logs -f` (native Docker command) |
| `make staging-stop` | `ansible-playbook ansible/cleanup.yml -e level=staging` |

### Production Environment

| Make Command | Ansible Command |
|--------------|-----------------|
| `make production` | `ansible-playbook ansible/deploy-production.yml` |
| `make kind-cluster` | _Included in deploy-production.yml_ |
| `make docker-images` | _Included in deploy-production.yml_ |
| `make docker-push` | _Included in deploy-production.yml_ |
| `make production-status` | `kubectl get pods -n api-deployment-demo` |
| `make production-logs` | `kubectl logs -n api-deployment-demo -l app=api-demo --tail=50 -f` |
| `make production-stop` | `ansible-playbook ansible/cleanup.yml -e level=production` |

### Monitoring Stack

| Make Command | Ansible Command |
|--------------|-----------------|
| `make monitoring` | `ansible-playbook ansible/deploy-monitoring.yml` |
| `make monitoring-status` | `kubectl get pods -n monitoring` |
| `make monitoring-logs` | `kubectl logs -n monitoring -l app=grafana --tail=20` |
| `make start-port-forwarding` | _Automatic in deploy-monitoring.yml_ |
| `make stop-port-forwarding` | `pkill -f "kubectl.*port-forward.*monitoring"` |

## Secrets Management

| Make Command | Ansible Command |
|--------------|-----------------|
| `make generate-secrets ENV=staging` | `ansible-playbook ansible/manage-secrets.yml -e env=staging` |
| `make generate-secrets ENV=production` | `ansible-playbook ansible/manage-secrets.yml -e env=production` |
| `make apply-secrets ENV=production` | `ansible-playbook ansible/manage-secrets.yml -e env=production -e apply=true` |
| `make generate-tls-secrets` | `ansible-playbook ansible/manage-secrets.yml --tags tls -e apply=true` |

## Cleanup Operations

| Make Command | Ansible Command |
|--------------|-----------------|
| `make clean` | `ansible-playbook ansible/cleanup.yml -e level=production` |
| `make clean-staging` | `ansible-playbook ansible/cleanup.yml -e level=staging` |
| `make clean-production` | `ansible-playbook ansible/cleanup.yml -e level=production` |
| `make clean-all` | `ansible-playbook ansible/cleanup.yml -e level=all` |
| `make clean-images` | _Included in cleanup.yml with level=all_ |

## Access Commands

| Make Command | Ansible Equivalent |
|--------------|-------------------|
| `make access-staging` | `echo "Staging: https://localhost:30443"` |
| `make access-production` | `echo "Production: http://localhost"` |
| `make access-monitoring` | `echo "Grafana: http://localhost:3000, Prometheus: http://localhost:9090"` |

## Orchestration & Quick Deploys

| Make Command | Ansible Command |
|--------------|-----------------|
| `make test-automated` | `ansible-playbook ansible/deploy.yml -e mode=full-pipeline` |
| `make quick-staging` | `ansible-playbook ansible/deploy.yml -e mode=staging` |
| `make quick-production` | `ansible-playbook ansible/deploy.yml -e mode=production` |

## Examples

### Deploy Everything (Full Pipeline)

```bash
# Make version
make test-automated

# Ansible version
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

### Deploy Only Staging

```bash
# Make version
make staging

# Ansible version
ansible-playbook ansible/deploy-staging.yml
```

### Deploy Production with Monitoring

```bash
# Make version
make production && make monitoring

# Ansible version
ansible-playbook ansible/deploy-production.yml && \
ansible-playbook ansible/deploy-monitoring.yml

# Or in one command
ansible-playbook ansible/deploy.yml -e mode=production && \
ansible-playbook ansible/deploy-monitoring.yml
```

### Clean and Redeploy Production

```bash
# Make version
make clean-production && make production

# Ansible version
ansible-playbook ansible/cleanup.yml -e level=production && \
ansible-playbook ansible/deploy-production.yml
```

### Generate and Apply Secrets

```bash
# Make version
make generate-secrets ENV=production
make apply-secrets ENV=production

# Ansible version (combined)
ansible-playbook ansible/manage-secrets.yml \
  -e env=production \
  -e apply=true
```

## Additional Ansible Options

### Verbose Output

```bash
ansible-playbook ansible/deploy-staging.yml -v      # Verbose
ansible-playbook ansible/deploy-staging.yml -vv     # More verbose
ansible-playbook ansible/deploy-staging.yml -vvv    # Debug mode
```

### Check Mode (Dry Run)

```bash
ansible-playbook ansible/deploy-production.yml --check
```

### Skip Specific Tasks

```bash
ansible-playbook ansible/deploy-production.yml --skip-tags "build,images"
```

### Run Only Specific Tasks

```bash
ansible-playbook ansible/deploy-production.yml --tags "kubernetes"
```

### List Available Tasks

```bash
ansible-playbook ansible/deploy-production.yml --list-tasks
```

## Benefits of Ansible Over Make

1. **Idempotency**: Safe to run multiple times without side effects
2. **Better Error Handling**: Detailed error messages and automatic retries
3. **State Management**: Track what changed and what didn't
4. **Modularity**: Reusable tasks and roles
5. **Remote Execution**: Can target remote servers (not just localhost)
6. **Built-in Validation**: Health checks and service verification
7. **Rollback Support**: Easier to undo changes
8. **Rich Reporting**: Better output formatting and result aggregation

## Tips

1. **Always run install-collections.sh first** (one-time setup)
2. **Use verbose mode** (`-v`) when troubleshooting
3. **Check mode** (`--check`) to preview changes before applying
4. **Combine playbooks** with `&&` for sequential execution
5. **Set environment variables** with `-e key=value`

## Native Commands Still Useful

Some commands are better run natively:

```bash
# Check Docker Compose status
docker compose ps

# Check Kubernetes pods
kubectl get pods -A

# View logs
docker compose logs -f api
kubectl logs -f -n api-deployment-demo deployment/api-deployment

# Port forwarding (manual)
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Migration Strategy

1. **Phase 1**: Use Ansible alongside Make (both work)
2. **Phase 2**: Gradually replace Make commands with Ansible
3. **Phase 3**: Optionally keep Makefile as thin wrapper:

   ```makefile
   staging:
       ansible-playbook ansible/deploy-staging.yml
   ```

This allows teams to transition gradually while maintaining compatibility.
