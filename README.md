# API Deployment Demo

A comprehensive **three-tier web application** demonstrating production-ready deployment strategies with:

- 🐍 **Python API** (FastAPI with Gunicorn WSGI server)  
- 🗄️ **PostgreSQL Database**
- 🌐 **Nginx Reverse Proxy** with SSL support
- 📊 **Complete monitoring stack** (Prometheus + Grafana)

This repository provides **multiple deployment approaches** including Docker Compose, Kubernetes with **fully automated provisioning**, and comprehensive monitoring solutions.

> **🎯 Everything is automated through our comprehensive Makefile** - run `make help` to see all available commands!

**🎯 Smart Port Architecture:**
- **Production (Kubernetes)**: Uses standard ports for easy access
- **Staging (Docker Compose)**: Uses high ports to avoid conflicts
- **Both environments can run simultaneously** without interference!

## ✨ Automated Deployment Features

**🎯 Zero Manual Intervention Required!**

- ✅ **Standard Port Access**: Production uses standard ports (80, 443, 8000, 3000, 9090)
- ✅ **🔒 SSL/HTTPS Integration**: Fully automated SSL certificate generation and HTTPS configuration
- ✅ **High Port Staging**: Staging uses high ports (30080, 30800) to avoid conflicts
- ✅ **Intelligent Health Checks**: Robust retry logic with HTTP and HTTPS validation
- ✅ **Self-Configuring Monitoring**: Complete Prometheus + Grafana stack
- ✅ **One-Command Deployment**: Complete SSL-enabled stack with `make production`
- ✅ **Automated Port Mapping**: Kind cluster handles all port forwarding including HTTPS (443)

| Service      | Production URL              | Staging URL                     | Description                        |
|--------------|-----------------------------|---------------------------------|------------------------------------|
| Web Frontend | `http://localhost`          | `http://localhost:30080`        | Main application via Nginx         |
| **HTTPS Web**| `https://localhost`         | N/A                             | **🔒 Secure HTTPS access**         |
| API Direct   | `http://localhost:8000`     | `http://localhost:30800`        | Direct API access                  |
| API Docs     | `http://localhost:8000/docs`| `http://localhost:30800/docs`   | Interactive Swagger documentation  |
| **HTTPS API**| `https://localhost/health`  | N/A                             | **🔒 Secure API endpoints**        |
| Prometheus   | `http://localhost:9090`     | N/A                             | Metrics and monitoring             |
| Grafana      | `http://localhost:3000`     | N/A                             | Dashboards (admin/use `scripts/get-grafana-password.sh`) |

## 🚀 Quick Start

Get started in seconds with our comprehensive Makefile:

```bash
# Show all available commands
make help

# Quick starts for different environments
make quick-staging      # Docker Compose environment
make production         # 🔒 Kubernetes with SSL/HTTPS + monitoring (fully automated!)
make quick-dev         # Development environment

# Test complete automation
make test-automated     # Comprehensive automated deployment test

# Check SSL/HTTPS status
make production-status  # Verify both HTTP and HTTPS endpoints
```

## 🧹 Cleanup Options

Choose the right cleanup level for your needs:

```bash
# Preview what would be deleted (safe)
make clean-all-dry-run

# Progressive cleanup options
make clean-staging      # Clean only Docker Compose staging
make clean-production   # Clean only Kubernetes (keep cluster)  
make clean              # Clean applications (keep cluster & images)
make clean-all          # 💥 NUCLEAR: Delete everything (cluster, images, volumes)
```

Use `make clean-all-dry-run` to preview cleanup operations.

## 🔒 SSL/HTTPS Integration

**Fully automated HTTPS with zero manual steps!**

### ✅ What Works Automatically

```bash
make production  # Complete SSL-enabled deployment in one command
```

**Automated SSL Features:**
- **🔐 Certificate Generation**: Self-signed certificates with proper SAN entries
- **🚀 Kubernetes Integration**: TLS secrets automatically created and mounted
- **🌐 Nginx Configuration**: Both HTTP (80) and HTTPS (443) configured
- **🧪 Health Validation**: Both protocols tested during deployment
- **📊 Status Monitoring**: `make production-status` shows HTTP + HTTPS health

### 🌐 HTTPS Access Points

| Service | HTTP URL | HTTPS URL | Notes |
|---------|----------|-----------|-------|
| **Web Frontend** | `http://localhost` | `https://localhost` | 🔒 Accept security warning |
| **API Health** | `http://localhost:8000/health` | `https://localhost/health` | 🔒 Both protocols work |
| **API Docs** | `http://localhost:8000/docs` | `https://localhost/api/docs` | 🔒 Swagger via HTTPS |

### 🧪 Testing HTTPS

```bash
# Verify HTTPS is working
curl -k https://localhost/health

# Check SSL certificate details
openssl s_client -connect localhost:443 -servername localhost < /dev/null

# Complete status including HTTPS
make production-status
```

### 📚 SSL Documentation

