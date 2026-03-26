# API Deployment Demo

Modern Kubernetes deployment pipeline demonstrating GitOps-ready infrastructure with Kustomize overlays and Ansible orchestration.

## Quick Start

**Prerequisites**: Docker, kubectl, Kind, Ansible

```bash
# Deploy production environment (one command)
make deploy

# Deploy staging environment
make deploy ENV=staging
```

**Access**: <https://localhost> (web), <http://localhost:8000> (API), <http://localhost:3000> (Grafana)

**Credentials**: Grafana default credentials are admin/admin

---

## Table of Contents

1. [How It Works](#how-it-works)
2. [What Gets Deployed](#what-gets-deployed)
3. [Key Commands](#key-commands)
4. [Architecture](#architecture)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)
7. [Documentation](#documentation)

---

## How It Works

### Deployment Pipeline

```bash
make deploy
```

**Execution flow:**

1. **Kind** creates 3-node Kubernetes cluster
2. **Docker** builds API + Nginx images
3. **Kustomize** builds environment-specific manifests from overlays
4. **Ansible** orchestrates deployment:
   - Generates TLS certificates
   - Applies Kustomize manifests
   - Waits for deployments to be ready
   - Verifies services and resources
5. **Kubernetes** runs the workloads

### Infrastructure as Code

**Kustomize** (`kustomize/`)

- Single source of truth for Kubernetes resources
- Base manifests + environment overlays (production/staging)
- GitOps-ready, declarative configuration

**Ansible** (`ansible/`)

- Deployment orchestration and workflow
- Pre-deployment tasks (certificates, validation)
- Post-deployment verification

**Makefile** (root)

- Simple deployment interface: `make deploy [ENV=production|staging]`

---

## What Gets Deployed

### Production Environment

| Component              | Count  | Purpose                                       |
| ---------------------- | ------ | --------------------------------------------- |
| **API**                | 2 pods | FastAPI + Gunicorn (production workload)      |
| **Nginx**              | 2 pods | Reverse proxy, SSL termination, load balancer |
| **PostgreSQL**         | 1 pod  | Persistent database with metrics exporter     |
| **Prometheus**         | 1 pod  | Metrics collection and alerting               |
| **Grafana**            | 1 pod  | Dashboards with 4 auto-provisioned dashboards |
| **Kube-State-Metrics** | 1 pod  | Kubernetes cluster metrics                    |

### Access Points

| Service     | URL                     | Port Mapping |
| ----------- | ----------------------- | ------------ |
| Web (HTTPS) | <https://localhost>     | 443 → 30443  |
| API Direct  | <http://localhost:8000> | 8000 → 30800 |
| Grafana     | <http://localhost:3000> | 3000 → 30300 |
| Prometheus  | <http://localhost:9090> | 9090 → 30900 |

**Credentials**:

- Grafana username: `admin`
- Grafana password: `admin` (change on first login, or check `make get-secrets`)
- Retrieve with: `kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d`

---

## Key Commands

### Deployment

```bash
make production         # Full production deployment
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
```

### Scaling & Testing

```bash
make scale COMPONENT=api REPLICAS=5   # Scale API pods
make scale COMPONENT=nginx REPLICAS=3 # Scale Nginx pods
make test-load                        # Run load test
make test-traffic                     # Generate traffic
```

### Cleanup

```bash
make clean-all          # Remove everything (cluster + images)
make cluster-delete     # Delete Kind cluster only
make destroy            # Remove deployment (keep cluster)
```

### Ansible

```bash
make deploy             # Full deployment (uses Ansible + Kustomize)
make validate           # Validate all configurations
```

**Full list**: Run `make help`

---

## Architecture

### Technology Stack

**Infrastructure**: Kustomize, Ansible, Makefile, Kind (Kubernetes)
**Application**: Python FastAPI, Gunicorn, Nginx, PostgreSQL 15  
**Monitoring**: Prometheus, Grafana  
**Orchestration**: Kubernetes with HPA (Horizontal Pod Autoscaler)

### Network Flow

```text
Internet/localhost → Kind Cluster → Nginx (:80/:443) → API (:8000) → PostgreSQL (:5432)
                                                ↓
                                            Prometheus (:9090) → Grafana (:3000)
```

### Environment Architecture

**Staging (Docker Compose)**:

- Database: `api_staging` on port `35432`
- API: Port `30800`, API_ENV=`staging`
- Nginx: Ports `30080`/`30443`
- Use: Local development and testing

**Production (Kubernetes/Kustomize)**:

- Database: `api_production` on port `5432` (internal)
- API: Port `8000`, API_ENV=`production`
- Nginx: Port `443` (HTTPS)
- Use: Production-like environment with monitoring

### Deployment Comparison

| Method        | Use Case                 | State Tracking | Idempotent                      | Preview                      |
| ------------- | ------------------------ | -------------- | ------------------------------- | ---------------------------- |
| **Kustomize** | Manifest templating      | ❌ No          | ✅ Yes                          | ✅ `kubectl apply --dry-run` |
| **Ansible**   | Deployment orchestration | ❌ No          | ✅ Yes                          | ⚠️ `--check`                 |
| **kubectl**   | Manual operations        | ❌ No          | ✅ Yes (apply) / ❌ No (create) | ❌ No                        |

### Kubernetes Resources

**Namespaces**:

- `api-deployment-demo-ns` (consolidated: application + monitoring)

**Workloads**:

- API Deployment (2 replicas)
- Nginx Deployment (2 replicas with metrics exporter sidecar)
- PostgreSQL Deployment (1 replica with postgres-exporter sidecar)
- Prometheus Deployment (1 replica)
- Grafana Deployment (1 replica)
- Kube-State-Metrics Deployment (1 replica)

**Configuration**:

- **ConfigMaps**: nginx-config, nginx-html, postgres-init, prometheus-config, grafana dashboards
- **Secrets**: api-secrets (SECRET_KEY), postgres-secrets (db-password, db-name), grafana-admin-secret
- **Services**: LoadBalancer (nginx), NodePort (api), ClusterIP (postgres, monitoring)
- **Managed by**: Kustomize (manifests), Ansible (deployment orchestration)

---

## Configuration

### Security & Secrets Setup

**⚠️ IMPORTANT**: Never commit secrets to version control!

**Automated (Recommended)**:

```bash
# Secrets are automatically generated and applied during deployment:
make deploy

# Or generate secrets manually:
./scripts/generate-secrets.sh production
```

**Manual Setup**:

```bash
# Generate strong secrets
openssl rand -base64 32    # For each secret

# Apply to cluster
kubectl create secret generic api-secrets \
  --from-literal=SECRET_KEY=<value> \
  -n api-deployment-demo-ns
```

**Security Features:**

- ✅ Automated secure password generation (32+ character cryptographic random)
- ✅ Kubernetes secrets marked as immutable
- ✅ All sensitive variables marked `sensitive = true`
- ✅ `.gitignore` excludes all secret files
- ✅ Secret key format validation (uppercase with underscores)
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

- **Kustomize**: Defines secret structure in manifests
- **Kubernetes**: Stores credentials securely (`kubectl get secrets -n api-deployment-demo-ns`)
- **Commands**: `make get-secrets` (view all credentials)
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
make cluster-info       # Cluster health
make pods               # Pod status
make events             # Recent events
make health             # Endpoint health checks
```

### Common Issues

**Pods not starting**:

```bash
# Check pod status and events
kubectl get pods -n api-deployment-demo-ns
kubectl describe pod <pod-name> -n api-deployment-demo-ns
make logs

# Common issues:
# 1. CreateContainerConfigError - secret key mismatch
kubectl get secret api-secrets -n api-deployment-demo-ns -o jsonpath='{.data}' | jq
# Should show "SECRET_KEY" (uppercase). If not, run: make deploy

# 2. ImagePullBackOff - image not loaded
make build && kind load docker-image api-deployment-demo-api:latest --name api-demo-cluster
```

**Image not found**:

```bash
make build
kind load docker-image api-deployment-demo-api:latest --name api-demo-cluster
kind load docker-image api-deployment-demo-nginx:latest --name api-demo-cluster

# Verify images in cluster
docker exec -it api-demo-cluster-control-plane crictl images | grep api-deployment
```

**Monitoring not accessible**:

```bash
kubectl get pods -n api-deployment-demo-ns | grep -E 'grafana|prometheus'
make forward
```

**Database connection issues**:

```bash
kubectl logs -n api-deployment-demo-ns -l app=postgres
kubectl get svc postgres -n api-deployment-demo-ns

# Test connectivity from API pod
kubectl exec -it deployment/api-deployment -n api-deployment-demo-ns -- nc -zv postgres 5432
```

### Debug Commands

```bash
# Logs
kubectl logs -f <pod-name> -n api-deployment-demo
make logs  # Follows API logs

# Resources
kubectl top nodes
kubectl top pods -n api-deployment-demo-ns
kubectl get all -n api-deployment-demo-ns

# Restart
make restart
kubectl rollout restart deployment <name> -n api-deployment-demo-ns
```

---

## Documentation

### 📚 Complete Documentation Index

**[View Full Documentation Index →](docs/INDEX.md)**

| Document                                            | Purpose                               |
| --------------------------------------------------- | ------------------------------------- |
| **[INDEX.md](docs/INDEX.md)**                       | Navigation guide to all documentation |
| **[QUICK-START.md](docs/QUICK-START.md)**           | Command cheat sheet and workflows     |
| **[MONITORING.md](docs/MONITORING.md)**             | Prometheus + Grafana guide            |
| **[SECRETS-SECURITY.md](docs/SECRETS-SECURITY.md)** | Security best practices               |

### Quick Links

- 🚀 **New here?** Start with [Quick Start](#quick-start) above
- 📖 **Learning?** See [How It Works](#how-it-works)
- 🔧 **Deploying?** Check [QUICK-START.md](docs/QUICK-START.md)
- 📊 **Monitoring?** Read [MONITORING.md](docs/MONITORING.md)
- 🐛 **Debugging?** Review [Troubleshooting](#troubleshooting)

---

## Contributing

Educational demonstration project. Feel free to fork, experiment, and adapt.

## License

Demonstration project for educational purposes.
