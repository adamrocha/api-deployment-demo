# Deployment Methods Comparison

This document compares three deployment methods available for the API Deployment Demo:

1. **Make + kubectl** (Default)
2. **Ansible**
3. **Kustomize**

## Quick Comparison Table

| Feature                      | Make + kubectl  | Ansible               | Kustomize        |
| ---------------------------- | --------------- | --------------------- | ---------------- |
| **Declarative**              | Partial         | Yes (with k8s module) | Fully            |
| **Learning Curve**           | Low             | Medium                | Medium           |
| **Multi-Environment**        | Manual          | Variables/Inventory   | Overlays         |
| **Version Control**          | Scripts + YAML  | Playbooks + YAML      | Pure YAML        |
| **CI/CD Friendly**           | Good            | Excellent             | Excellent        |
| **GitOps Support**           | Limited         | Moderate              | Native           |
| **Error Handling**           | Basic           | Advanced              | Basic            |
| **Wait/Retry Logic**         | Manual          | Built-in              | Limited          |
| **Configuration Management** | No              | Yes                   | No               |
| **Best For**                 | Quick local dev | Full automation       | GitOps workflows |

## 1. Make + kubectl (Default)

### Overview

Simple orchestration using Makefile targets that execute kubectl commands directly.

### Strengths

✅ **Simple** - Easy to understand and modify
✅ **Direct** - No abstraction, runs kubectl commands
✅ **Fast** - Minimal overhead
✅ **Transparent** - See exactly what runs
✅ **Debugging** - Easy to test individual commands

### Weaknesses

❌ **Limited Error Handling** - No built-in retry logic
❌ **No State Tracking** - Manual dependency management
❌ **Environment Management** - Lacks native multi-environment support
❌ **Imperative Style** - Sequential command execution

### Usage

```bash
# Deploy everything
make deploy

# Deploy infrastructure only
make apply

# Configure with Ansible (post-deployment)
make config

# Clean up
make destroy
```

### When to Use

- **Local development** workflows
- **Quick testing** and iteration
- **Learning** Kubernetes concepts
- **Simple deployments** without complex requirements
- When you need **maximum transparency**

### Example Workflow

```bash
# Build and load images
make build load-images

# Generate TLS
./scripts/generate-tls-secrets.sh

# Apply manifests sequentially
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/postgres-deployment.yaml
# ... etc
```

## 2. Ansible

### Overview

Uses Ansible playbooks with the `kubernetes.core` collection for declarative Kubernetes resource management.

### Strengths

✅ **Declarative + Imperative** - Best of both worlds
✅ **Advanced Error Handling** - Retries, conditions, error recovery
✅ **Wait Conditions** - Built-in readiness checks
✅ **Multi-Environment** - Inventory and variable support
✅ **Configuration Management** - Full Ansible ecosystem
✅ **Reporting** - Detailed status and change tracking
✅ **Integration** - Works with existing Ansible automation
✅ **Secrets Management** - Ansible Vault integration

### Weaknesses

❌ **Dependencies** - Requires Ansible + collections
❌ **Learning Curve** - Ansible knowledge needed
❌ **Verbosity** - More YAML than alternatives
❌ **Performance** - Slower than direct kubectl

### Usage

```bash
# Deploy with Ansible
make deploy-ansible

# Or directly
cd ansible
ansible-playbook deploy.yml -e "environment=production"

# Destroy with Ansible
make destroy-ansible

# Run with specific tags
ansible-playbook deploy.yml --tags database,api
```

### Project Structure

```
ansible/
├── deploy.yml           # Main deployment playbook
├── destroy.yml          # Cleanup playbook
├── kubernetes.yml       # Configuration playbook (existing)
└── inventory.ini        # Host/group definitions
```

### Key Features

**Pre-flight Checks:**

```yaml
- name: Check cluster connectivity
  kubernetes.core.k8s_cluster_info:
  register: cluster_info
  failed_when: cluster_info.failed
```

**Wait Conditions:**

```yaml
- name: Wait for database to be ready
  kubernetes.core.k8s:
    kind: Pod
    wait: yes
    wait_condition:
      type: Ready
      status: "True"
    wait_timeout: 120
```

**Error Recovery:**

```yaml
- name: Deploy with retry
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('file', 'manifest.yaml') }}"
  retries: 3
  delay: 10
```

### When to Use