- **Core Script**: [`scripts/validate-ssl-certificates.sh`](scripts/validate-ssl-certificates.sh) - SSL certificate generation and validation
- **Certificate Report**: [`ssl-certificate-report.txt`](ssl-certificate-report.txt) - Generated certificate details
- **SSL Configuration**: [`nginx/ssl-include.conf`](nginx/ssl-include.conf) - Nginx SSL settings

### 🔧 Browser HTTPS Access

When accessing `https://localhost` for the first time, you'll see a security warning because we use self-signed certificates. This is **expected and safe for development**:

**Chrome/Edge:**
1. Click "Advanced" or "Details"
2. Click "Proceed to localhost (unsafe)"

**Firefox:**
1. Click "Advanced"
2. Click "Accept the Risk and Continue"

**Safari:**
1. Click "Show Details"
2. Click "visit this website"

**Why this happens:** Self-signed certificates aren't verified by a trusted Certificate Authority. In production, use certificates from Let's Encrypt or your organization's CA.

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│    Nginx    │───▶│ Python API  │───▶│ PostgreSQL  │
│  (Browser)  │    │(Port 80/443)│    │  (Port 8000)│    │ (Port 5432) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 🧠 Design and Architecture Decisions

### Kubernetes Architecture Choices

#### **StatefulSet for PostgreSQL Database**
**Decision**: Used StatefulSet instead of Deployment for PostgreSQL
**Justification**:
- **Persistent Identity**: StatefulSet provides stable, unique network identifiers (`api-demo-postgres-0`) critical for database clustering and backup procedures
- **Ordered Deployment**: Ensures predictable startup sequence, crucial for database initialization and connection handling
- **Persistent Storage**: Guarantees consistent PVC attachment across pod restarts, preventing data loss
- **Stable Network Identity**: Enables reliable service discovery for database connections, especially important in multi-replica scenarios

**Alternative Considered**: Deployment with PVC
**Why Rejected**: Deployments don't guarantee pod naming consistency or ordered scaling, risking data corruption in database scenarios

#### **Meaningful Volume Naming Strategy**
**Decision**: Implemented descriptive PVC naming instead of auto-generated names
**Implementation**:
- **StatefulSet Name**: `api-demo-postgres` (was: `postgres-statefulset`)
- **Volume Claim Template**: `postgres-data` (was: `postgres-storage`)  
- **Resulting PVC**: `postgres-data-api-demo-postgres-0` ✅

**Benefits**:
- **🏷️ Clear Identification**: PVC name immediately indicates purpose and environment
- **🔍 Easier Troubleshooting**: Meaningful names in `kubectl get pvc` output
- **📊 Better Monitoring**: Volume metrics clearly labeled in Prometheus/Grafana
- **🚀 DevOps Friendly**: Operations team can quickly identify storage resources

**Volume Naming Convention**:
```bash
# Pattern: {purpose}-{service}-{component}-{replica}
postgres-data-api-demo-postgres-0  # Production database storage
logs-api-staging-app-0             # Staging application logs (future)
cache-api-production-redis-0       # Production Redis cache (future)
```

**Docker vs Kubernetes Volume Management**:
- **Docker Compose**: Uses named volumes (`postgres_data` → `api-deployment-demo_staging_postgres_data`)
- **Kubernetes**: Uses meaningful PVCs (`postgres-data-api-demo-postgres-0`)
- **Kind Nodes**: Use anonymous volumes (normal infrastructure behavior)

#### **Headless Service for Database**
**Decision**: Implemented headless service (`clusterIP: None`) for PostgreSQL
**Justification**:
- **Direct Pod Access**: Allows applications to connect directly to specific database pods without load balancing
- **StatefulSet Integration**: Works seamlessly with StatefulSet's stable network identities
- **DNS Resolution**: Provides predictable DNS names (`api-demo-postgres-0.postgres-headless.api-deployment-demo.svc.cluster.local`)
- **Database Clustering**: Essential for future PostgreSQL clustering (primary/replica configurations)

**Alternative Considered**: Standard ClusterIP service
**Why Rejected**: Load balancing database connections can cause session affinity issues and complicates connection pooling

#### **Network Policies for Security Isolation**
**Decision**: Implemented namespace-level network policies
**Justification**:
- **Zero-Trust Networking**: Default deny with explicit allow rules
- **Microservice Isolation**: Each service only accessible by authorized components
- **Attack Surface Reduction**: Limits lateral movement in case of compromise
- **Compliance**: Meets security requirements for production deployments

### TLS and Certificate Management

#### **Automated Certificate Generation**
**Decision**: Self-signed certificates with automated generation via `generate-ssl.sh`
**Justification**:
- **Development Velocity**: Enables immediate HTTPS testing without external dependencies
- **Cost Efficiency**: No certificate authority costs for development/staging
- **Automation**: Consistent certificate generation across environments
- **Extensibility**: Script easily replaceable with Let's Encrypt or enterprise CA integration

**Production Strategy**: Replace with cert-manager for automatic Let's Encrypt certificates or integrate with enterprise PKI

