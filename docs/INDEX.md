# Documentation Index

📚 **Streamlined guide to the API Deployment Demo**

## 🚀 Start Here

**New to this project?**

1. **[../README.md](../README.md)** - Project overview and architecture
2. **[QUICK-START.md](QUICK-START.md)** - Get deployed in 3 commands

## 📖 Core Documentation

| Document                                   | Purpose                              | When to Read          |
| ------------------------------------------ | ------------------------------------ | --------------------- |
| [QUICK-START.md](QUICK-START.md)           | Commands, workflows, troubleshooting | Day-to-day operations |
| [MONITORING.md](MONITORING.md)             | Prometheus + Grafana dashboards      | Setting up monitoring |
| [SECRETS-SECURITY.md](SECRETS-SECURITY.md) | Security best practices              | Handling credentials  |

## 🗺️ Quick Navigation

### I want to...

| Goal                            | Start Here                                             |
| ------------------------------- | ------------------------------------------------------ |
| **Deploy the application**      | [QUICK-START.md](QUICK-START.md#-deploy-in-3-commands) |
| **View monitoring dashboards**  | [MONITORING.md](MONITORING.md#quick-start)             |
| **Manage secrets securely**     | [SECRETS-SECURITY.md](SECRETS-SECURITY.md)             |
| **Troubleshoot issues**         | [QUICK-START.md](QUICK-START.md#-troubleshooting)      |
| **Understand the architecture** | [../README.md](../README.md#architecture)              |
| **Scale the application**       | [QUICK-START.md](QUICK-START.md#change-replicas)       |
| **Update configuration**        | [QUICK-START.md](QUICK-START.md#update-configuration)  |
| **Access Grafana dashboards**   | [MONITORING.md](MONITORING.md#grafana-dashboards)      |

## 🏗️ Current Architecture

The project uses **Kustomize + Ansible** for a declarative, reproducible deployment:

```text
┌──────────────────────────────────────┐
│    Make (Simple Commands)            │
└──────────────┬───────────────────────┘
               │
    ┌──────────┴─────────────┐
    ▼                        ▼
┌─────────┐           ┌─────────────┐
│Kustomize│──apply──▶ │   Ansible   │
│Manifests│           │ Orchestrator│
└─────────┘           └─────────────┘
    (Source of Truth)        │
                             ▼
                   ┌──────────────────┐
                   │  Kind Cluster    │
                   │  • API           │
                   │  • Nginx         │
                   │  • PostgreSQL    │
                   │  • Monitoring    │
                   └──────────────────┘
```

## 📁 Project Structure

```text
api-deployment-demo/
├── kustomize/              # Kubernetes manifests (SOURCE OF TRUTH)
│   ├── base/               # Common resources
│   └── overlays/
│       ├── production/     # Production config
│       └── staging/        # Staging config
│
├── ansible/                # Deployment orchestration
│   ├── deploy.yml          # Main playbook
│   └── roles/
│       └── deployment-orchestrator/
│
├── api/                    # FastAPI application
├── nginx/                  # Reverse proxy
├── database/               # PostgreSQL setup
├── scripts/                # Utility scripts
├── docs/                   # This documentation
└── Makefile                # Command interface
```

## 🔄 Common Workflows

### Quick Commands

```bash
make deploy      # Full deployment
make status      # Check health
make logs-api    # View API logs
make urls        # Show access URLs
make destroy     # Remove deployment
```

### Development Workflow

1. Make code changes
2. `make build` - Build new images
3. `make load-images` - Load into cluster
4. `make restart COMPONENT=api` - Restart pods

### Configuration Updates

1. Edit `kustomize/base/` or `kustomize/overlays/`
2. `make deploy` - Apply changes
3. `make status` - Verify deployment

## 📊 Monitoring Stack

- **Prometheus**: Metrics collection at http://localhost:30900
- **Grafana**: Dashboards at http://localhost:30300 (admin/admin)
- **4 Pre-configured dashboards**: API, Infrastructure, Database, Nginx
- **Auto-provisioned**: No manual import needed

See [MONITORING.md](MONITORING.md) for details.

## 🔐 Security

- Secrets generated via `./scripts/generate-secrets.sh`
- TLS certificates auto-generated and applied
- Network policies available (optional)
- Ansible Vault supported for sensitive data

See [SECRETS-SECURITY.md](SECRETS-SECURITY.md) for best practices.

## 🆘 Getting Help

```bash
make help        # List all commands
make validate    # Run all validations
make get-secrets # Display credentials
```

## 📚 Legacy Documentation

Historical reference materials are available in [archive/](archive/):

- Alternative deployment methods (deprecated)
- Deployment method comparisons
- Project consolidation planning

These documents reflect previous project states and are kept for reference only.

## 🔗 External Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Ansible Kubernetes Collection](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
