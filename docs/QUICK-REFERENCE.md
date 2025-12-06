# Quick Reference: Terraform + Ansible + Make

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────┐
│               MAKE (Orchestration)               │
│  Simple commands for complex workflows           │
└─────────────────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
┌──────────────────┐       ┌──────────────────┐
│   TERRAFORM      │       │    ANSIBLE       │
│  Infrastructure  │       │  Configuration   │
│   Provisioning   │       │   Management     │
└──────────────────┘       └──────────────────┘
        │                           │
        └─────────────┬─────────────┘
                      ▼
        ┌─────────────────────────────┐
        │   Kubernetes / Docker        │
        │    Running Applications      │
        └─────────────────────────────┘
```

## When to Use What

### Use Terraform When

- Creating/destroying infrastructure
- Provisioning new environments
- Changing resource definitions (deployments, services)
- Managing infrastructure state
- Building and loading Docker images

### Use Ansible When

- Configuring existing deployments
- Scaling applications dynamically
- Tuning performance parameters
- Setting environment variables
- Applying runtime configurations
- Managing operational tasks

### Use Make When

- Running any command (provides consistent interface)
- Chaining Terraform and Ansible operations
- Executing CI/CD pipelines
- Troubleshooting and validation

## Common Workflows

### Initial Deployment

```bash
# Full deployment (recommended)
make deploy-production-full

# Or step by step
make tf-production          # Terraform provisions
make ansible-k8s-all        # Ansible configures
```

### Configuration Update (No Infrastructure Change)

```bash
# Scale replicas
make ansible-k8s-config api_replicas=5

# Tune database
make ansible-k8s-tune db_shared_buffers=512MB
```

### Infrastructure Update

```bash
# Review changes
make tf-plan-production

# Apply changes
make tf-production
```

### Quick Operations

```bash
# Status
kubectl get pods -n api-deployment-demo

# Logs
kubectl logs -n api-deployment-demo deployment/api-deployment

# Shell access
kubectl exec -it -n api-deployment-demo deployment/api-deployment -- sh

# Resource usage
kubectl top pods -n api-deployment-demo
```

## Command Comparison

| Task | Terraform | Ansible | Make |
|------|-----------|---------|------|
| Deploy everything | `terraform apply` | N/A | `make deploy-production-full` |
| Scale API to 3 | Change code + apply | `ansible-playbook ... -e api_replicas=3` | `make ansible-k8s-config api_replicas=3` |
| Update env var | Change code + apply | `ansible-playbook ...` | `make ansible-k8s-config` |
| Add new service | Add resource + apply | N/A | `make tf-production` |
| Tune performance | N/A | `ansible-playbook --tags tuning` | `make ansible-k8s-tune` |
| Destroy | `terraform destroy` | N/A | `make tf-destroy-production` |

## File Locations

```
api-deployment-demo/
├── terraform/              # Infrastructure as Code
│   ├── production.tf       # Production Kubernetes resources
│   ├── staging.tf          # Staging Docker Compose
│   ├── monitoring.tf       # Prometheus + Grafana
│   ├── docker.tf           # Image builds
│   └── variables.tf        # Configuration variables
│
├── ansible/                # Configuration Management
│   ├── kubernetes.yml      # Kubernetes config playbook
│   ├── site.yml            # General deployment playbook
│   └── roles/
│       ├── kubernetes-config/   # K8s configuration
│       └── kubernetes-tuning/   # K8s optimization
│
├── Makefile                # Orchestration
├── CI-CD-WORKFLOWS.md      # Complete workflow guide
└── QUICK-REFERENCE.md      # This file
```

## Environment Variables

```bash
# Set environment
export ENV=production

# Custom configuration
export TF_VAR_replicas=3
export ANSIBLE_TAGS="config,tuning"
```

## Troubleshooting

### Terraform Issues

```bash
# Validate configuration
cd terraform && terraform validate

# Check state
make tf-output

# Clean and reinitialize
make tf-clean && make tf-init
```

### Ansible Issues

```bash
# Validate playbook
make ansible-validate

# Check mode (dry-run)
cd ansible && ansible-playbook kubernetes.yml --check

# Verbose mode
cd ansible && ansible-playbook kubernetes.yml -vvv
```

### Kubernetes Issues

```bash
# Check pods
kubectl get pods -n api-deployment-demo

# Describe pod
kubectl describe pod -n api-deployment-demo <pod-name>

# View logs
kubectl logs -n api-deployment-demo <pod-name>

# Events
kubectl get events -n api-deployment-demo --sort-by='.lastTimestamp'
```

## Quick Commands Cheatsheet

```bash
# Deployment
make deploy-production-full    # Complete production deployment
make deploy-staging-full       # Complete staging deployment

# Configuration
make ansible-k8s-config        # Apply configuration
make ansible-k8s-tune          # Apply tuning
make ansible-k8s-all           # Both config and tuning

# Infrastructure
make tf-production             # Terraform apply production
make tf-staging                # Terraform apply staging
make tf-plan-production        # Review changes
make tf-output                 # Show outputs

# CI/CD
make ci-pipeline               # Build, test, deploy staging
make ci-promote                # Promote to production

# Cleanup
make clean-all                 # Clean everything
make tf-destroy-production     # Destroy production
make tf-clean                  # Clean Terraform state
```

## Access URLs

### Staging (Docker Compose)

- HTTPS: <https://localhost:30443>
- API: <http://localhost:30800>
- DB: localhost:35432

### Production (Kubernetes)

- Web: <http://localhost:80> or <https://localhost:443>
- API: <http://localhost:8000>
- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>

## Best Practices

1. **Always validate before applying**

   ```bash
   make tf-plan-production
   ```

2. **Test in staging first**

   ```bash
   make deploy-staging-full && make test
   ```

3. **Use Ansible for runtime changes**
   - Scaling, env vars, tuning

4. **Use Terraform for structural changes**
   - New services, resource definitions

5. **Use Make for everything else**
   - Provides consistency and documentation