#### **TLS Termination at Nginx**
**Decision**: Terminate TLS at the Nginx reverse proxy layer
**Justification**:
- **Performance**: Dedicated TLS handling optimized for high throughput
- **Certificate Management**: Centralized certificate storage and rotation
- **Flexibility**: Easy to implement different TLS policies per service
- **Observability**: Centralized TLS metrics and logging

### Horizontal Pod Autoscaling (HPA)

#### **Metrics-Based Scaling**
**Decision**: CPU and memory-based autoscaling for API and Nginx pods
**Justification**:
- **Resource Efficiency**: Automatic scaling prevents over-provisioning
- **Cost Management**: Scales down during low usage periods
- **Performance**: Scales up before resource exhaustion impacts users
- **Custom Metrics Ready**: Foundation for application-specific metrics scaling

**Configuration**:
- **API Scaling**: 2-10 replicas based on 70% CPU utilization
- **Nginx Scaling**: 2-5 replicas based on 80% CPU utilization
- **Database**: Intentionally excluded from HPA due to stateful nature

## 🔧 Infrastructure as Code Strategy

### Ansible Vault Integration

#### **Sensitive Data Management**
**Implementation**: Ansible Vault for encrypting sensitive variables
**Strategy**:
```yaml
# Encrypted with ansible-vault
$ANSIBLE_VAULT;1.1;AES256
66613834663...
```

**Benefits**:
- **Version Control Safe**: Encrypted secrets can be committed to repositories
- **Role-Based Access**: Different vault passwords for different environments
- **Audit Trail**: Changes to secrets are tracked in git history
- **Team Collaboration**: Secure secret sharing without external tools

**CI/CD Integration**:
- Vault passwords stored in CI/CD secret management (GitHub Secrets, Jenkins Credentials)
- Automated decryption during deployment pipelines
- Environment-specific vault files for staging/production isolation

#### **Secret Rotation Strategy**
**Automated Rotation**: Integration with HashiCorp Vault or AWS Secrets Manager
**Manual Rotation**: Use `scripts/validate-ssl-certificates.sh` to regenerate certificates
**Emergency Procedures**: Break-glass access for critical situations

### CI/CD Pipeline Integration

#### **GitOps Workflow**
**Strategy**: Infrastructure and application code in same repository
**Benefits**:
- **Atomic Deployments**: Infrastructure and application changes deployed together
- **Rollback Capability**: Easy rollback of both infrastructure and application
- **Audit Trail**: Complete deployment history in git log
- **Branch Protection**: Infrastructure changes require code review

#### **Pipeline Stages**
```yaml
1. Code Quality Gates:
   - Linting (Ansible, YAML, Python)
   - Security scanning (ansible-lint, hadolint)
   - Unit tests

2. Infrastructure Validation:
   - Ansible playbook syntax validation
   - Kubernetes manifest validation (kubeval)
   - Terraform plan (if applicable)

3. Deployment:
   - Staging deployment with Ansible
   - Integration tests
   - Production deployment approval gate
   - Production deployment

4. Post-Deployment:
   - Health checks
   - Monitoring validation
   - Performance testing
```

#### **Environment Promotion**
**Staging → Production**: Automated with manual approval gates
**Feature Branches**: Temporary environments for testing
**Rollback Strategy**: Automated rollback on health check failures

## ⚖️ Design Trade-offs and Assumptions

### Current Limitations and Assumptions

#### **Assumptions Made**
1. **Single Availability Zone**: Current setup assumes single-AZ deployment
   - **Implication**: No protection against AZ-level failures
   - **Future Improvement**: Multi-AZ deployment with pod anti-affinity rules

2. **Development-First SSL**: Self-signed certificates assumed acceptable for development
   - **Implication**: Browser warnings in development
   - **Production Plan**: Integration with Let's Encrypt or enterprise CA

3. **Stateful Database**: Single PostgreSQL instance without clustering
   - **Implication**: Database becomes single point of failure
   - **Future Improvement**: PostgreSQL clustering with pg_auto_failover

4. **Local Storage**: Kind cluster uses local storage
   - **Implication**: Data loss on cluster destruction
   - **Production Plan**: Integration with cloud storage (EBS, GCE PD)

#### **Architectural Trade-offs**

##### **Monolithic vs Microservices**
**Decision**: Single API service instead of microservices
**Trade-offs**:
- ✅ **Pros**: Simpler deployment, fewer network calls, easier development
- ❌ **Cons**: Harder to scale individual components, technology lock-in
- **Future Path**: Extract user management, authentication as separate services

##### **Container Orchestration Choice**
**Decision**: Kubernetes over Docker Swarm or nomad
**Trade-offs**:
- ✅ **Pros**: Industry standard, rich ecosystem, advanced features
- ❌ **Cons**: Complexity overhead, learning curve, resource usage
- **Alternative**: Docker Swarm for simpler deployments

##### **Monitoring Stack**
**Decision**: Prometheus + Grafana over ELK stack or commercial solutions
**Trade-offs**:
- ✅ **Pros**: Cloud-native, excellent Kubernetes integration, cost-effective
- ❌ **Cons**: Learning curve, requires configuration, limited log analysis
- **Enhancement**: Consider adding ELK for centralized logging

