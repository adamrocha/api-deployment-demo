# Terraform Infrastructure as Code

This directory contains Terraform configurations to provision and manage the Kubernetes-based production infrastructure for the API Deployment Demo.

## Overview

Terraform manages:

- 🐳 **Docker image builds** (API and Nginx containers)
- ☸️ **Kubernetes resources** (deployments, services, secrets, ConfigMaps)
- 📊 **Monitoring stack** (Prometheus and Grafana)
- 🔐 **Secrets and TLS certificates**

## Architecture

```text
┌─────────────┐    ┌──────────────┐    ┌────────────────┐
│   Makefile  │───▶│  Terraform   │───▶│    Ansible     │
│  (Wrapper)  │    │ (Provision)  │    │ (Configure)    │
└─────────────┘    └──────────────┘    └────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ Kind Cluster │
                   │  (Kubernetes)│
                   └──────────────┘
```

## Prerequisites

- Terraform >= 1.0
- Docker Desktop
- kubectl
- kind
- Make

## Quick Start

### Recommended: Use Makefile

The easiest way to deploy is through the Makefile at the project root:

```bash
# Full deployment (build + provision + configure)
make deploy

# Step by step
make build      # Build Docker images
make cluster    # Create Kind cluster
make apply      # Run Terraform
make config     # Run Ansible configuration
```

### Direct Terraform Usage

If you need to run Terraform directly:

```bash
# 1. Generate secrets
../scripts/generate-secrets.sh terraform

# 2. Initialize Terraform
terraform init

# 3. Create Kind cluster (if not exists)
kind create cluster --name api-demo-cluster --config ../kind-config.yaml

# 4. Plan and apply
terraform plan -var="environment=production" -var="enable_monitoring=true"
terraform apply -var="environment=production" -var="enable_monitoring=true" -auto-approve
```

## Configuration

### Required: terraform.tfvars

Terraform requires a `terraform.tfvars` file with sensitive credentials. **Never commit this file.**

**Generate automatically (recommended):**

```bash
# From project root
./scripts/generate-secrets.sh terraform
```

This script generates cryptographically secure passwords and creates both `terraform.tfvars` and Kubernetes secret manifests.

**Or create manually from template:**

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit and replace placeholder values with secure passwords
```

**Required variables:**

- `db_password` - PostgreSQL database password (32+ characters)
- `secret_key` - API application secret key (32+ characters)
- `grafana_password` - Grafana admin password (32+ characters)

**Important:** The `make apply` command automatically runs secret generation to ensure secrets are synchronized between Terraform and Kubernetes.

### Variables Reference

| Variable            | Type   | Default                 | Description                   |
| ------------------- | ------ | ----------------------- | ----------------------------- |
| `environment`       | string | `"production"`          | Deployment environment        |
| `project_name`      | string | `"api-deployment-demo"` | Project identifier            |
| `cluster_name`      | string | `"api-demo-cluster"`    | Kind cluster name             |
| `replicas`          | number | `2`                     | Number of API replicas        |
| `enable_monitoring` | bool   | `true`                  | Deploy Prometheus/Grafana     |
| `db_password`       | string | *(required)*            | Database password             |
| `secret_key`        | string | *(required)*            | API secret key                |
| `grafana_password`  | string | *(required)*            | Grafana password              |

## Module Organization

The Terraform configuration is split into logical modules:

| File            | Purpose                                            |
| --------------- | -------------------------------------------------- |
| `providers.tf`  | Provider configurations (Docker, Kubernetes, Null) |
| `variables.tf`  | Input variable definitions                         |
| `outputs.tf`    | Output values (cluster name, namespace, URLs)      |
| `docker.tf`     | Docker image builds for API and Nginx              |
| `production.tf` | Kubernetes deployments, services, ingress          |
| `monitoring.tf` | Prometheus and Grafana monitoring stack            |

## Common Commands

### View Infrastructure

```bash
# Show current outputs
terraform output

# Show resources
terraform state list

