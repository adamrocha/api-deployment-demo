# API Deployment Demo

A comprehensive **three-tier web application** demonstrating production-ready deployment strategies with:

- 🐍 **Python API** (FastAPI with Gunicorn WSGI server)  
- 🗄️ **PostgreSQL Database**
- 🌐 **Nginx Reverse Proxy** with SSL support

This repository provides **multiple deployment approaches** including Docker Compose, Ansible automation, and Kubernetes orchestration.

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│    Nginx    │───▶│ Python API  │───▶│ PostgreSQL  │
│  (Browser)  │    │(Port 80/443)│    │  (Port 8000)│    │ (Port 5432) │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## 📁 Repository Structure

```
api-deployment-demo/
├── docker-compose.yml           # Staging environment orchestration
├── .env.example                # Environment configuration template
├── .gitignore                  # Git ignore rules
├── api/                        # Python API service
│   ├── Dockerfile             # API container definition
│   ├── main.py                # FastAPI application
│   ├── requirements.txt       # Python dependencies
│   └── gunicorn.conf.py       # Gunicorn configuration
├── nginx/                     # Nginx reverse proxy
│   ├── Dockerfile            # Nginx container definition
│   ├── nginx.conf            # Main Nginx configuration
│   ├── common-config.conf    # Shared Nginx settings
│   ├── generate-ssl.sh       # SSL certificate generation script
│   ├── health-check.sh       # Nginx health monitoring script
│   ├── index.html           # Welcome page
│   ├── ssl/                 # SSL certificates directory
│   └── logs/                # Nginx logs directory
├── database/                 # Database configuration
│   ├── init.sql             # Database initialization script
│   └── postgresql.conf      # PostgreSQL configuration
├── ansible/                  # Ansible deployment automation
│   ├── site.yml             # Main playbook
│   ├── inventory.ini        # Inventory configuration
│   ├── group_vars/          # Group variables
│   │   ├── all.yml         # Common variables
│   │   └── staging.yml     # Staging-specific variables
│   ├── host_vars/          # Host-specific variables
│   └── roles/              # Ansible roles
│       ├── docker/         # Docker installation and setup
│       ├── ssl-certificates/ # SSL certificate management
│       ├── api-app/        # Application deployment
│       └── monitoring/     # System monitoring setup
└── kubernetes/              # Kubernetes manifests
    ├── namespace.yaml      # Namespace definition
    ├── configmaps.yaml     # Configuration data
    ├── secrets.yaml        # Sensitive data (base64 encoded examples)
    ├── persistent-volumes.yaml # Storage configuration
    ├── postgres-deployment.yaml # Database deployment
    ├── postgres-init-configmap.yaml # Database initialization
    ├── api-deployment.yaml # API service deployment
    ├── nginx-deployment.yaml # Nginx proxy deployment
    ├── ingress.yaml        # Ingress configuration
    ├── hpa.yaml           # Horizontal Pod Autoscaler
    └── network-policy.yaml # Network security policies
```

## 🚀 Deployment Options

### 1. Docker Compose (Staging)

**Quick start for staging environment:**

```bash
# Clone repository
git clone https://github.com/adamrocha/api-deployment-demo.git
cd api-deployment-demo

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Deploy with Docker Compose
docker-compose up -d

# Verify deployment
curl http://localhost/health
```

**Access points:**
- **Application**: http://localhost
- **API Docs**: http://localhost/docs
- **Health Check**: http://localhost/health

### 2. Ansible Automation

**Automated server provisioning and deployment:**

```bash
# Configure inventory
cd ansible
cp inventory.ini.example inventory.ini
# Update inventory.ini with your server details

# Deploy to staging
ansible-playbook -i inventory.ini site.yml --limit staging

# Deploy to production  
ansible-playbook -i inventory.ini site.yml --limit production
```

**Ansible features:**
- ✅ Automated Docker installation
- ✅ SSL certificate generation
- ✅ Application deployment
- ✅ Health monitoring setup
- ✅ System configuration

### 3. Kubernetes

**Scalable container orchestration:**

```bash
# Apply all Kubernetes manifests
cd kubernetes

# Create namespace and basic resources
kubectl apply -f namespace.yaml
kubectl apply -f configmaps.yaml
kubectl apply -f secrets.yaml
kubectl apply -f persistent-volumes.yaml

# Deploy database
kubectl apply -f postgres-init-configmap.yaml
kubectl apply -f postgres-deployment.yaml

# Deploy API and Nginx
kubectl apply -f api-deployment.yaml  
kubectl apply -f nginx-deployment.yaml

# Configure networking and scaling
kubectl apply -f ingress.yaml
kubectl apply -f hpa.yaml
kubectl apply -f network-policy.yaml

# Monitor deployment
kubectl get pods -n api-deployment-demo
```

**Kubernetes features:**
- ✅ Horizontal Pod Autoscaling
- ✅ Network policies for security
- ✅ Ingress configuration
- ✅ Resource limits and requests
- ✅ Health checks and probes

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
SERVER_NAME=yourdomain.com

# Resources
API_WORKERS=4
LOG_LEVEL=info
```

### SSL Configuration

The `nginx/generate-ssl.sh` script automatically generates self-signed certificates:

```bash
# Generate SSL certificates
./nginx/generate-ssl.sh

# Configure SSL settings
SSL_ENABLED=true
SSL_SELF_SIGNED=true
SERVER_NAME=yourdomain.com
```

## 📚 API Documentation

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Welcome page |
| GET | `/health` | Health check |
| GET | `/docs` | Interactive API docs (Swagger) |
| GET | `/redoc` | Alternative API docs |
| POST | `/users/` | Create a new user |
| GET | `/users/` | List all users |
| GET | `/users/{id}` | Get user by ID |
| DELETE | `/users/{id}` | Delete user by ID |

### Example Usage

```bash
# Health check
curl http://localhost/health

# Create user
curl -X POST "http://localhost/users/" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "email": "john@example.com"}'

# Get users  
curl http://localhost/users/
```

## 🏥 Monitoring & Health Checks

### Docker Compose
```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs -f

# Health checks
curl http://localhost/health
curl http://localhost/nginx-health
```

### Ansible Monitoring
- Automated log rotation
- System resource monitoring  
- Health check cron jobs
- Email/Slack alerting

### Kubernetes Monitoring
- Built-in health probes
- Resource utilization tracking
- Horizontal Pod Autoscaling
- Network policy enforcement

## 🔒 Security Features

- **Container Security**: Non-root users, resource limits
- **Network Security**: Network policies, firewall rules
- **SSL/TLS**: Automated certificate generation
- **Secret Management**: Kubernetes secrets, Ansible vault
- **Headers**: Security headers via Nginx
- **Input Validation**: API request validation

## 🌍 Environment Support

| Environment | Docker Compose | Ansible | Kubernetes |
|-------------|----------------|---------|------------|
| Development | ✅ | ✅ | ✅ |
| Staging | ✅ | ✅ | ✅ |  
| Production | ✅ | ✅ | ✅ |

## 📝 Notes

- **Secrets**: Update all default passwords and keys before production use
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