##### **Database Choice**
**Decision**: PostgreSQL over MySQL, MongoDB, or cloud databases
**Trade-offs**:
- ✅ **Pros**: ACID compliance, JSON support, excellent performance
- ❌ **Cons**: More complex than MySQL, not as horizontally scalable as NoSQL
- **Cloud Alternative**: Consider managed databases (RDS, Cloud SQL) for production

### Future Improvement Areas

#### **Scalability Enhancements**
1. **Database Clustering**: Implement PostgreSQL streaming replication
2. **Caching Layer**: Add Redis for API response caching
3. **CDN Integration**: Static asset delivery optimization
4. **Connection Pooling**: Implement PgBouncer for database connections

#### **Security Hardening**
1. **Network Segmentation**: Implement service mesh (Istio) for advanced networking
2. **Secret Management**: Integrate with external secret managers (Vault, AWS Secrets)
3. **Image Scanning**: Automated vulnerability scanning in CI/CD
4. **Policy as Code**: Implement OPA Gatekeeper for Kubernetes policies

#### **Operational Excellence**
1. **Disaster Recovery**: Automated backup and restore procedures
2. **Multi-Region**: Cross-region deployment for high availability
3. **Chaos Engineering**: Implement chaos testing for resilience validation
4. **Performance Monitoring**: APM integration (Jaeger, New Relic)

#### **Developer Experience**
1. **Local Development**: Improve local development with Tilt or Skaffold
2. **Testing**: Implement comprehensive integration test suite
3. **Documentation**: Interactive API documentation and architectural decision records (ADRs)
4. **Debugging**: Implement remote debugging capabilities

## 📁 Repository Structure

```
api-deployment-demo/
├── Makefile                           # Complete automation commands with secret management
├── docker-compose.yml                 # Staging environment orchestration  
├── kind-config.yaml                   # Kubernetes cluster configuration
├── .env.example                       # Environment configuration template (safe to commit)
├── .env                               # Actual environment values (gitignored)
├── .gitignore                         # Enhanced with security-focused ignores
├── api/                               # Python API service
│   ├── Dockerfile                     # API container definition
│   ├── main.py                        # FastAPI application with metrics
│   ├── requirements.txt               # Python dependencies
│   └── gunicorn.conf.py               # Gunicorn configuration
├── nginx/                             # Nginx reverse proxy
│   ├── Dockerfile                     # Nginx container definition
│   ├── nginx.conf                     # Main Nginx configuration
│   ├── common-config.conf             # Shared Nginx settings
│   ├── ssl-include.conf               # SSL configuration include
│   ├── generate-ssl.sh                # SSL certificate generation script
│   ├── health-check.sh                # Nginx health monitoring script
│   ├── index.html                     # Welcome page
│   ├── ssl/                           # SSL certificates directory
│   └── logs/                          # Nginx logs directory
├── database/                          # Database configuration
│   ├── init.sql                       # Database initialization script
│   └── postgresql.conf                # PostgreSQL configuration
├── kubernetes/                        # Kubernetes manifests
│   ├── namespace.yaml                 # Namespace definition
│   ├── configmaps.yaml                # Configuration data
│   ├── secrets-*.yaml                 # Generated secrets (gitignored, from .env)
│   ├── configmap-*.yaml               # Generated configmaps (gitignored, from .env)
│   ├── persistent-volumes.yaml        # Storage configuration
│   ├── postgres-deployment.yaml       # Database StatefulSet deployment (updated naming)
│   ├── postgres-init-configmap.yaml   # Database initialization
│   ├── api-deployment.yaml            # API service deployment
│   ├── nginx-deployment.yaml          # Nginx proxy deployment
│   ├── nginx-html-configmap.yaml      # Nginx HTML content configuration
│   ├── nginx-ingress-controller.yaml  # Nginx ingress controller
│   ├── nodeport-services.yaml         # NodePort service definitions
│   ├── ingress.yaml                   # Basic ingress configuration
│   ├── https-ingress.yaml             # HTTPS ingress configuration
│   ├── production-ingress.yaml        # Production ingress rules
│   ├── hpa.yaml                       # Horizontal Pod Autoscaler
│   ├── network-policy.yaml            # Network security policies
│   ├── monitoring-ingress.yaml        # Ingress for monitoring services
│   ├── monitoring-nodeport.yaml       # NodePort for monitoring services  
│   ├── monitoring-loadbalancer.yaml   # LoadBalancer for monitoring
│   ├── monitoring-secrets.yaml        # Monitoring authentication secrets
│   ├── grafana-*.yaml                 # Grafana configuration files
│   ├── prometheus-*.yaml              # Prometheus configuration files
│   └── tls-secret.yaml                # TLS certificate secrets
├── scripts/                           # Active utility and automation scripts (archived scripts available in scripts/archived/ for reference)
│   ├── generate-secrets.sh            # 🔐 Environment-based secret generation
│   ├── get-grafana-password.sh        # 🔐 Secure password retrieval helper
│   ├── validate-ssl-certificates.sh   # 🔒 Core SSL certificate generation
│   ├── cleanup-all.sh                 # Complete environment cleanup
│   ├── generate-traffic.sh            # Test traffic generation for dashboards
│   ├── test-automated-deployment.sh   # Comprehensive deployment testing
│   ├── test-production-deployment.sh  # Production deployment validation
│   ├── promote-to-production.sh       # Production promotion workflow
│   ├── quick-start.sh                 # Interactive setup guide
│   ├── load-test.sh                   # Performance testing
│   ├── controlled-load-test.sh        # Load testing with controls
│   ├── autoscaling-status.sh          # HPA monitoring and status
│   ├── security-audit.sh              # Security audit and validation
│   ├── git-security-audit.sh          # Git repository security audit
│   └── archived/                      # Archived obsolete scripts
│       ├── README.md                  # Archive documentation
│       ├── start-monitoring.sh        # Legacy port-forwarding script
│       ├── verify-dashboard.sh        # Legacy manual verification
│       ├── setup-local-cluster.sh     # Legacy cluster setup
│       ├── enable-https.sh            # Legacy HTTPS setup
│       ├── health-check-host.sh       # Legacy health checking
│       ├── verify-cleanup.sh          # Legacy cleanup verification
│       ├── verify-monitoring.sh       # Legacy monitoring verification
│       ├── demo-architecture.sh       # Architecture demo script
│       ├── demo-automation.sh         # Automation demo script
│       └── test-configuration.sh      # Legacy configuration testing
├── ssl-certificate-report.txt        # SSL certificate generation report
└── ansible/                           # Ansible deployment automation
    ├── site.yml                       # Main playbook
    ├── inventory.ini                  # Inventory configuration
    ├── group_vars/                    # Group variable configurations
    │   ├── all.yml                    # Common variables
    │   └── staging.yml                # Staging-specific variables
    ├── host_vars/                     # Host-specific variables
    └── roles/                         # Ansible roles
        ├── docker/                    # Docker installation and setup
        ├── ssl-certificates/          # SSL certificate management
        ├── api-app/                   # Application deployment
        ├── database/                  # Database configuration
        └── monitoring/                # System monitoring setup
```

