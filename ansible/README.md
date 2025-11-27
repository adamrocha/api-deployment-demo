# Ansible Playbooks for API Deployment Demo

This directory contains Ansible playbooks that replace Makefile commands for deploying and managing the API Deployment Demo infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Playbook Overview](#playbook-overview)
- [Quick Start](#quick-start)
- [Make to Ansible Command Reference](#make-to-ansible-command-reference)
- [Deployment Modes](#deployment-modes)
- [Secrets Management](#secrets-management)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Benefits Over Make](#benefits-over-make)

## Prerequisites

Install required Ansible collections:

```bash
# Run the install script (recommended)
cd ansible && ./install-collections.sh

# Or manually install collections
ansible-galaxy collection install community.docker kubernetes.core
```

**Requirements:**
- Ansible 2.9+
- Docker & Docker Compose v2
- kubectl and kind (for production deployments)
- Python 3.8+

## Playbook Overview

| Playbook | Replaces Make Command | Description |
|----------|----------------------|-------------|
| `deploy-staging.yml` | `make staging` | Deploy Docker Compose staging environment |
| `deploy-production.yml` | `make production` | Deploy Kubernetes production with Kind |
| `deploy-monitoring.yml` | `make monitoring` | Deploy Prometheus & Grafana monitoring |
| `manage-secrets.yml` | `make generate-secrets`, `make apply-secrets` | Manage Kubernetes secrets |
| `cleanup.yml` | `make clean-all`, `make clean-staging` | Clean up environments |
| `deploy.yml` | `make test-automated`, `make quick-production` | Main orchestration playbook |

## Quick Start

### Deploy Staging Environment

```bash
ansible-playbook ansible/deploy-staging.yml
```

**Access:**
- Web (HTTPS): https://localhost:30443
- API Direct: http://localhost:30800/health
- Database: localhost:35432

⚠️ **Important:** Always use HTTPS (port 30443) for web access. Accept browser warnings for self-signed certificates.

### Deploy Production Environment

```bash
ansible-playbook ansible/deploy-production.yml
```

**Access:**
- Web: http://localhost
- API: http://localhost:8000
- Kubernetes Dashboard: `kubectl proxy`

### Deploy Monitoring Stack

```bash
ansible-playbook ansible/deploy-monitoring.yml
```

**Access:**
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090

### Full Deployment Pipeline

```bash
# Deploy staging → production → monitoring
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

### Cleanup

```bash
# Clean everything (Docker images, Kubernetes cluster, volumes)
ansible-playbook ansible/cleanup.yml -e level=all

# Clean only staging
ansible-playbook ansible/cleanup.yml -e level=staging

# Clean only production
ansible-playbook ansible/cleanup.yml -e level=production

# Clean only monitoring
ansible-playbook ansible/cleanup.yml -e level=monitoring
```

## Make to Ansible Command Reference

### Environment Deployments

#### Staging Environment

| Make Command | Ansible Command |
|--------------|-----------------|
| `make staging` | `ansible-playbook ansible/deploy-staging.yml` |
| `make staging-build` | `ansible-playbook ansible/deploy-staging.yml -e rebuild=true` |
| `make staging-status` | `docker compose ps` |
| `make staging-logs` | `docker compose logs -f` |
| `make staging-stop` | `ansible-playbook ansible/cleanup.yml -e level=staging` |

#### Production Environment

| Make Command | Ansible Command |
|--------------|-----------------|
| `make production` | `ansible-playbook ansible/deploy-production.yml` |
| `make kind-cluster` | _Included in deploy-production.yml_ |
| `make docker-images` | _Included in deploy-production.yml_ |
| `make production-status` | `kubectl get pods -n api-deployment-demo` |
| `make production-logs` | `kubectl logs -n api-deployment-demo -l app=api-demo --tail=50 -f` |
| `make production-stop` | `ansible-playbook ansible/cleanup.yml -e level=production` |

#### Monitoring Stack

| Make Command | Ansible Command |
|--------------|-----------------|
| `make monitoring` | `ansible-playbook ansible/deploy-monitoring.yml` |
| `make monitoring-status` | `kubectl get pods -n monitoring` |
| `make start-port-forwarding` | _Automatic in deploy-monitoring.yml_ |
| `make stop-port-forwarding` | `pkill -f "kubectl.*port-forward.*monitoring"` |

### Secrets Management

| Make Command | Ansible Command |
|--------------|-----------------|
| `make generate-secrets ENV=staging` | `ansible-playbook ansible/manage-secrets.yml -e env=staging` |
| `make generate-secrets ENV=production` | `ansible-playbook ansible/manage-secrets.yml -e env=production` |
| `make apply-secrets ENV=production` | `ansible-playbook ansible/manage-secrets.yml -e env=production -e apply=true` |
| `make generate-tls-secrets` | `ansible-playbook ansible/manage-secrets.yml --tags tls -e apply=true` |

### Cleanup Operations

| Make Command | Ansible Command |
|--------------|-----------------|
| `make clean` | `ansible-playbook ansible/cleanup.yml -e level=production` |
| `make clean-staging` | `ansible-playbook ansible/cleanup.yml -e level=staging` |
| `make clean-production` | `ansible-playbook ansible/cleanup.yml -e level=production` |
| `make clean-all` | `ansible-playbook ansible/cleanup.yml -e level=all` |

### Orchestration Commands

| Make Command | Ansible Command |
|--------------|-----------------|
| `make test-automated` | `ansible-playbook ansible/deploy.yml -e mode=full-pipeline` |
| `make quick-staging` | `ansible-playbook ansible/deploy.yml -e mode=staging` |
| `make quick-production` | `ansible-playbook ansible/deploy.yml -e mode=production` |

## Deployment Modes

The main `deploy.yml` orchestrator supports multiple modes:

### Staging Only

```bash
ansible-playbook ansible/deploy.yml -e mode=staging
```

Deploys only the Docker Compose staging environment.

### Production Only

```bash
ansible-playbook ansible/deploy.yml -e mode=production
```

Deploys only the Kubernetes production environment.

### Full Pipeline (Staging → Production → Monitoring)

```bash
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

Complete deployment pipeline with health checks between stages.

### Monitoring Only

```bash
ansible-playbook ansible/deploy.yml -e mode=monitoring
```

Deploys only the monitoring stack (Prometheus & Grafana).

### Skip Cleanup

```bash
ansible-playbook ansible/deploy.yml -e mode=production -e no_cleanup=true
```

Deploy without cleaning up existing resources first.

## Secrets Management

### Generate Secrets

```bash
# Generate secrets for staging
ansible-playbook ansible/manage-secrets.yml -e env=staging

# Generate secrets for production
ansible-playbook ansible/manage-secrets.yml -e env=production
```

This generates secret files in `kubernetes/secrets-{env}.yaml` but doesn't apply them to the cluster.

### Generate and Apply to Cluster

```bash
ansible-playbook ansible/manage-secrets.yml \
  -e env=production \
  -e apply=true \
  -e target_namespace=api-deployment-demo
```

Generates secrets and immediately applies them to the Kubernetes cluster.

### Generate TLS Secrets

```bash
ansible-playbook ansible/manage-secrets.yml \
  --tags tls \
  -e target_namespace=api-deployment-demo \
  -e tls_secret_name=nginx-ssl-certs \
  -e apply=true
```

Generates TLS certificates and applies them to the cluster.

## Advanced Usage

### Verbose Output

```bash
# Verbose
ansible-playbook ansible/deploy-staging.yml -v

# More verbose
ansible-playbook ansible/deploy-staging.yml -vv

# Debug mode
ansible-playbook ansible/deploy-production.yml -vvv
```

### Check Mode (Dry Run)

```bash
ansible-playbook ansible/deploy-staging.yml --check
```

Shows what would change without making any actual changes.

### List Tasks

```bash
ansible-playbook ansible/deploy-production.yml --list-tasks
```

Shows all tasks that would be executed.

### Run Specific Tags

```bash
ansible-playbook ansible/deploy-production.yml --tags "kubernetes"
ansible-playbook ansible/manage-secrets.yml --tags "tls"
```

### Skip Specific Tags

```bash
ansible-playbook ansible/deploy-production.yml --skip-tags "build,images"
```

### Combine Multiple Deployments

```bash
# Deploy production then monitoring
ansible-playbook ansible/deploy-production.yml && \
ansible-playbook ansible/deploy-monitoring.yml

# Clean and redeploy production
ansible-playbook ansible/cleanup.yml -e level=production && \
ansible-playbook ansible/deploy-production.yml
```

## Environment Variables

Playbooks respect the following variables:

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `mode` | staging, production, full-pipeline, monitoring | - | Deployment mode for orchestrator |
| `env` | development, staging, production | development | Environment for secrets |
| `level` | all, staging, production, monitoring | - | Cleanup level |
| `apply` | true, false | false | Apply secrets to cluster |
| `no_cleanup` | true, false | false | Skip cleanup before deployment |
| `target_namespace` | string | api-deployment-demo | Kubernetes namespace |
| `cluster_name` | string | api-demo-cluster | Kind cluster name |

## Troubleshooting

### Check Ansible Version

```bash
ansible --version  # Should be 2.9+
```

### Verify Collections

```bash
ansible-galaxy collection list
```

Should show `community.docker` and `kubernetes.core`.

### Test Connection

```bash
ansible localhost -m ping
```

### View Playbook Tasks

```bash
ansible-playbook ansible/deploy-staging.yml --list-tasks
```

### Debug Mode

```bash
ansible-playbook ansible/deploy-production.yml -vvv
```

### Common Warnings

You may see these warnings - they are **expected and safe to ignore**:

```text
[WARNING]: No inventory was parsed, only implicit localhost is available
[WARNING]: provided hosts list is empty, only localhost is available
```

These occur because playbooks target `localhost` directly for Docker Compose and Kubernetes operations, which is the intended behavior.

### Kubernetes Context Errors

If you see errors like "Invalid kube-config file" or "Expected key current-context":

```bash
# Check if Kind cluster exists
kind get clusters

# If no cluster exists, the cleanup playbook handles it gracefully
# For production/monitoring cleanup, ensure cluster exists first
```

The playbooks check for cluster existence before attempting Kubernetes operations.

### Port Conflicts

If ports are already in use:

```bash
# Check what's using the ports
lsof -i :30080,30443,30800  # Staging ports
lsof -i :80,443,8000,3000,9090  # Production ports

# Clean up existing deployments
ansible-playbook ansible/cleanup.yml -e level=all
```

### Docker Issues

```bash
# Restart Docker daemon
# macOS: Click Docker icon → Restart

# Check Docker status
docker ps
docker compose ps

# Clean Docker resources
docker system prune -a --volumes
```

## Benefits Over Make

1. **Better Error Handling**: Ansible provides detailed error messages and rollback capabilities
2. **Idempotency**: Can safely run playbooks multiple times without side effects
3. **Modularity**: Easy to include/import tasks and create reusable roles
4. **State Management**: Track what changed and what didn't
5. **Conditional Logic**: Advanced conditionals, loops, and variable handling
6. **Remote Execution**: Can target remote hosts (not just localhost)
7. **Built-in Validation**: Health checks, retries, and service verification
8. **Reporting**: Better output formatting and result aggregation
9. **Rollback Support**: Easier to undo changes when needed
10. **Cross-platform**: Works consistently across different operating systems

## Native Commands Still Useful

Some operations are better run with native tools:

```bash
# Docker Compose
docker compose ps                    # Check status
docker compose logs -f api          # View logs
docker compose exec api bash        # Shell into container

# Kubernetes
kubectl get pods -A                  # List all pods
kubectl logs -f pod-name            # View logs
kubectl describe pod pod-name       # Pod details
kubectl exec -it pod-name -- bash   # Shell into pod

# Port forwarding (manual)
kubectl port-forward -n monitoring svc/grafana 3000:3000
```

## Migration Strategy

Transition from Make to Ansible gradually:

1. **Phase 1**: Use Ansible alongside Make (both work)
2. **Phase 2**: Gradually replace Make commands with Ansible
3. **Phase 3**: Optionally keep Makefile as thin wrapper:

   ```makefile
   staging:
       ansible-playbook ansible/deploy-staging.yml
   
   production:
       ansible-playbook ansible/deploy-production.yml
   
   clean-all:
       ansible-playbook ansible/cleanup.yml -e level=all
   ```

This allows teams to transition gradually while maintaining compatibility.

## Examples

### Complete Workflow

```bash
# 1. Clean everything
ansible-playbook ansible/cleanup.yml -e level=all

# 2. Deploy full pipeline
ansible-playbook ansible/deploy.yml -e mode=full-pipeline

# 3. Check status
docker compose ps                              # Staging
kubectl get pods -n api-deployment-demo        # Production
kubectl get pods -n monitoring                 # Monitoring
```

### Development Workflow

```bash
# Deploy staging for testing
ansible-playbook ansible/deploy-staging.yml

# Make changes to code...

# Redeploy staging
ansible-playbook ansible/cleanup.yml -e level=staging
ansible-playbook ansible/deploy-staging.yml

# When ready, deploy to production
ansible-playbook ansible/deploy-production.yml
```

### CI/CD Integration

```bash
# In your CI/CD pipeline
- name: Deploy to Staging
  run: ansible-playbook ansible/deploy-staging.yml

- name: Run Tests
  run: pytest tests/

- name: Deploy to Production
  run: ansible-playbook ansible/deploy-production.yml
  if: github.ref == 'refs/heads/main'
```

## Support

For issues or questions:
- Review playbook documentation in this directory
- Check the main project README
- Run verbose mode (`-vvv`) to debug issues
- Use check mode (`--check`) to preview changes
