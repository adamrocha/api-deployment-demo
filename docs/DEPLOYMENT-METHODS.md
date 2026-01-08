# Deployment Methods - Quick Reference

This project supports three deployment methods. Choose based on your needs:

## 🚀 Quick Decision Matrix

| I want to... | Use |
| --- | --- | --- |
| Deploy infrastructure declaratively with state tracking | **Terraform** |
| Automate configuration and sequential tasks | **Ansible** |
| Quick manual operations and learning | **Make/Scripts** |
| Work on fresh clones without setup | **Ansible** or **Terraform** |
| Preview changes before applying | **Terraform** |
| Manage cloud resources | **Terraform** |
| Deploy on pre-configured systems | **Ansible** |

## 📖 Method Details

### 1. Terraform (Infrastructure as Code)

**Location:** `terraform/`

**Best for:**

- Declarative infrastructure definitions
- State management and drift detection
- Cloud resource provisioning
- Automatic dependency resolution
- Team collaboration

**Quick Start:**

```bash
make staging         # Deploy staging
make apply           # Deploy production
make output          # View outputs
make clean-tf        # Clean Terraform state
```

**Pros:**
✅ Declarative - describe what you want, not how
✅ Built-in state management
✅ Preview changes with `terraform plan`
✅ Automatic dependency graph
✅ Easy rollback
✅ Idempotent by design

**Cons:**
❌ Learning curve for HCL syntax
❌ State file management needed for teams
❌ Provider limitations

**Files:**

```text
terraform/
├── main.tf           # Provider configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── docker.tf         # Docker image builds
├── staging.tf        # Staging environment
├── production.tf     # Production environment
├── monitoring.tf     # Monitoring stack
└── README.md         # Full documentation
```

### 2. Ansible (Configuration Management)

**Location:** `ansible/`

**Best for:**

- Configuration automation
- Sequential deployment workflows
- Fresh environment setup
- Multi-environment management
- Traditional sysadmin workflows

**Quick Start:**

```bash
# Deploy environments
ansible-playbook ansible/deploy-staging.yml
ansible-playbook ansible/deploy-production.yml
ansible-playbook ansible/deploy.yml -e mode=full-pipeline

# Manage secrets
ansible-playbook ansible/manage-secrets.yml

# Cleanup
ansible-playbook ansible/cleanup.yml -e level=staging
ansible-playbook ansible/cleanup.yml -e level=all
```

**Pros:**
✅ Easy to read YAML syntax
✅ Procedural control flow
✅ Works on fresh clones (auto-creates .env, SSL)
✅ Built-in idempotency
✅ No state file to manage
✅ Rich module ecosystem

**Cons:**
❌ No state tracking
❌ No preview mode (--check is limited)
❌ Manual dependency ordering
❌ Can be verbose

**Files:**

```text
ansible/
├── deploy-staging.yml     # Staging deployment
├── deploy-production.yml  # Production deployment
├── deploy.yml             # Full pipeline
├── manage-secrets.yml     # Secret management
├── cleanup.yml            # Cleanup resources
└── roles/                 # Reusable roles
```

### 3. Make/Scripts (Traditional Commands)

**Location:** `Makefile`, `scripts/`

**Best for:**

- Quick manual operations
- Learning the deployment process
- Debugging and troubleshooting
- One-off tasks
- Custom workflows

**Quick Start:**

```bash
# Automated pipeline
make test

# Manual deployments
make staging
make deploy
make forward

# Status and logs
make status
make logs

# Cleanup
make clean-staging
make clean-production
make clean-all
```

**Pros:**
✅ Simple command syntax
✅ Low learning curve
✅ Full manual control
✅ Easy to understand
✅ No tool dependencies (except make)

**Cons:**
❌ No idempotency
❌ No state management
❌ Manual dependency tracking
❌ No preview mode
❌ Less suitable for automation

**Key Commands:**

```bash
make help              # Show all commands
make staging           # Deploy staging
make production        # Deploy production
make monitoring        # Add monitoring
make clean-all         # Nuclear cleanup
```

## 🔄 Workflow Comparison

### Deploying Staging

**Terraform:**