## 🎯 Getting Started Demo

All deployment options are automated through our comprehensive Makefile:

```bash
# Clone and enter the repository
git clone https://github.com/adamrocha/api-deployment-demo.git
cd api-deployment-demo

# Quick deployment options
make quick-staging      # Docker Compose staging environment
make production         # 🔒 Kubernetes with SSL/HTTPS + full monitoring stack
make quick-dev         # Development environment

# Check what's running (includes HTTPS status)
make production-status  # Shows HTTP + HTTPS health checks

# Generate test traffic for monitoring
make traffic

# Clean up when done
make clean
```

**Access Points After Setup:**
- **Staging (Docker Compose)**: http://localhost:30800 (API), http://localhost:30080 (Web)
- **Production (Kubernetes)**: 
  - **HTTP**: http://localhost:8000 (API), http://localhost (Web)
  - **🔒 HTTPS**: https://localhost (Web + API), https://localhost/health (API Health)
  - **Monitoring**: http://localhost:3000 (Grafana), http://localhost:9090 (Prometheus)
- **Complete Automation**: All services including SSL/HTTPS accessible without manual configuration!

## 🚀 Deployment Automation

All deployment scenarios are fully automated through the Makefile. For detailed commands and options:

```bash
make help  # Show all available automation commands
```

### Key Deployment Features
- ✅ **Zero Manual Configuration**: Complete automation from build to deployment
- ✅ **🔒 SSL/HTTPS Automation**: Fully automated certificate generation and HTTPS configuration
- ✅ **Environment Isolation**: Staging and production can run simultaneously
- ✅ **Dual Protocol Health Validation**: Automated HTTP and HTTPS health checks with retry logic
- ✅ **Monitoring Integration**: Full observability stack included
- ✅ **Cleanup Automation**: Progressive cleanup options for different scenarios

## 🔧 Configuration

### Environment Variables

All configuration is managed through environment variables documented in `.env.example`. Key settings include:

```bash
# Database
DB_NAME=api_staging
DB_USER=postgres  
DB_PASSWORD=your_secure_password

# API
API_ENV=staging
DEBUG=false
SECRET_KEY=your-secret-key

# SSL
SSL_ENABLED=true
SERVER_NAME=localhost

# Resources
API_WORKERS=4
LOG_LEVEL=info
```

### 🔒 SSL/HTTPS Configuration

SSL certificates are **automatically generated and configured** during deployment:

```bash
# SSL is fully automated - no manual steps required!
make production         # Automatically generates SSL certificates and configures HTTPS

# SSL configuration happens automatically:
# ✅ Self-signed certificates generated with proper SAN entries
# ✅ Kubernetes TLS secrets created
# ✅ Nginx configured for both HTTP (80) and HTTPS (443)
# ✅ Browser access ready at https://localhost (accept security warning)

# Verify SSL status
make production-status  # Shows both HTTP and HTTPS health checks
```

