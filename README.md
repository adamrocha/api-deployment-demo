# API Deployment Demo

Modern DevOps deployment pipeline demonstrating Infrastructure as Code with Terraform, Ansible configuration management, and Kubernetes orchestration.

## Quick Start

**Prerequisites**: Docker, kubectl, Kind, Terraform (>= 1.0)

```bash
# Deploy production environment (one command)
make production
```

**Access**: <https://localhost> (web), <http://localhost:8000> (API), <http://localhost:3000> (Grafana)

---

## Table of Contents

1. [How It Works](#how-it-works)
2. [What Gets Deployed](#what-gets-deployed)
3. [Key Commands](#key-commands)
4. [Architecture](#architecture)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Resources](#resources)

---

## How It Works

### Deployment Pipeline

```bash
make production
```

**Execution flow:**

1. **Kind** creates 3-node Kubernetes cluster
2. **Docker** builds API + Nginx images
3. **Terraform** provisions infrastructure (namespaces, services, ConfigMaps, secrets)
4. **Kubernetes** deploys workloads (API, Nginx, PostgreSQL, monitoring)
5. **Ansible** applies configuration tuning (HPA, resource limits, PDB)

### Infrastructure as Code

**Terraform** (`terraform/`)

- Declarative infrastructure provisioning
- State management for tracking resources
- Automatic dependency resolution
- Idempotent operations

**Ansible** (`ansible/`)

- Configuration management post-deployment
- Kubernetes resource tuning
- Horizontal Pod Autoscaler (HPA) setup
- Performance optimization

**Makefile** (root)

- Orchestrates all workflows
- Simplifies complex operations
- Provides consistent interface

---

## What Gets Deployed

### Production Environment

| Component | Count | Purpose |
|-----------|-------|---------|
| **API** | 2-10 pods | FastAPI + Gunicorn (autoscales on CPU) |
| **Nginx** | 2 pods | Reverse proxy, SSL termination, load balancer |
| **PostgreSQL** | 1 pod | Persistent database (StatefulSet) |
| **Prometheus** | 1 pod | Metrics collection and alerting |
| **Grafana** | 1 pod | Dashboards with 4 auto-provisioned dashboards |

### Access Points

| Service | URL | Port Mapping |
|---------|-----|--------------|
| Web (HTTPS) | <https://localhost> | 443 → 30443 |
| API Direct | <http://localhost:8000> | 8000 → 30800 |
| Grafana | <http://localhost:3000> | 3000 → 30300 |
| Prometheus | <http://localhost:9090> | 9090 → 30900 |

**Credentials**: Grafana `admin`/`admin`

---

## Key Commands

### Deployment

```bash
make production          # Full production deployment
make staging            # Docker Compose staging environment
make ci-pipeline        # CI/CD automated pipeline
```

### Management

```bash
make status             # Check deployment status
make health             # Test all health endpoints
make pods               # List all pods
make events             # View recent cluster events
```

### Monitoring & Logs

```bash
make logs-api           # API logs (follow)
make logs-nginx         # Nginx logs (follow)
make forward            # Port forward monitoring stack
```

### Scaling & Testing

```bash
make scale COMPONENT=api REPLICAS=5  # Scale API pods
make scale COMPONENT=nginx REPLICAS=3 # Scale Nginx pods
make test-load                        # Run load test
make test-traffic                     # Generate traffic
```

### Cleanup

```bash
make clean-all          # Remove everything (cluster + images)
make cluster-delete     # Delete Kind cluster only
make destroy            # Destroy Terraform resources
```

### Terraform

```bash
make init               # Initialize Terraform
make plan               # Preview changes
make apply              # Apply infrastructure
make output             # View outputs
```

### Ansible

```bash
make config             # Apply Kubernetes configuration
make tune               # Enable autoscaling and tuning
make ansible            # Run all Ansible playbooks
```

**Full list**: Run `make help`

---

## Architecture

### Technology Stack

**Infrastructure**: Terraform, Ansible, Makefile, Kind (Kubernetes)  
**Application**: Python FastAPI, Gunicorn, Nginx, PostgreSQL 15  
**Monitoring**: Prometheus, Grafana  
**Orchestration**: Kubernetes with HPA (Horizontal Pod Autoscaler)

### Network Flow

```text
Internet/localhost → Kind Cluster → Nginx (:80/:443) → API (:8000) → PostgreSQL (:5432)
                                                ↓
                                            Prometheus (:9090) → Grafana (:3000)
```

### Deployment Comparison

| Method | Use Case | State Tracking | Idempotent | Preview |
|--------|----------|----------------|------------|---------|
| **Terraform** | Infrastructure provisioning | ✅ Yes | ✅ Yes | ✅ `terraform plan` |
| **Ansible** | Configuration management | ❌ No | ✅ Yes | ⚠️ `--check` |
| **kubectl** | Manual operations | ❌ No | ⚠️ Partial | ❌ No |

### Kubernetes Resources

**Namespace**: `production`

**Workloads**:

- API Deployment (2-10 replicas, CPU-based autoscaling)
- Nginx Deployment (2 replicas)
- PostgreSQL StatefulSet (1 replica with persistent volume)
- Prometheus Deployment (1 replica)
- Grafana Deployment (1 replica)

**Configuration**:

- ConfigMaps: nginx-config, nginx-html, postgres-init
- Secrets: TLS certificates, database credentials
- Services: LoadBalancer (nginx), ClusterIP (api, postgres, monitoring)
- HPA: Min 2, Max 10, Target 50% CPU
- Network Policies: Pod-to-pod traffic control

---

## Configuration

### Security & Secrets Setup

**⚠️ IMPORTANT**: Never commit secrets to version control!

```bash
# 1. Generate strong secrets
openssl rand -base64 32    # For DB_PASSWORD
openssl rand -base64 32    # For SECRET_KEY

# 2. For Terraform, copy and customize
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with secure values
```

**Security Features:**

- ✅ Kubernetes secrets marked as immutable
- ✅ All sensitive variables marked `sensitive = true`
- ✅ `.gitignore` excludes all secret files
- ✅ Comprehensive security guide: [SECRETS-SECURITY.md](docs/SECRETS-SECURITY.md)

### Environment Variables

Auto-generated `.env` file:

```bash
DB_NAME=api_production
DB_USER=postgres
DB_PASSWORD=<generated>
DB_HOST=postgres-service
API_ENV=production
SECRET_KEY=<generated>
SSL_ENABLED=true
```

### Secrets Management

- **Terraform**: Provisions TLS certificates and Kubernetes secrets
- **Kubernetes**: Stores credentials securely (`kubectl get secrets -n production`)
- **Commands**: `make secrets-tls` (regenerate TLS)
- **Best Practices**: See [SECRETS-SECURITY.md](docs/SECRETS-SECURITY.md) for production recommendations

### Monitoring Configuration

- **Prometheus**: Scrapes metrics from API, Nginx, PostgreSQL (port 9090)
- **Grafana**: 4 auto-provisioned dashboards (API, Infrastructure, Database, Nginx)
- **Auto-Deployment**: Dashboards loaded automatically via ConfigMaps
- **Access**: Navigate to Dashboards → Browse → API Demo folder
- **Metrics**: `http_requests_total`, `http_request_duration_seconds`, CPU/memory usage

**Verify Setup**: Run `./scripts/verify-monitoring.sh`

---

## Troubleshooting

### Quick Diagnostics

```bash
make cluster-info        # Cluster health
make pods               # Pod status
make events             # Recent events
make health             # Endpoint health checks
```

### Common Issues

**Pods not starting**:

```bash
kubectl describe pod <pod-name> -n production
make logs-api-once
# Check: images loaded, secrets exist, resources available
```

**Image not found**:

```bash
```bash
make build && make load-images
docker exec -it api-demo-cluster-control-plane crictl images
```

**Terraform timeout**:

```bash
```bash
# Services have 3-5min timeouts configured
make apply              # Retry
make cluster-info       # Check cluster health
```

**Monitoring not accessible**:

```bash
kubectl get pods -n monitoring | grep -E 'grafana|prometheus'
make forward
```

**Database connection issues**:

```bash
```bash
kubectl logs -n production -l app=postgres
kubectl get svc postgres-service -n production
```

### Debug Commands

```bash
# Logs
kubectl logs -f <pod-name> -n production
make logs-api-once
make logs-nginx-once

# Resources
kubectl top nodes
kubectl top pods -n production
kubectl get all -n production

# Terraform
make tf-plan
make tf-output
terraform state list

# Restart
make restart
kubectl rollout restart deployment <name> -n production
```

---

## Resources

### Documentation

- 📚 **[QUICK-REFERENCE.md](docs/QUICK-REFERENCE.md)** - Command cheat sheet
- 🔄 **[CI-CD-WORKFLOWS.md](docs/CI-CD-WORKFLOWS.md)** - Pipeline details
- 🏗️ **[DEPLOYMENT-METHODS.md](docs/DEPLOYMENT-METHODS.md)** - Method comparison
- 🔐 **[SECRETS-SECURITY.md](docs/SECRETS-SECURITY.md)** - Secrets management & security best practices

### External Links

- [Terraform Docs](https://terraform.io/docs)
- [Kubernetes Docs](https://kubernetes.io/docs)
- [Kind Docs](https://kind.sigs.k8s.io)
- [Ansible Docs](https://docs.ansible.com)

### Support

**Getting Help**:

1. Check `make status` and `make health`
2. Review logs with `make logs-api-once`
3. Check events with `make events`
4. Verify resources with `make pods`

---

## Contributing

Educational demonstration project. Feel free to fork, experiment, and adapt.

## License

Demonstration project for educational purposes.