```bash
cd terraform
terraform init
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

**Ansible:**

```bash
ansible-playbook ansible/deploy-staging.yml
```

**Make:**

```bash
make staging
```

### Deploying Production

**Terraform:**

```bash
cd terraform
terraform plan -var="environment=production"
terraform apply -var="environment=production"
```

**Ansible:**

```bash
ansible-playbook ansible/deploy-production.yml
```

**Make:**

```bash
make production
```

### Cleanup

**Terraform:**

```bash
terraform destroy -var="environment=staging"
```

**Ansible:**

```bash
ansible-playbook ansible/cleanup.yml -e level=staging
```

**Make:**

```bash
make clean-staging
```

## 🎯 Recommended Usage

### For Development

Use **Make** for quick operations:

```bash
make staging
make staging-logs
make clean-staging
```

### For Testing/CI

Use **Ansible** for automated pipelines:

```bash
ansible-playbook ansible/deploy.yml -e mode=full-pipeline
```

### For Production Infrastructure

Use **Terraform** for declarative management:

```bash
terraform apply -var="environment=production"
```

### For Fresh Environments

Use **Ansible** or **Terraform** (both auto-configure):

```bash
# Ansible - auto-creates .env, generates SSL
ansible-playbook ansible/deploy-staging.yml

# Terraform - manages complete infrastructure
terraform apply -var="environment=staging"
```

## 🔧 Tool Installation

### Installing Terraform

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform --version
```

### Ansible

```bash
# macOS
brew install ansible

# Linux
sudo apt install ansible    # Debian/Ubuntu
sudo yum install ansible    # RHEL/CentOS

# Python pip
pip install ansible

# Verify
ansible --version
```

### Make

```bash
# macOS (pre-installed)
which make

# Linux
sudo apt install make       # Debian/Ubuntu
sudo yum install make       # RHEL/CentOS

# Verify
make --version
```

## 📊 Feature Matrix

| Feature | Terraform | Ansible | Make/Scripts |
| --- | --- | --- | --- |
| State tracking | ✅ Yes | ❌ No | ❌ No |
| Idempotency | ✅ Built-in | ✅ Task-level | ❌ Manual |
| Preview changes | ✅ terraform plan | ⚠️ --check | ❌ No |
| Rollback | ✅ Easy | ⚠️ Manual | ❌ Manual |
| Dependency graph | ✅ Automatic | ⏱️ Sequential | 🔧 Manual |
| Cloud resources | ✅ Excellent | ⚠️ Limited | ❌ No |
| Configuration mgmt | ⚠️ Limited | ✅ Excellent | ⚠️ Manual |
| Learning curve | Medium | Low-Medium | Low |
| Team collaboration | ✅ Remote state | ⚠️ Git only | ⚠️ Git only |
| Secret management | ⚠️ External | ✅ Ansible Vault | ⚠️ .env files |

## 🎓 Learning Resources

### Terraform Documentation

- Official: <https://learn.hashicorp.com/terraform>
- Project: `terraform/README.md`

### Ansible Documentation

- Official: <https://docs.ansible.com/>
- Project: `ansible/README.md`

### Make Documentation

- GNU Make: <https://www.gnu.org/software/make/manual/>
- Project: Run `make help`

## 💡 Pro Tips

### Use All Three Together

```bash
# 1. Terraform: Provision infrastructure
terraform apply -var="environment=production"

# 2. Ansible: Configure applications
ansible-playbook ansible/deploy-production.yml

# 3. Make: Quick operations
make production-logs
```

### CI/CD Integration

```yaml
# GitLab CI example
deploy-staging:
  script:
    - terraform apply -var="environment=staging" -auto-approve
    
deploy-production:
  script:
    - ansible-playbook ansible/deploy-production.yml
```

### Development Workflow

1. **Develop locally**: Use `make staging`
2. **Test automation**: Use `ansible-playbook`
3. **Deploy infrastructure**: Use `terraform apply`

## 🆘 Getting Help

Each method has detailed documentation:

- **Terraform**: See `terraform/README.md`
- **Ansible**: See `ansible/README.md` (if exists) or playbook comments
- **Make**: Run `make help`

## 🎯 Summary

Choose based on your immediate need:

- **"I want to manage infrastructure as code"** → Terraform
- **"I want to automate deployment tasks"** → Ansible  
- **"I want quick manual control"** → Make/Scripts
- **"I want all of the above"** → Use all three! 🚀