**🎯 Key SSL Features:**
- **Automated Generation**: Certificates created during `make production`
- **Browser Ready**: HTTPS works immediately at `https://localhost`
- **Dual Protocol**: Both HTTP and HTTPS endpoints available
- **Comprehensive Testing**: Status checks verify both protocols

## 📚 API Documentation

| Method | Endpoint      | Description                        |
|--------|---------------|------------------------------------|
| GET    | `/`           | Welcome page                       |
| GET    | `/health`     | Health check                       |
| GET    | `/docs`       | Interactive API docs (Swagger)     |
| GET    | `/redoc`      | Alternative API docs               |
| POST   | `/users/`     | Create a new user                  |
| GET    | `/users/`     | List all users                     |
| GET    | `/users/{id}` | Get user by ID                     |
| DELETE | `/users/{id}` | Delete user by ID                  |

### Example Usage

```bash
# Health check (production HTTP)
curl http://localhost:8000/health

# Health check (production HTTPS) 🔒
curl -k https://localhost/health

# Health check (staging)  
curl http://localhost:30800/health

# Create user (production HTTP)
curl -X POST "http://localhost:8000/users/" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}'

# Create user (production HTTPS) 🔒
curl -k -X POST "https://localhost/users/" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}'

# Create user (staging)
curl -X POST "http://localhost:30800/users/" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}'

# Get users (production HTTP)
curl http://localhost:8000/users/

# Get users (production HTTPS) 🔒
curl -k https://localhost/users/

# Get users (staging)
curl http://localhost:30800/users/
```

## 📊 Observability and Monitoring Architecture

### Prometheus Monitoring Setup

#### **Metrics Collection Strategy**
**Architecture**: Pull-based metrics collection with service discovery
**Components**:
- **Prometheus Server**: Central metrics aggregation and storage
- **Node Exporter**: System-level metrics (CPU, memory, disk, network)
- **cAdvisor**: Container-level metrics (embedded in kubelet)
- **Custom Application Metrics**: Business logic and API performance metrics

#### **Service Discovery Configuration**
```yaml
# Kubernetes service discovery
kubernetes_sd_configs:
  - role: pod
    namespaces:
      names: ["api-deployment-demo", "monitoring"]
```

**Benefits**:
- **Automatic Discovery**: New services automatically discovered and monitored
- **Label-Based Filtering**: Fine-grained control over metric collection
- **Dynamic Configuration**: No manual configuration updates for new services

#### **Metric Categories**
1. **Infrastructure Metrics**:
   - CPU, memory, disk utilization per node
   - Network traffic and error rates
   - Kubernetes resource usage

2. **Application Metrics**:
   - API request rates and response times
   - Database connection pool status
   - Custom business metrics (user registrations, API calls)

3. **Security Metrics**:
   - Failed authentication attempts
   - SSL certificate expiration dates
   - Network policy violations

### Grafana Dashboard Configuration

#### **Dashboard Architecture**
**Hierarchical Organization**:
- **Executive Overview**: High-level business and system health metrics
- **Infrastructure Monitoring**: Detailed system performance dashboards
- **Application Performance**: API-specific metrics and traces
- **Security Monitoring**: Security events and compliance metrics

#### **Key Dashboards Implemented**
1. **System Overview Dashboard**:
   - Cluster resource utilization
   - Pod status and restarts
   - Network traffic patterns
   - Storage usage trends

2. **API Performance Dashboard**:
   - Request rate and error rate trends
   - Response time percentiles (p50, p95, p99)
   - Database query performance
   - Endpoint-specific metrics

3. **Database Monitoring Dashboard**:
   - Connection pool status
   - Query performance metrics
   - Lock wait times
   - Storage usage and growth trends

#### **Alerting Strategy**
**Alert Levels**:
- **Critical**: Service down, data loss risk (immediate response)
- **Warning**: Performance degradation, capacity thresholds (respond within 30min)
- **Info**: Planned maintenance, deployment notifications

**Alert Routing**:
```yaml
# Example alerting rules
groups:
  - name: api_alerts
    rules:
      - alert: APIHighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "API error rate is above 10%"
```

#### **Visualization Best Practices**
- **Color Consistency**: Red for errors, green for success, yellow for warnings
- **Time Range Selection**: Default to last 1 hour with quick range selectors
- **Drill-Down Capability**: Click-through from overview to detailed views
- **Mobile Responsiveness**: Dashboards optimized for mobile monitoring

### Metrics and KPIs

#### **Golden Signals Monitoring**
1. **Latency**: API response times across all endpoints
2. **Traffic**: Request rates and concurrent users
3. **Errors**: Error rates by endpoint and error type
4. **Saturation**: Resource utilization (CPU, memory, disk)

#### **Business Metrics**
- **User Registration Rate**: New user signups per hour/day
- **API Usage Patterns**: Most frequently used endpoints
- **Geographic Distribution**: User location analysis
- **Performance SLA Compliance**: Uptime and response time SLA tracking

