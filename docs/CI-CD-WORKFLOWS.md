# CI/CD Workflow Guide

This document describes the seamless staging-to-production CI/CD workflows using Terraform (IaC), Ansible (Configuration Management), and Make (Orchestration).

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  1. BUILD          →  2. TEST  →  3. STAGING  →  4. PRODUCTION │
│                                                               │
│  ├─ Docker Build   │  ├─ Unit    │  ├─ Terraform │  ├─ Terraform │
│  ├─ Image Tag      │  ├─ Integration│  ├─ Ansible │  ├─ Ansible │
│  └─ Registry Push  │  └─ E2E     │  └─ Validate │  └─ Monitor │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Tools & Responsibilities

### Terraform (Infrastructure as Code)

**Purpose:** Provision and manage infrastructure

- Create Kubernetes namespaces, deployments, services
- Configure resource limits and requests
- Set up networking (NodePorts, LoadBalancers)
- Manage secrets and ConfigMaps
- Build and load Docker images

### Ansible (Configuration Management)

**Purpose:** Configure and tune deployed resources

- Scale deployments dynamically
- Update environment variables
- Configure HPA (Horizontal Pod Autoscaler)
- Set up Pod Disruption Budgets
- Tune database parameters
- Monitor resource usage

### Make (Orchestration)

**Purpose:** Simplify and standardize command execution

- Provide consistent CLI interface
- Chain Terraform and Ansible commands
- Handle dependencies between tasks
- Enable troubleshooting workflows

## Deployment Workflows

### 1. Full Staging Deployment

```bash
make deploy-staging-full
```

**What happens:**

1. Terraform provisions staging infrastructure (Docker Compose)
2. Waits for services to be ready
3. Ansible configures and tunes the deployment
4. Validates health endpoints

**Components:**

- Docker Compose on host
- PostgreSQL, API, Nginx containers
- Ports: 30080 (HTTP), 30443 (HTTPS), 30800 (API), 35432 (DB)

### 2. Full Production Deployment

```bash
make deploy-production-full
# or
make provision-and-configure
```

**What happens:**

1. Creates Kind cluster (if needed)
2. Terraform provisions production infrastructure:
   - Kubernetes deployments (API, Nginx, PostgreSQL)
   - Services (LoadBalancer, NodePort)
   - ConfigMaps (nginx-config, nginx-html)
   - Secrets (SSL certs, DB credentials)
   - Monitoring stack (Prometheus, Grafana)
3. Ansible applies configuration:
   - Scales deployments to production replicas
   - Sets resource limits
   - Configures environment variables
   - Enables HPA
   - Creates Pod Disruption Budgets
4. Validates all services are healthy

**Components:**

- Kind Kubernetes cluster (3 nodes)
- API deployment (2 replicas)
- Nginx deployment (2 replicas)
- PostgreSQL (1 replica)
- Prometheus + Grafana
- Ports: 80, 443, 8000 (via Kind port mappings)

### 3. Configuration-Only Updates

If infrastructure is already deployed, you can update configuration without reprovisioning:

```bash
# Configure Kubernetes resources
make ansible-k8s-config ENV=production

# Tune and optimize
make ansible-k8s-tune ENV=production

# Run all Ansible tasks
make ansible-k8s-all ENV=production
```

### 4. CI Pipeline

Full CI/CD pipeline execution:

```bash
# Complete pipeline (build, test, deploy to staging)
make ci-pipeline

# Promote staging to production
make ci-promote
```

**Pipeline stages:**

1. **Build:** `make ci-build` - Build Docker images
2. **Test:** `make ci-test` - Run test suites
3. **Deploy Staging:** `make ci-deploy-staging` - Deploy to staging environment
4. **Validate:** Automated health checks and validation
5. **Promote:** `make ci-promote` - Deploy to production

## Staging vs Production Alignment

Both environments use the same base configuration with environment-specific overrides:

