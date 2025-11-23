# API Deployment Demonstration

A comprehensive demonstration project showcasing modern DevOps practices with automated API deployment pipelines using Docker Compose (staging) and Kubernetes (production). Features SSL/HTTPS, monitoring with Prometheus & Grafana, horizontal autoscaling, and infrastructure automation.

## Table of Contents

- [Quick Start](#quick-start)
- [Access Points](#access-points)
- [Deployment Options](#deployment-options)
- [Configuration & Secrets](#configuration--secrets)
- [SSL/HTTPS Setup](#sslhttps-setup)
- [Monitoring & Observability](#monitoring--observability)
- [Development Workflow](#development-workflow)
- [Architecture Overview](#architecture-overview)
- [Cleanup & Management](#cleanup--management)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

Choose your deployment path:

### Option 1: Full Production Pipeline (Recommended)
```bash
make test-automated    # Complete staging → production pipeline
```

**What it does:**
1. Deploys to staging (Docker Compose on high ports)
2. Runs validation tests
3. Auto-promotes to production (Kubernetes on standard ports)
4. Validates production deployment

### Option 2: Staging Only
```bash
make deploy-staging    # Deploy to Docker Compose staging
```

### Option 3: Production Only
```bash
make deploy-production # Deploy directly to Kubernetes
```

---

## Access Points

All services are available on both staging and production environments:

| Service | Production (Kubernetes) | Staging (Docker Compose) |
|---------|------------------------|--------------------------|
| **API** | http://localhost/api | http://localhost:8001/api |
| **Nginx** | http://localhost | http://localhost:8001 |
| **Grafana** | http://localhost:3000 | http://localhost:3001 |
| **Prometheus** | http://localhost:9090 | http://localhost:9091 |

**Default Credentials:**
- Grafana: `admin` / `admin` (change on first login)

---

## Deployment Options

### Automated Pipeline
```bash
make test-automated          # Full staging → production pipeline with validation
make test-automated SKIP_TESTS=true  # Skip validation tests
```

### Manual Deployments
```bash
# Staging environment (Docker Compose)
make deploy-staging          # Deploy to staging
make test-staging            # Run validation tests
make logs-staging            # View logs

# Production environment (Kubernetes)
make deploy-production       # Deploy to production
make test-production         # Run validation tests
make logs-production         # View logs
make status-production       # Check pod status
```

### Kubernetes Management
```bash
make k8s-dashboard          # Open Kubernetes dashboard
kubectl get pods -n production  # View production pods
kubectl logs -f <pod-name> -n production  # Stream logs
```

---

## Configuration & Secrets

### Environment Variables
All configuration is managed through a single `.env` file with prefixed variables:

```bash
# Staging (STG_) - Docker Compose on high ports
STG_API_PORT=8001
STG_NGINX_PORT=8001
STG_GRAFANA_PORT=3001

# Production (PROD_) - Kubernetes on standard ports
PROD_API_PORT=80
PROD_NGINX_PORT=80
PROD_GRAFANA_PORT=3000

# Database configuration
DB_NAME=mydatabase
DB_USER=postgres
DB_HOST=postgres-service
```

### Secret Management
```bash
# Generate all secrets (Kubernetes secrets & .env updates)
make generate-secrets

# What gets generated:
# - JWT tokens (API authentication)
# - Grafana admin password
# - PostgreSQL password
# - Session secrets
# - TLS certificates (if needed)
```

Secrets are stored in:
- **Kubernetes**: `kubectl get secrets -n production`
- **Environment**: `.env` file (gitignored)
- **Docker Compose**: Uses `.env` directly

---

## SSL/HTTPS Setup

### Quick SSL Setup

**Option 1: Self-Signed Certificates (Development)**
```bash
cd nginx/ssl
./generate-certs.sh
# Follow prompts for certificate details
```

**Option 2: Let's Encrypt (Production)**
```bash
# Prerequisites: 
# - Domain pointing to your server
# - Ports 80/443 accessible
# - Certbot installed

sudo certbot certonly --standalone -d yourdomain.com
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem nginx/ssl/server.crt
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem nginx/ssl/server.key
```

### SSL Configuration

Enable SSL in your `.env`:
```bash
SSL_ENABLED=true
SSL_CERT_PATH=/etc/nginx/ssl/server.crt
SSL_KEY_PATH=/etc/nginx/ssl/server.key
```

### Verify SSL
```bash
# Check certificate validity
make validate-ssl

# Test HTTPS manually
curl -k https://localhost/api/health
openssl s_client -connect localhost:443 -servername localhost
```

### SSL Troubleshooting
- **Certificate not found**: Ensure paths in `.env` match actual certificate locations
- **Permission denied**: Check file permissions (`chmod 644 *.crt`, `chmod 600 *.key`)
- **Browser warnings**: Self-signed certs will show warnings - this is expected in development
- **Let's Encrypt renewal**: Set up auto-renewal with `certbot renew --dry-run`

---

## Monitoring & Observability

### Grafana Dashboards

Access Grafana at:
- Production: http://localhost:3000
- Staging: http://localhost:3001

**Pre-configured dashboards:**
- API Performance (requests/sec, latency, error rates)
- System Metrics (CPU, memory, disk)
- Kubernetes Cluster Overview (production only)

### Prometheus Metrics

Access Prometheus at:
- Production: http://localhost:9090
- Staging: http://localhost:9091

**Key metrics:**
- `http_requests_total` - Total HTTP requests
- `http_request_duration_seconds` - Request latency
- `api_health_status` - API health check status

**Example queries:**
```promql
# Request rate (requests per second)
rate(http_requests_total[5m])

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_requests_total{status=~"5.."}[5m])
```

### Horizontal Pod Autoscaling (HPA)

Production environment automatically scales based on CPU usage:

```bash
# Check autoscaling status
kubectl get hpa -n production

# View scaling events
kubectl describe hpa api-hpa -n production

# Trigger autoscaling (load test)
make load-test
```

**Autoscaling configuration:**
- Min replicas: 2
- Max replicas: 10
- Target CPU: 50%

---

## Development Workflow

### Local Development
```bash
# Run API locally
cd api
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

# Run database locally
docker-compose up -d postgres
```

### Testing
```bash
# Run all tests
make test

# Test staging environment
make test-staging

# Test production environment
make test-production

# Load testing
make load-test              # Standard load test
make load-test DURATION=300 # 5-minute load test
```

### Docker Development
```bash
# Build images
docker-compose build

# Run specific service
docker-compose up api

# View logs
docker-compose logs -f api
```

---

## Architecture Overview

### Technology Stack
- **API**: Python FastAPI with Gunicorn
- **Web Server**: Nginx (reverse proxy, SSL termination)
- **Database**: PostgreSQL 15
- **Monitoring**: Prometheus + Grafana
- **Container Orchestration**: Docker Compose (staging), Kubernetes (production)
- **Infrastructure as Code**: Kubernetes manifests, Docker Compose

### Deployment Architecture

**Staging Environment (Docker Compose):**
- Runs on high ports (8001, 3001, 9091)
- Single-host deployment
- Ideal for testing and validation
- Direct .env file usage

**Production Environment (Kubernetes):**
- Runs on standard ports (80, 3000, 9090)
- Multi-node capable
- Horizontal autoscaling
- ConfigMaps and Secrets for configuration

### Network Architecture
```
Internet → Nginx (SSL termination) → API → PostgreSQL
                ↓
         Prometheus ← Metrics
                ↓
            Grafana (visualization)
```

### Detailed Design Decisions

For in-depth architectural decisions, design patterns, and trade-offs, see [ARCHITECTURE.md](./ARCHITECTURE.md).

---

## Cleanup & Management

### Cleanup Options

| Command | Scope | Use Case |
|---------|-------|----------|
| `make clean-staging` | Staging only | Clean Docker Compose environment |
| `make clean-production` | Production only | Clean Kubernetes resources |
| `make clean-all` | Everything | Full cleanup (staging + production) |
| `make clean-volumes` | Data volumes | Remove all persistent data |

### Safe Cleanup Workflow
```bash
# 1. Stop staging environment
make clean-staging

# 2. Stop production environment
make clean-production

# 3. Remove volumes (WARNING: deletes data)
make clean-volumes

# Or do everything at once
make clean-all
```

### Resource Management
```bash
# View resource usage
docker stats                          # Docker resources
kubectl top nodes -n production       # Kubernetes node resources
kubectl top pods -n production        # Kubernetes pod resources

# Prune unused Docker resources
docker system prune -a --volumes
```

---

## Troubleshooting

### Common Issues

#### Port Conflicts
**Problem**: `port is already allocated`

**Solution**:
```bash
# Find process using port
lsof -i :8001  # or relevant port

# Kill process
kill -9 <PID>

# Or use different ports in .env
STG_API_PORT=8002
```

#### Database Connection Issues
**Problem**: `could not connect to database`

**Solution**:
```bash
# Check database status
docker ps | grep postgres
kubectl get pods -n production | grep postgres

# View database logs
docker logs <postgres-container>
kubectl logs <postgres-pod> -n production

# Verify connection settings in .env
DB_HOST=postgres-service
DB_PORT=5432
```

#### Kubernetes Pod Not Starting
**Problem**: Pod in `CrashLoopBackOff` or `ImagePullBackOff`

**Solution**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n production

# View pod logs
kubectl logs <pod-name> -n production

# Common fixes:
# - Check image name/tag in deployment.yaml
# - Verify secrets are created: kubectl get secrets -n production
# - Check resource limits aren't too restrictive
```

#### SSL Certificate Issues
**Problem**: Browser shows security warnings or certificate errors

**Solution**:
```bash
# Verify certificate files exist
ls -la nginx/ssl/

# Check certificate validity
make validate-ssl

# Regenerate self-signed certificates
cd nginx/ssl && ./generate-certs.sh

# For Let's Encrypt, verify domain and renew
sudo certbot renew
```

#### Metrics Not Showing in Grafana
**Problem**: Grafana dashboards show "No data"

**Solution**:
```bash
# Verify Prometheus is scraping
# Go to http://localhost:9090/targets
# All targets should show "UP"

# Check Grafana data source
# Go to http://localhost:3000/datasources
# Test connection to Prometheus

# Restart monitoring stack
kubectl rollout restart deployment prometheus -n production
kubectl rollout restart deployment grafana -n production
```

### Debug Commands

```bash
# Staging (Docker Compose)
docker-compose ps                    # Service status
docker-compose logs -f api           # Follow API logs
docker-compose exec api /bin/bash   # Shell into container

# Production (Kubernetes)
kubectl get all -n production        # All resources
kubectl describe pod <name> -n production  # Detailed pod info
kubectl exec -it <pod> -n production -- /bin/bash  # Shell into pod
kubectl get events -n production --sort-by='.lastTimestamp'  # Recent events

# Monitoring
curl http://localhost:8001/api/health  # Health check (staging)
curl http://localhost/api/health       # Health check (production)
```

### Getting Help

1. **Check Logs**: Always start by examining logs
2. **Verify Configuration**: Ensure `.env` file has correct values
3. **Resource Status**: Check that all services are running
4. **Network Connectivity**: Verify services can reach each other
5. **Secrets**: Confirm all required secrets are generated

For persistent issues, include the following in bug reports:
- Output of `make status-production` or `docker-compose ps`
- Relevant logs from failing service
- `.env` configuration (remove sensitive values)
- Kubernetes events (`kubectl get events -n production`)

---

## Additional Resources

- **Makefile**: View all available commands with `make help`
- **Architecture Details**: See `ARCHITECTURE.md` (if available)
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Docker Compose Docs**: https://docs.docker.com/compose/
- **FastAPI Docs**: https://fastapi.tiangolo.com/
- **Prometheus Docs**: https://prometheus.io/docs/

---

## License

This is a demonstration project for educational purposes.