#### **Operational Metrics**
- **Deployment Frequency**: Release cadence tracking
- **Recovery Time**: Mean time to recovery (MTTR) from incidents
- **Change Failure Rate**: Percentage of deployments causing issues
- **Lead Time**: Time from code commit to production deployment

### Log Management Strategy

#### **Centralized Logging Architecture**
**Current Implementation**: Container logs via `kubectl logs`
**Future Enhancement**: ELK Stack (Elasticsearch, Logstash, Kibana) integration

#### **Log Levels and Structure**
```json
{
  "timestamp": "2025-10-22T20:00:00Z",
  "level": "INFO",
  "service": "api-service",
  "trace_id": "abc123",
  "user_id": "user123",
  "message": "User registration successful",
  "duration_ms": 245,
  "endpoint": "/users/",
  "status_code": 201
}
```

#### **Log Retention Policy**
- **Application Logs**: 30 days local, 90 days archived
- **Access Logs**: 7 days local, 30 days archived
- **Security Logs**: 90 days local, 1 year archived
- **Audit Logs**: 1 year local, 7 years archived (compliance)

### Health Check Strategy

#### **Multi-Level Health Checks**
1. **Liveness Probes**: Basic service availability
2. **Readiness Probes**: Service ready to handle traffic
3. **Startup Probes**: Application initialization status
4. **Custom Health Endpoints**: Business logic health validation

#### **Health Check Implementation**
```python
# API health endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "database": await check_database_connection(),
        "dependencies": await check_external_dependencies()
    }
```

#### **Health Check Metrics**
- **Response Time Tracking**: Health endpoint performance
- **Dependency Status**: External service health monitoring
- **Error Pattern Analysis**: Health check failure correlation
- **Availability Calculation**: Uptime percentage tracking

### Performance Monitoring

#### **Application Performance Monitoring (APM)**
**Future Integration**: Jaeger for distributed tracing
**Benefits**:
- **Request Tracing**: End-to-end request flow visualization
- **Bottleneck Identification**: Performance issue root cause analysis
- **Service Dependency Mapping**: Inter-service communication patterns
- **Error Context**: Detailed error information with stack traces

#### **Resource Optimization**
**Monitoring Targets**:
- **Pod Resource Usage**: CPU and memory optimization opportunities
- **Network Performance**: Inter-pod communication efficiency
- **Storage I/O**: Database and file system performance
- **Cache Hit Rates**: Future Redis implementation optimization

#### **Capacity Planning**
**Predictive Analytics**:
- **Growth Trend Analysis**: Resource usage growth patterns
- **Seasonal Pattern Recognition**: Traffic variation modeling
- **Scaling Recommendations**: Automated scaling threshold suggestions
- **Cost Optimization**: Resource allocation efficiency analysis

## 🏥 Monitoring & Health Checks

All monitoring and health check operations are automated through the Makefile:

```bash
# Environment status and health (includes HTTPS checks)
make production-status  # Check HTTP + HTTPS endpoints and pod status
make logs               # View logs for active environment
make monitoring-status  # Check monitoring stack health

# Generate test data for monitoring
make traffic           # Generate test traffic for metrics

# Access monitoring dashboards (after make production)
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000 (admin/use scripts/get-grafana-password.sh)
# HTTPS Web:  https://localhost (accept security warning for self-signed cert)
# HTTPS API:  https://localhost/health

# Get Grafana credentials easily
./scripts/get-grafana-password.sh  # Shows username and password
```

### Automated Health Validation
- **Staging Environment**: Health checks via `make status`
- **Production Environment**: Comprehensive monitoring with Prometheus/Grafana + SSL/HTTPS validation
- **🔒 SSL/HTTPS Monitoring**: Automated health checks for both HTTP and HTTPS endpoints
- **Continuous Monitoring**: Automated health probes and alerting

## 🔒 Security Features

- **Container Security**: Non-root users, resource limits
- **Network Security**: Network policies, firewall rules
- **🔒 SSL/TLS**: **Fully automated HTTPS integration**:
  - **Zero Manual Steps**: SSL certificates auto-generated during deployment
  - **Browser Ready**: HTTPS accessible immediately at `https://localhost`
  - **Dual Protocol Support**: Both HTTP and HTTPS endpoints available
  - **Comprehensive Testing**: Automated health checks for both protocols
  - **Makefile Integration**: `make production` includes complete SSL setup
- **Secret Management**: 🆕 **Environment-based secret management**:
  - **Standard Workflow**: `.env.example` → `.env` → `make apply-secrets`
  - **Secure by Default**: All sensitive values managed via .env files
  - **Zero Hardcoded Passwords**: Eliminated all `admin123` references
  - **Grafana Security**: Anonymous access disabled, authentication required
  - **Password Retrieval**: `./scripts/get-grafana-password.sh` for secure access
  - **External Integration**: Supports HashiCorp Vault, AWS Secrets Manager, Sealed Secrets
  - **Automated Generation**: `./scripts/generate-secrets.sh` for safe secret handling
  - **Git Protection**: Zero secrets committed to version control