# Inspect specific resource
terraform state show kubernetes_deployment.api
```

### Update Infrastructure

```bash
# Preview changes
terraform plan -var="environment=production" -var="enable_monitoring=true"

# Apply specific changes
terraform apply -target=kubernetes_deployment.api

# Refresh state
terraform refresh
```

### Troubleshooting

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# View logs (via kubectl)
kubectl logs -n api-deployment-demo -l component=api --tail=50
```

## Security Best Practices

### ✅ DO

- ✅ Generate secrets with `./scripts/generate-secrets.sh terraform`
- ✅ Use strong random passwords (32+ characters)
- ✅ Keep `terraform.tfvars` permissions at 600 (`chmod 600 terraform.tfvars`)
- ✅ Run security audits regularly: `./scripts/security-audit.sh`
- ✅ Review Terraform plans before applying
- ✅ Use Kubernetes secrets for sensitive data

### ❌ DON'T

- ❌ **Never commit `terraform.tfvars` to git** (already in .gitignore)
- ❌ Don't hardcode passwords in `.tf` files
- ❌ Don't share terraform.tfvars via insecure channels
- ❌ Don't use weak or default passwords
- ❌ Don't commit `.terraform.lock.hcl` if using different platforms

## Integration with Make & Ansible

This project uses a **layered deployment approach**:

### 1. Makefile (Orchestration Layer)

- Provides simple commands (`make deploy`, `make status`)
- Handles prerequisites (cluster creation, image builds)
- Coordinates Terraform and Ansible

### 2. Terraform (Provisioning Layer)

- Creates infrastructure resources
- Builds and manages Docker images
- Deploys Kubernetes objects
- Sets up monitoring stack

### 3. Ansible (Configuration Layer)

- Applies ConfigMaps and additional configuration
- Tunes deployment settings
- Manages Kubernetes-specific customizations

**Recommended workflow:**

```bash
make deploy    # Runs: build → terraform apply → ansible-playbook
```

**For Terraform-only changes:**

```bash
make plan      # Preview Terraform changes
make apply     # Apply Terraform + sync secrets
```

**Note:** `make apply` automatically:

1. Initializes Terraform
2. Creates Kind cluster (if needed)
3. Applies Terraform changes
4. Generates and synchronizes Kubernetes secrets

## Managed Resources

Terraform fully manages all infrastructure resources. **Do not manually create or modify these resources** - use Terraform exclusively:

### Core Infrastructure

- **Namespaces:** `api-deployment-demo`, `monitoring`
- **Deployments:** API, PostgreSQL, Nginx, Prometheus, Grafana, Kube-State-Metrics
- **Services:** API, PostgreSQL, Nginx, Prometheus, Grafana
- **Secrets:** `api-secrets`, `database-credentials`, `grafana-admin-secret`
- **ConfigMaps:** Prometheus config, Grafana dashboards, datasources, Nginx config

### Docker Images

- `api-deployment-demo-api:latest`
- `api-deployment-demo-nginx:latest`

### Important Notes

**Secret Key Format:**
All Kubernetes secrets created by Terraform use **uppercase with underscores** for environment variable keys:

- ✅ `SECRET_KEY` (correct)
- ❌ `secret-key` (incorrect)

**Nginx Deployment:**
Nginx is fully managed by Terraform via `production.tf`. The `kubernetes/nginx-deployment.yaml` file is for reference only and should not be applied manually.

**State Management:**
All resources are tracked in `terraform.tfstate`. If you manually create/delete resources, you must import/remove them from state to avoid conflicts.

## Access URLs

After deployment, access the application at:

- **Web (HTTPS):** <https://localhost>
- **API:** <http://localhost:8000>
- **API Docs:** <http://localhost:8000/docs>
- **Grafana:** <http://localhost:3000> (username: `admin`, password: from `terraform.tfvars`)
- **Prometheus:** <http://localhost:9090>

## Cleanup

### Remove Deployment (Keep Cluster)

```bash
# Via Makefile (recommended)
make clean

# Direct Terraform
terraform destroy -var="environment=production" -var="enable_monitoring=true"
```

