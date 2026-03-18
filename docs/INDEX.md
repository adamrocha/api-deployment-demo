# Documentation Index

📚 **Complete guide to the API Deployment Demo project**

## 🚀 Getting Started

**New to this project?** Start here:

1. **[../README.md](../README.md)** - Project overview, quick start, and key commands
2. **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Cheat sheet for common tasks
3. **[DEPLOYMENT-METHODS.md](DEPLOYMENT-METHODS.md)** - Choose your deployment approach

## 📖 Core Documentation

### Infrastructure & Deployment

| Document                                       | Purpose                                         | When to Read                 |
| ---------------------------------------------- | ----------------------------------------------- | ---------------------------- |
| [DEPLOYMENT-METHODS.md](DEPLOYMENT-METHODS.md) | Compare Terraform, Ansible, and Make approaches | Choosing deployment strategy |
| [TERRAFORM-GUIDE.md](TERRAFORM-GUIDE.md)       | Deep dive into IaC with Terraform               | Working with infrastructure  |
| [QUICK-REFERENCE.md](QUICK-REFERENCE.md)       | Command cheat sheet and workflows               | Day-to-day operations        |

### Monitoring & Observability

| Document                       | Purpose                                                | When to Read          |
| ------------------------------ | ------------------------------------------------------ | --------------------- |
| [MONITORING.md](MONITORING.md) | Complete monitoring stack guide (Prometheus + Grafana) | Setting up monitoring |

### Security

| Document                                   | Purpose                                       | When to Read         |
| ------------------------------------------ | --------------------------------------------- | -------------------- |
| [SECRETS-SECURITY.md](SECRETS-SECURITY.md) | Security best practices and secret management | Handling credentials |

### Project History

| Document                     | Purpose                              | When to Read                 |
| ---------------------------- | ------------------------------------ | ---------------------------- |
| [CHANGELOG.md](CHANGELOG.md) | Project evolution and recent changes | Understanding what's changed |

## 🗺️ Navigation Guide

### I want to

| Goal                                 | Start Here                                                   |
| ------------------------------------ | ------------------------------------------------------------ |
| **Deploy quickly**                   | [../README.md](../README.md#quick-start) → `make production` |
| **Understand the architecture**      | [../README.md](../README.md#architecture)                    |
| **Choose between Terraform/Ansible** | [DEPLOYMENT-METHODS.md](DEPLOYMENT-METHODS.md)               |
| **Set up monitoring**                | [MONITORING.md](MONITORING.md)                               |
| **Scale applications**               | [QUICK-REFERENCE.md](QUICK-REFERENCE.md#common-workflows)    |
| **Manage secrets securely**          | [SECRETS-SECURITY.md](SECRETS-SECURITY.md)                   |
| **Troubleshoot issues**              | [../README.md](../README.md#troubleshooting)                 |
| **View metrics/dashboards**          | [MONITORING.md](MONITORING.md#grafana-dashboards)            |
| **Run Terraform**                    | [TERRAFORM-GUIDE.md](TERRAFORM-GUIDE.md)                     |
| **Customize configuration**          | [TERRAFORM-GUIDE.md](TERRAFORM-GUIDE.md#configuration)       |

## 📁 Documentation Structure

```text
docs/
├── INDEX.md                   ← You are here!
├── CHANGELOG.md               ← Version history
├── DEPLOYMENT-METHODS.md      ← Terraform vs Ansible vs Make
├── MONITORING.md              ← Prometheus + Grafana guide
├── QUICK-REFERENCE.md         ← Command cheat sheet
├── SECRETS-SECURITY.md        ← Security best practices
└── TERRAFORM-GUIDE.md         ← Infrastructure as Code guide
```

## 🔍 Quick Links by Role

### For Developers

- [Quick Start](../README.md#quick-start) - Get up and running
- [Key Commands](../README.md#key-commands) - Essential commands
- [API Documentation](../api/main.py) - API endpoints

### For DevOps Engineers

- [Architecture](../README.md#architecture) - System design
- [Terraform Guide](TERRAFORM-GUIDE.md) - IaC reference
- [Deployment Methods](DEPLOYMENT-METHODS.md) - Implementation options

### For SREs

- [Monitoring](MONITORING.md) - Observability stack
- [Troubleshooting](../README.md#troubleshooting) - Common issues
- [Scaling](QUICK-REFERENCE.md#scaling) - Autoscaling and manual scaling

### For Security Teams

- [Secrets Management](SECRETS-SECURITY.md) - Credential handling
- [Security Best Practices](SECRETS-SECURITY.md#security-principles) - Core principles
- [TLS/SSL Setup](SECRETS-SECURITY.md#tlsssl-certificates) - Certificate management

## 💡 Tips

- **Start simple**: Run `make production` first, then explore the docs
- **Use the Makefile**: It wraps all complex operations (see [QUICK-REFERENCE.md](QUICK-REFERENCE.md))
- **Bookmark this index**: Return here when you need to find specific information
- **Check CHANGELOG**: See what's new in [CHANGELOG.md](CHANGELOG.md)

---

**Need help?** Check the [Troubleshooting section](../README.md#troubleshooting) or review logs with `make logs-api` / `make logs-nginx`.
