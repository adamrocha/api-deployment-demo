# Terraform Infrastructure as Code

This directory contains Terraform configurations to manage the API Deployment Demo infrastructure.

## Prerequisites

- Terraform >= 1.0
- Docker Desktop
- kubectl
- kind (for production deployments)

## Quick Start

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy Staging Environment

```bash
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

### 4. Deploy Production Environment

First, create the Kind cluster:

```bash
kind create cluster --name api-demo-cluster --config ../kind-config.yaml
```

Then deploy:

```bash
terraform plan -var="environment=production"
terraform apply -var="environment=production"
```

## Environments

### Staging (Docker Compose)

Deploys containers on high ports for local development:

- Web (HTTPS): <https://localhost:30443>
- API: <http://localhost:30800>
- Database: localhost:35432

```bash
terraform apply -var="environment=staging"
```

### Production (Kubernetes)

Deploys to Kind cluster with standard ports:

- Web: <http://localhost>
- API: <http://localhost:8000>
- Grafana: <http://localhost:3000> (if monitoring enabled)
- Prometheus: <http://localhost:9090> (if monitoring enabled)

```bash
terraform apply -var="environment=production"
```

## Variables

### Required Variables

- `environment` - "staging" or "production"
- `db_password` - Database password (sensitive)
- `secret_key` - API secret key (sensitive)

### Optional Variables

- `project_name` - Project name (default: "api-deployment-demo")
- `cluster_name` - Kind cluster name (default: "api-demo-cluster")
- `kubeconfig_path` - Path to kubeconfig (default: "~/.kube/config")
- `replicas` - Number of replicas (default: 2)
- `enable_monitoring` - Enable monitoring stack (default: true)
- `staging_ports` - Port mappings for staging

## Commands

### Plan Changes

```bash
terraform plan -var="environment=staging"
```

### Apply Changes

```bash
terraform apply -var="environment=staging"
```

### Destroy Infrastructure

```bash
terraform destroy -var="environment=staging"
```

### View Outputs

```bash
terraform output
```

### Switch Environments

```bash
# Switch from staging to production
terraform destroy -var="environment=staging"
terraform apply -var="environment=production"
```

## Workspaces

Use Terraform workspaces to manage multiple environments:

```bash
# Create staging workspace
terraform workspace new staging
terraform apply -var="environment=staging"

# Create production workspace
terraform workspace new production
terraform apply -var="environment=production"

# List workspaces
terraform workspace list

# Switch workspaces
terraform workspace select staging
```

## State Management

### Local State

By default, Terraform uses local state files. For team collaboration, consider using remote state:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "api-deployment-demo/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Remote State Options

- AWS S3 + DynamoDB
- Terraform Cloud
- Azure Storage
- Google Cloud Storage

## Modules

The configuration is organized into logical files:

- `main.tf` - Provider configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `docker.tf` - Docker image builds
- `staging.tf` - Staging environment (Docker Compose)
- `production.tf` - Production environment (Kubernetes)
- `monitoring.tf` - Monitoring stack

## Security Best Practices

1. **Never commit `terraform.tfvars`** - Add to `.gitignore`
2. **Use sensitive variables** - Mark passwords as sensitive
3. **Encrypt state files** - Use remote backend with encryption
4. **Rotate credentials** - Regularly update passwords and keys
5. **Use secrets management** - Consider HashiCorp Vault or AWS Secrets Manager

## Troubleshooting

### Docker Provider Issues

```bash
# Check Docker is running
docker ps

# Restart Docker provider
terraform apply -refresh-only
```

### Kubernetes Provider Issues

```bash
# Check kubeconfig
kubectl cluster-info

# Verify Kind cluster
kind get clusters

# Check namespace
kubectl get ns
```

### Image Build Failures

```bash
# Rebuild images manually
docker build -t api-deployment-demo-api:latest ../api
docker build -t api-deployment-demo-nginx:latest ../nginx

# Import into Terraform state
terraform import docker_image.api api-deployment-demo-api:latest
```

## Comparison: Terraform vs Ansible

| Aspect | Terraform | Ansible |
|--------|-----------|---------|
| **Purpose** | Infrastructure as Code | Configuration Management |
| **State** | Managed state file | Stateless |
| **Declarative** | Yes | No (procedural) |
| **Best For** | Cloud resources, infrastructure | Configuration, deployment |
| **Idempotency** | Built-in | Task-dependent |
| **Dependencies** | Automatic graph | Manual ordering |

### When to Use Each

**Use Terraform for:**

- Creating cloud infrastructure
- Managing container orchestration
- Declarative infrastructure definitions
- State tracking and drift detection

**Use Ansible for:**

- Configuration management
- Application deployment
- Sequential operations
- Ad-hoc tasks

**Use Both Together:**

- Terraform: Provision infrastructure
- Ansible: Configure and deploy applications

## Examples

### Deploy Everything

```bash
# Staging with monitoring
terraform apply \
  -var="environment=staging" \
  -var="enable_monitoring=true"

# Production with custom replicas
terraform apply \
  -var="environment=production" \
  -var="replicas=3" \
  -var="enable_monitoring=true"
```

### Update Single Resource

```bash
# Update only API deployment
terraform apply -target=kubernetes_deployment.api
```

### Import Existing Resources

```bash
# Import existing Docker network
terraform import docker_network.staging api-deployment-demo_staging_network
```

## Integration with Make/Ansible

You can continue using Make and Ansible alongside Terraform:

```makefile
# In Makefile
terraform-staging:
 cd terraform && terraform apply -var="environment=staging" -auto-approve

terraform-production:
 cd terraform && terraform apply -var="environment=production" -auto-approve
```

## Support

For issues or questions:

- Review Terraform documentation: <https://www.terraform.io/docs>
- Check provider documentation
- Review state file for drift
- Use `terraform plan` to preview changes
