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
make staging           # Deploy to Docker Compose staging
```

**Staging Access:** https://localhost:30443 (HTTPS required, self-signed cert)

### Option 3: Production Only
```bash
make production        # Deploy directly to Kubernetes
```

---

## Access Points

All services are available on both staging and production environments:

| Service | Production (Kubernetes) | Staging (Docker Compose) |
|---------|------------------------|--------------------------||
| **API** | http://localhost/api | http://localhost:30800/api |
| **Nginx (HTTP)** | http://localhost | http://localhost:30080 → redirects to HTTPS |
| **Nginx (HTTPS)** | https://localhost | https://localhost:30443 |
| **Grafana** | http://localhost:3000 | *(not available in staging)* |
| **Prometheus** | http://localhost:9090 | *(not available in staging)* |

**Note:** Staging uses self-signed SSL certificates. Use `curl -k` or accept browser security warnings.

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
make staging                 # Deploy to staging
make staging-status          # Check status
make staging-logs            # View logs

# Production environment (Kubernetes)
make production              # Deploy to production
make production-status       # Check status
make production-logs         # View logs
```

### Kubernetes Management
```bash
kubectl get pods -n api-deployment-demo  # View production pods
kubectl logs -f <pod-name> -n api-deployment-demo  # Stream logs
kubectl get all -n api-deployment-demo   # View all resources
```

---

## Configuration & Secrets

### Environment Variables
All configuration is managed through `.env` file:

```bash
# Database configuration
DB_NAME=api_staging
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_HOST=postgres
DB_PORT=5432

# API configuration
API_ENV=staging
DEBUG=false
SECRET_KEY=your_secret_key
API_WORKERS=4

# SSL/TLS Configuration
SSL_ENABLED=true
SSL_SELF_SIGNED=true
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
cd nginx
./generate-ssl.sh
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
# Test HTTPS manually
curl -k https://localhost/api/health
curl -k https://localhost:30443/api/health  # Staging
openssl s_client -connect localhost:443 -servername localhost

# Check certificate details
openssl x509 -in nginx/ssl/nginx-selfsigned.crt -text -noout
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
kubectl get hpa -n api-deployment-demo

# View scaling events
kubectl describe hpa api-hpa -n api-deployment-demo

# Trigger autoscaling (generate traffic)
make traffic
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
# Run automated deployment test (full pipeline)
make test-automated

# Generate test traffic
make traffic

# Check environment status
make status                  # Active environment
make staging-status          # Staging specifically
make production-status       # Production specifically
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

---

## Cleanup & Management

### Cleanup Options

| Command | Scope | Use Case |
|---------|-------|----------|
| `make clean-staging` | Staging only | Clean Docker Compose environment |
| `make clean-production` | Production only | Clean Kubernetes resources |
| `make clean-all` | Everything | Full cleanup (staging + production) |

### Safe Cleanup Workflow
```bash
# 1. Stop staging environment
make clean-staging

# 2. Stop production environment
make clean-production

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
kubectl get pods -n api-deployment-demo | grep postgres

# View database logs
docker logs <postgres-container>
kubectl logs <postgres-pod> -n api-deployment-demo

# Verify connection settings in .env
DB_HOST=postgres-service
DB_PORT=5432
```

#### Kubernetes Pod Not Starting
**Problem**: Pod in `CrashLoopBackOff` or `ImagePullBackOff`

**Solution**:
```bash
# Check pod status
kubectl describe pod <pod-name> -n api-deployment-demo

# View pod logs
kubectl logs <pod-name> -n api-deployment-demo

# Common fixes:
# - Check image name/tag in deployment.yaml
# - Verify secrets are created: kubectl get secrets -n api-deployment-demo
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
kubectl rollout restart deployment prometheus -n monitoring
kubectl rollout restart deployment grafana -n monitoring
```

### Debug Commands

```bash
# Staging (Docker Compose)
docker compose ps                    # Service status
docker compose logs -f api           # Follow API logs
docker compose exec api /bin/bash    # Shell into container

# Production (Kubernetes)
kubectl get all -n api-deployment-demo        # All resources
kubectl describe pod <name> -n api-deployment-demo  # Detailed pod info
kubectl exec -it <pod> -n api-deployment-demo -- /bin/bash  # Shell into pod
kubectl get events -n api-deployment-demo --sort-by='.lastTimestamp'  # Recent events

# Monitoring
curl http://localhost:30800/health           # API health check (staging)
curl -k https://localhost:30443/health       # Nginx health check (staging HTTPS)
curl http://localhost/health                 # Health check (production)
```

### Getting Help

1. **Check Logs**: Always start by examining logs
2. **Verify Configuration**: Ensure `.env` file has correct values
3. **Resource Status**: Check that all services are running
4. **Network Connectivity**: Verify services can reach each other
5. **Secrets**: Confirm all required secrets are generated

For persistent issues, include the following in bug reports:
- Output of `make production-status` or `docker compose ps`
- Relevant logs from failing service
- `.env` configuration (remove sensitive values)
- Kubernetes events (`kubectl get events -n api-deployment-demo`)

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