- **Production deployments** requiring robust error handling
- **Multi-environment** setups (dev/staging/prod)
- Integration with **existing Ansible infrastructure**
- When you need **configuration management** (tuning, optimization)
- **Complex workflows** with dependencies
- When **secrets management** (Vault) is important
- **Compliance** requirements (audit logs, reporting)

### Best Practices

1. **Use Ansible Vault** for secrets
2. **Tag tasks** for selective execution
3. **Use variables** for environment-specific configs
4. **Implement proper wait conditions**
5. **Add retries** for flaky operations
6. **Use check mode** for dry runs

## 3. Kustomize

### Overview

Kubernetes-native tool for customizing YAML configurations using base + overlay pattern.

### Strengths

✅ **Pure Declarative** - Template-free YAML
✅ **Environment Variants** - Native overlay support
✅ **GitOps Ready** - Works seamlessly with ArgoCD/Flux
✅ **No Dependencies** - Built into kubectl
✅ **Composable** - Mix and match bases
✅ **Version Control Friendly** - All configuration in Git
✅ **Namespace Scoped** - Easy multi-tenant deployments
✅ **Strategic Merge** - Patch specific fields

### Weaknesses

❌ **Limited Logic** - No programming constructs
❌ **Learning Curve** - Patching syntax takes time
❌ **Debugging** - Harder to trace issues
❌ **No Wait Logic** - Manual readiness checks needed

### Usage

```bash
# Deploy production
make deploy-kustomize-prod

# Deploy staging
make deploy-kustomize-staging

# Preview what will be deployed
make kustomize-preview-prod

# Show diff
make kustomize-diff-prod

# Or use kubectl directly
kubectl apply -k kustomize/overlays/production
kubectl delete -k kustomize/overlays/production
```

### Project Structure

```
kustomize/
├── base/
│   └── kustomization.yaml       # Common base resources
└── overlays/
    ├── production/
    │   ├── kustomization.yaml   # Production customizations
    │   └── namespace.yaml       # Production namespace
    └── staging/
        ├── kustomization.yaml   # Staging customizations
        └── namespace.yaml       # Staging namespace
```

### Key Features

**Base Configuration:**

```yaml
# base/kustomization.yaml
resources:
  - ../../kubernetes/api-deployment.yaml
  - ../../kubernetes/api-service.yaml

images:
  - name: api-deployment-demo-api
    newTag: latest
```

**Production Overlay:**

```yaml
# overlays/production/kustomization.yaml
bases:
  - ../../base

commonLabels:
  environment: production

replicas:
  - name: api-deployment
    count: 3

patches:
  - target:
      kind: Deployment
      name: api-deployment
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "1Gi"
```

**Staging Overlay:**

```yaml
# overlays/staging/kustomization.yaml
bases:
  - ../../base

namespace: api-deployment-demo-staging
namePrefix: staging-

replicas:
  - name: api-deployment
    count: 1
```

### When to Use

- **GitOps workflows** with ArgoCD or Flux
- **Multi-environment** deployments (dev/staging/prod)
- **Kubernetes-native** teams
- When you want **no external dependencies**
- **Continuous delivery** pipelines
- **Multi-tenant** deployments (namespace per team)
- When **declarative everything** is a requirement

### GitOps Integration

**ArgoCD Application:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-demo-production
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/api-deployment-demo
    targetRevision: main
    path: kustomize/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: api-deployment-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Flux Kustomization:**

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: api-demo-production
spec:
  interval: 5m
  path: ./kustomize/overlays/production
  prune: true
  sourceRef:
    kind: GitRepository
    name: api-deployment-demo
```

### Best Practices

1. **Keep base minimal** - Only truly common resources
2. **Use strategic merge patches** - Avoid duplicating entire resources
3. **Version control everything** - Commit all kustomization.yaml
4. **Test overlays locally** - Use `kubectl kustomize` before applying
5. **Use namePrefix/nameSuffix** - For multi-instance deployments
6. **Document patches** - Add comments explaining why
7. **Validate before commit** - Use pre-commit hooks

## Detailed Comparison

### 1. Deployment Speed

| Method    | Build | Deploy | Total |
| --------- | ----- | ------ | ----- |
| Make      | 30s   | 60s    | 90s   |
| Ansible   | 30s   | 90s    | 120s  |
| Kustomize | 30s   | 45s    | 75s   |

_Note: Times are approximate for local Kind cluster_

### 2. Error Recovery

**Make:**

```bash
# Manual retry
kubectl apply -f api-deployment.yaml || \
  (sleep 10 && kubectl apply -f api-deployment.yaml)
