# Ansible Playbooks for API Deployment Demo

This directory contains Ansible playbooks that replace Makefile commands for deploying and managing the API Deployment Demo infrastructure.

## Prerequisites

Install required Ansible collections:

```bash
ansible-galaxy collection install community.docker
ansible-galaxy collection install kubernetes.core
```

Or use the provided script:

```bash
./install-collections.sh
```

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

**Access:** <https://localhost:30443> (Docker Compose on high ports)

### Deploy Production Environment

```bash
ansible-playbook ansible/deploy-production.yml
```

**Access:** <http://localhost> (Kubernetes on standard ports)

### Deploy Monitoring Stack

```bash
ansible-playbook ansible/deploy-monitoring.yml
```

**Access:**

- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>

### Full Deployment Pipeline

```bash
# Deploy staging -> production -> monitoring
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

### Cleanup

```bash
# Clean everything
ansible-playbook ansible/cleanup.yml -e level=all

# Clean only staging
ansible-playbook ansible/cleanup.yml -e level=staging

# Clean only production
ansible-playbook ansible/cleanup.yml -e level=production
```

## Deployment Modes

The main `deploy.yml` orchestrator supports multiple modes:

### Staging Only

```bash
ansible-playbook ansible/deploy.yml -e mode=staging
```

### Production Only

```bash
ansible-playbook ansible/deploy.yml -e mode=production
```

### Full Pipeline (Staging → Production → Monitoring)

```bash
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

### Monitoring Only

```bash
ansible-playbook ansible/deploy.yml -e mode=monitoring
```

## Secrets Management

### Generate Secrets

```bash
ansible-playbook ansible/manage-secrets.yml -e env=staging
ansible-playbook ansible/manage-secrets.yml -e env=production
```

### Generate and Apply to Cluster

```bash
ansible-playbook ansible/manage-secrets.yml \
  -e env=production \
  -e apply=true \
  -e target_namespace=api-deployment-demo
```

### Generate TLS Secrets

```bash
ansible-playbook ansible/manage-secrets.yml \
  --tags tls \
  -e target_namespace=api-deployment-demo \
  -e tls_secret_name=nginx-ssl-certs \
  -e apply=true
```

## Advanced Usage

### Skip Cleanup Before Deployment

```bash
ansible-playbook ansible/deploy.yml -e mode=production -e no_cleanup=true
```

### Verbose Output

```bash
ansible-playbook ansible/deploy-staging.yml -v
ansible-playbook ansible/deploy-production.yml -vv
```

### Check Mode (Dry Run)

```bash
ansible-playbook ansible/deploy-staging.yml --check
```

### Limit to Specific Tasks

```bash
ansible-playbook ansible/deploy-production.yml --tags "docker,kubernetes"
```

## Comparison: Make vs Ansible

| Make Command | Ansible Equivalent |
|--------------|-------------------|
| `make staging` | `ansible-playbook ansible/deploy-staging.yml` |
| `make production` | `ansible-playbook ansible/deploy-production.yml` |
| `make monitoring` | `ansible-playbook ansible/deploy-monitoring.yml` |
| `make clean-all` | `ansible-playbook ansible/cleanup.yml -e level=all` |
| `make clean-staging` | `ansible-playbook ansible/cleanup.yml -e level=staging` |
| `make generate-secrets ENV=production` | `ansible-playbook ansible/manage-secrets.yml -e env=production` |
| `make test-automated` | `ansible-playbook ansible/deploy.yml -e mode=full-pipeline` |

## Environment Variables

Playbooks respect the following variables:

- `mode`: Deployment mode (staging, production, full-pipeline, monitoring)
- `env`: Environment for secrets (development, staging, production)
- `level`: Cleanup level (all, staging, production, monitoring)
- `apply`: Apply secrets to cluster (true/false)
- `no_cleanup`: Skip cleanup before deployment (true/false)
- `target_namespace`: Kubernetes namespace
- `cluster_name`: Kind cluster name (default: api-demo-cluster)

## Troubleshooting

### Check Ansible Version

```bash
ansible --version  # Should be 2.9+
```

### Verify Collections

```bash
ansible-galaxy collection list
```

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

### Kubernetes Context Errors

If you see errors like "Invalid kube-config file" or "Expected key current-context":

```bash
# Check if Kind cluster exists
kind get clusters

# If no cluster exists, the cleanup playbook will handle it gracefully
# For production/monitoring cleanup, ensure cluster exists first
```

The playbooks are designed to check for cluster existence before attempting Kubernetes operations, so these errors should not occur during normal operation.

## Benefits Over Make

1. **Better Error Handling**: Ansible provides detailed error messages and rollback capabilities
2. **Idempotency**: Can safely run playbooks multiple times
3. **Modularity**: Easy to include/import tasks and roles
4. **State Management**: Track deployment state and changes
5. **Conditional Logic**: Advanced conditionals and loops
6. **Remote Execution**: Can target remote hosts (not just localhost)
7. **Validation**: Built-in validation and testing capabilities
8. **Reporting**: Better output formatting and result aggregation

## Next Steps

- Customize `group_vars/` for environment-specific configurations
- Add custom roles in `roles/` directory
- Extend playbooks with additional deployment scenarios
- Integrate with CI/CD pipelines
- Add dynamic inventory for multi-host deployments

## Support

For issues or questions:

- Check existing roles in `ansible/roles/`
- Review `ansible/inventory.ini` for host configuration
- Run validation: `./validate-ansible.sh`