- **Headers**: Security headers via Nginx
- **Input Validation**: API request validation
- **Makefile Integration**: `make generate-secrets`, `make validate-env`, `make apply-secrets`

📖 **Implementation**: See [`scripts/generate-secrets.sh`](scripts/generate-secrets.sh) for detailed secret generation process

## 🔧 Environment Configuration

### Standard Workflow (Recommended)

The project follows the standard `.env` file pattern for configuration:

```bash
# 1. Copy template to working file
make setup-env        # Copies .env.example to .env

# 2. Edit with your actual values
nano .env             # Set actual values for empty variables

# 3. Generate Kubernetes secrets
make generate-secrets # Creates kubernetes/secrets-*.yaml

# 4. Apply to cluster
make apply-secrets    # Deploys secrets to Kubernetes
```

### File Structure
- **`.env.example`** - Template with empty values (committed to git)
- **`.env`** - Your actual configuration (gitignored for security)
- **`kubernetes/secrets-*.yaml`** - Generated manifests (gitignored)

### Key Configuration Variables
```bash
# Database
DB_PASSWORD=your_secure_password
DATABASE_URL=postgresql://...

# Application
SECRET_KEY=your_secret_key
API_ENV=production

# Monitoring
GRAFANA_ADMIN_PASSWORD=your_grafana_password
```

📖 **Advanced Configuration**: Modify [`scripts/generate-secrets.sh`](scripts/generate-secrets.sh) for custom secret management workflows.

## 🔍 Operations and Troubleshooting

### Volume and Storage Management

#### **Inspecting Volume Status**
```bash
# Check PersistentVolumeClaims with meaningful names
kubectl get pvc -n api-deployment-demo
# Shows: postgres-data-api-demo-postgres-0  (meaningful! ✅)

# Check PersistentVolumes  
kubectl get pv
# Shows underlying storage details

# Describe specific PVC for detailed information
kubectl describe pvc postgres-data-api-demo-postgres-0 -n api-deployment-demo

# Check pod volume mounts
kubectl describe pod api-demo-postgres-0 -n api-deployment-demo | grep -A10 "Volumes:"
```

#### **Docker vs Kubernetes Volume Inspection**

**Docker Compose (Staging)**:
```bash
# Check named volumes (meaningful names)
docker volume ls
# Shows: api-deployment-demo_staging_postgres_data ✅

# Inspect volume details
docker volume inspect api-deployment-demo_staging_postgres_data
```

**Kubernetes (Production)**:
```bash
# Check application volumes (meaningful names)  
kubectl get pvc -n api-deployment-demo
# Shows: postgres-data-api-demo-postgres-0 ✅

# Note: Kind infrastructure uses anonymous Docker volumes (normal behavior)
docker ps --format "table {{.Names}}\t{{.Image}}"
# Shows: api-demo-cluster-worker (uses internal anonymous volumes)
```

#### **Volume Troubleshooting**

**Common Issues**:
1. **PVC Pending**: Check storage class and node capacity
   ```bash
   kubectl describe pvc postgres-data-api-demo-postgres-0 -n api-deployment-demo
   kubectl get storageclass
   ```

2. **Pod Stuck in ContainerCreating**: Usually volume mount issues  
   ```bash
   kubectl describe pod api-demo-postgres-0 -n api-deployment-demo
   kubectl get events -n api-deployment-demo --sort-by='.lastTimestamp'
   ```

3. **Data Loss After Pod Restart**: Verify PVC is Bound
   ```bash
   kubectl get pvc -n api-deployment-demo
   # Status should be "Bound", not "Pending" or "Lost"
   ```

### Health and Status Monitoring

```bash
# Complete environment status
make production-status     # HTTP + HTTPS health checks

# Pod health
kubectl get pods -n api-deployment-demo -o wide

# Service endpoints
kubectl get svc -n api-deployment-demo

# Resource usage
kubectl top pods -n api-deployment-demo
kubectl top nodes
```

### Backup and Recovery

```bash
# Database backup (example for PostgreSQL)
kubectl exec -n api-deployment-demo api-demo-postgres-0 -- pg_dump -U postgres api_demo > backup.sql

# Volume backup (copy data from PVC)
kubectl cp api-deployment-demo/api-demo-postgres-0:/var/lib/postgresql/data ./postgres-backup/
```

## 🌍 Environment Support


| Environment | Docker Compose | Ansible | Kubernetes |
|-------------|----------------|---------|------------|
| Development | ✅             | ✅      | ✅         |
| Staging     | ✅             | ✅      | ✅         |
| Production  | ✅             | ✅      | ✅         |

## 📝 Notes

- **Configuration**: Always start with `make setup-env` to copy the template
- **Secrets**: Set all empty values before deployment
- **SSL**: Replace self-signed certificates with proper SSL certificates for production
- **Monitoring**: Configure monitoring and alerting for production environments  
- **Backups**: Implement regular database backup procedures
- **Updates**: Keep container images and dependencies updated

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with all deployment methods
4. Submit a pull request

---

**Built for production deployments with Docker, Ansible, and Kubernetes** 🚀