### Complete Cleanup

```bash
# Nuclear option - removes everything
make clean-all

# Manual cleanup
kind delete cluster --name api-demo-cluster
cd terraform && rm -rf .terraform/ .terraform.lock.hcl terraform.tfstate*
```

## State Management

### Local State (Default)

By default, Terraform stores state locally in `terraform.tfstate`. This works fine for:

- Individual developers
- Learning/testing
- Single-machine deployments

**⚠️ Warning:** Local state files may contain sensitive data. Never commit them.

### Remote State (Team Collaboration)

For team environments, use remote state backends:

**Example: S3 Backend**

```hcl
# In providers.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "api-deployment-demo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

**Other options:**

- Terraform Cloud (recommended for teams)
- Azure Blob Storage
- Google Cloud Storage
- HashiCorp Consul

## Troubleshooting

### Common Deployment Issues

**CreateContainerConfigError: Secret Key Not Found**

If pods fail with `Error: couldn't find key SECRET_KEY in Secret`, this indicates a mismatch between the secret key name and the deployment reference.

```bash
# Verify the secret has the correct key
kubectl get secret api-secrets -n api-deployment-demo -o jsonpath='{.data}' | jq

# The secret should contain "SECRET_KEY" (uppercase with underscore)
# If it shows "secret-key" (lowercase with hyphen), recreate it:
kubectl delete secret api-secrets -n api-deployment-demo
make apply  # Terraform will recreate with correct format
```

**Grafana Pod Failing: grafana-admin-secret Not Found**

The Grafana admin password secret is automatically created by Terraform.

```bash
# Verify the secret exists
kubectl get secret grafana-admin-secret -n monitoring

# If missing, import existing or let Terraform create it
terraform import -var="environment=production" -var="enable_monitoring=true" \
  'kubernetes_secret_v1.grafana_admin[0]' monitoring/grafana-admin-secret
```

**Terraform State Corruption: Unexpected Identity Change**

If you see "Unexpected Identity Change" errors during apply:

```bash
# Remove corrupted state entry
terraform state rm 'kubernetes_deployment_v1.grafana[0]'

# Import the existing resource
terraform import -var="environment=production" -var="enable_monitoring=true" \
  'kubernetes_deployment_v1.grafana[0]' monitoring/grafana

# Apply again
make apply
```

### Docker Provider Issues

```bash
# Verify Docker is running
docker ps

# Rebuild images
make build

# Check Terraform Docker provider
terraform state list | grep docker_image
```

### Kubernetes Provider Issues

```bash
# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check Kind cluster
kind get clusters

# Verify namespace exists
kubectl get ns api-deployment-demo
```

### Secrets Not Applied

```bash
# Regenerate secrets (automatically called by make apply)
./scripts/generate-secrets.sh terraform

# Verify terraform.tfvars exists
ls -la terraform/terraform.tfvars

# Check secrets in cluster
kubectl get secrets -n api-deployment-demo
kubectl get secrets -n monitoring

# Verify secret contents (base64 encoded)
kubectl get secret api-secrets -n api-deployment-demo -o yaml
```

### Image Build Failures

```bash
# Check Docker daemon
docker info

# Build images manually
docker build -t api-deployment-demo-api:latest api/
docker build -t api-deployment-demo-nginx:latest nginx/

# Load into Kind
kind load docker-image api-deployment-demo-api:latest --name api-demo-cluster
kind load docker-image api-deployment-demo-nginx:latest --name api-demo-cluster
```

## Additional Resources

- **Project Root README:** `../README.md` - Overall project documentation
- **Deployment Methods:** `../docs/DEPLOYMENT-METHODS.md` - Comparison of deployment approaches
- **Secrets Security:** `../docs/SECRETS-SECURITY.md` - Security best practices
- **Makefile:** `../Makefile` - See all available commands with `make help`
- **Terraform Docs:** <https://www.terraform.io/docs>
- **Kubernetes Docs:** <https://kubernetes.io/docs>