| Aspect | Staging | Production |
|--------|---------|------------|
| **Platform** | Docker Compose | Kubernetes (Kind) |
| **Infrastructure** | Terraform (docker.tf, staging.tf) | Terraform (production.tf, monitoring.tf) |
| **Configuration** | Ansible (site.yml) | Ansible (kubernetes.yml) |
| **API Replicas** | 1 | 2 |
| **Nginx Replicas** | 1 | 2 |
| **Database** | PostgreSQL container | PostgreSQL pod |
| **Monitoring** | Optional | Prometheus + Grafana |
| **SSL/TLS** | Self-signed | Self-signed (production cert in real deployment) |
| **Autoscaling** | No | Yes (HPA) |
| **Access Ports** | 30080, 30443, 30800 | 80, 443, 8000, 3000, 9090 |

## Workflow Examples

### Example 1: Deploy Fresh Production Environment

```bash
# Option A: Complete deployment
make deploy-production-full

# Option B: Step by step
make tf-production        # Provision infrastructure
make ansible-k8s-all      # Configure and tune
```

### Example 2: Update Production Configuration

```bash
# Scale API to 5 replicas
make ansible-k8s-config ENV=production api_replicas=5

# Tune database performance
make ansible-k8s-tune ENV=production \
  db_shared_buffers=512MB \
  db_effective_cache_size=2GB
```

### Example 3: Staging to Production Workflow

```bash
# 1. Deploy and test in staging
make deploy-staging-full

# 2. Run tests
make test

# 3. If tests pass, promote to production
make ci-promote
```

### Example 4: Troubleshooting

```bash
# Check Terraform state
make tf-output

# View deployment status
kubectl get pods -n api-deployment-demo -o wide

# Check resource usage
kubectl top pods -n api-deployment-demo

# View Ansible deployment status
make ansible-k8s-all ENV=production --tags verification
```

## Environment Variables

Configure deployments using environment variables:

```bash
# Set environment
export ENV=production

# Set custom values
make ansible-k8s-config \
  api_replicas=3 \
  nginx_replicas=2 \
  hpa_max_replicas=15 \
  hpa_target_cpu=80
```

## Access URLs

### Staging

- Web (HTTPS): <https://localhost:30443>
- API: <http://localhost:30800>
- Database: localhost:35432

### Production

- Web (HTTP): <http://localhost:80>
- Web (HTTPS): <https://localhost:443>
- API: <http://localhost:8000>
- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>

## Best Practices

1. **Always test in staging first**

   ```bash
   make deploy-staging-full && make test
   ```

2. **Use Terraform for infrastructure changes**

   ```bash
   make tf-plan-production  # Review changes
   make tf-production       # Apply changes
   ```

3. **Use Ansible for configuration changes**

   ```bash
   make ansible-k8s-config  # Quick config updates
   make ansible-k8s-tune    # Performance tuning
   ```

4. **Monitor deployments**

   ```bash
   kubectl get pods -n api-deployment-demo --watch
   kubectl top pods -n api-deployment-demo
   ```

5. **Clean slate for testing**

   ```bash
   make clean-all      # Clean everything
   make tf-clean       # Clean Terraform state
   ```

## Troubleshooting

### Terraform State Issues

```bash
# Clean and reinitialize
make tf-clean
make tf-init
```

### Deployment Not Ready

```bash
# Check pod status
kubectl get pods -n api-deployment-demo

# Check logs
kubectl logs -n api-deployment-demo deployment/api-deployment
kubectl logs -n api-deployment-demo deployment/nginx-deployment

# Describe for events
kubectl describe pod -n api-deployment-demo <pod-name>
```

### Ansible Connection Issues

```bash
# Verify kubectl connectivity
kubectl cluster-info

# Check context
kubectl config current-context

# Validate Ansible
make ansible-validate
```

## Next Steps

- Set up GitLab CI/CD or GitHub Actions to automate `make ci-pipeline`
- Configure production SSL certificates (not self-signed)
- Set up external monitoring and alerting
- Implement blue/green or canary deployments
- Add automated rollback procedures