```

**Ansible:**

```yaml
- name: Deploy API
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('file', 'api-deployment.yaml') }}"
  retries: 3
  delay: 10
  until: result is succeeded
```

**Kustomize:**

```bash
# No built-in retry, requires wrapper
while ! kubectl apply -k overlays/production; do
  sleep 10
done
```

### 3. Environment Management

**Make:**

```bash
# Manual environment selection
ENV=staging make deploy
# Requires custom logic in Makefile
```

**Ansible:**

```yaml
# ansible/inventory.ini
[production]
localhost ansible_connection=local

[production:vars]
environment=production
replicas=3
```

```bash
ansible-playbook deploy.yml -i inventory.ini -l production
```

**Kustomize:**

```
# Directory per environment
kustomize/overlays/production/
kustomize/overlays/staging/
```

```bash
kubectl apply -k kustomize/overlays/production
kubectl apply -k kustomize/overlays/staging
```

### 4. Secret Management

**Make:**

```bash
# External scripts
./scripts/generate-secrets.sh
kubectl apply -f secrets.yaml
```

**Ansible:**

```yaml
# Ansible Vault
- name: Deploy secrets
  kubernetes.core.k8s:
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: db-credentials
      data:
        password: "{{ db_password | b64encode }}"
  no_log: true
```

**Kustomize:**

```yaml
# Secret generator
secretGenerator:
  - name: db-credentials
    literals:
      - password=changeme
# Or use sealed-secrets, external-secrets
```

## Recommendations

### Use Make + kubectl for

- 🚀 **Local development**
- 📚 **Learning Kubernetes**
- 🔍 **Debugging deployment issues**
- ⚡ **Quick iterations**

### Use Ansible for

- 🏢 **Production environments**
- 🔄 **Complex workflows**
- 🔐 **Compliance requirements**
- 🎯 **Configuration management**
- 🤝 **Existing Ansible infrastructure**

### Use Kustomize for

- 🔄 **GitOps workflows**
- 🌍 **Multi-environment deployments**
- 🎨 **Kubernetes-native teams**
- 📦 **No external dependencies**
- 🔀 **Multi-tenant setups**

## Migration Paths

### From Make to Ansible

1. Keep existing Kubernetes manifests
2. Create `ansible/deploy.yml` playbook
3. Use `kubernetes.core.k8s` module
4. Add wait conditions and error handling
5. Test parallel: `make deploy` vs `make deploy-ansible`
6. Switch when confident

### From Make to Kustomize

1. Create `kustomize/base/kustomization.yaml`
2. Reference existing manifests
3. Create overlays for environments
4. Test: `kubectl kustomize overlays/production`
5. Apply: `kubectl apply -k overlays/production`
6. Migrate scripts to CI/CD

### From Ansible to Kustomize

1. Extract manifest definitions from playbooks
2. Create Kustomize base from manifests
3. Convert variables to patches in overlays
4. Replace `kubernetes.core.k8s` with `kubectl apply -k`
5. Move logic to CI/CD pipeline

## Hybrid Approaches

### Make + Kustomize

```makefile
deploy: build load-images
 kubectl apply -k kustomize/overlays/production
 $(MAKE) urls
```

### Ansible + Kustomize

```yaml
- name: Deploy with Kustomize
  command: kubectl apply -k {{ overlay_path }}
  args:
    chdir: "{{ playbook_dir }}/../kustomize"
```

### All Three

```makefile
# Default: kubectl
deploy: apply

# Alternative: Ansible
deploy-ansible: deploy-with-ansible

# Alternative: Kustomize
deploy-kustomize: deploy-kustomize-prod
```

## Conclusion

All three methods are valid and production-ready:

- **Make** is best for simplicity and local dev
- **Ansible** is best for complex automation and configuration management
- **Kustomize** is best for GitOps and declarative everything

Choose based on:

1. Team expertise
2. Existing infrastructure
3. Deployment complexity
4. Environment count
5. CI/CD tooling
6. GitOps requirements

**Pro tip:** Start with Make for development, graduate to Kustomize or Ansible for production.
