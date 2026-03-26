# Quick Reference: Deployment Methods

## One-Line Commands

### Make + kubectl (Default)

```bash
make deploy          # Full deployment
make destroy         # Full cleanup
make status          # Check status
```

### Ansible

```bash
make deploy-ansible   # Deploy with Ansible
make destroy-ansible  # Cleanup with Ansible
cd ansible && ansible-playbook deploy.yml -e "environment=production"
```

### Kustomize

```bash
make deploy-kustomize-prod      # Production
make deploy-kustomize-staging   # Staging
make kustomize-preview-prod     # Preview
kubectl apply -k kustomize/overlays/production   # Direct
```

## Common Operations

### Deploy

| Task        | Make                                     | Ansible                                         | Kustomize                                               |
| ----------- | ---------------------------------------- | ----------------------------------------------- | ------------------------------------------------------- |
| Full deploy | `make deploy`                            | `make deploy-ansible`                           | `make deploy-kustomize-prod`                            |
| Skip build  | `make apply`                             | `ansible-playbook deploy.yml --skip-tags build` | `kubectl apply -k overlays/production`                  |
| Dry run     | N/A                                      | `ansible-playbook deploy.yml --check`           | `kubectl apply -k overlays/production --dry-run=client` |
| Preview     | `kubectl get all -n api-deployment-demo` | `ansible-playbook deploy.yml --check --diff`    | `kubectl kustomize overlays/production`                 |

### Update

| Task            | Make                                  | Ansible                                     | Kustomize                              |
| --------------- | ------------------------------------- | ------------------------------------------- | -------------------------------------- |
| Update API      | `make restart`                        | `ansible-playbook deploy.yml --tags api`    | `kubectl apply -k overlays/production` |
| Update config   | `make config`                         | `ansible-playbook deploy.yml --tags config` | Edit overlay, `kubectl apply -k`       |
| Change replicas | `make scale COMPONENT=api REPLICAS=3` | Edit inventory, rerun                       | Edit overlay `replicas`, rerun         |

### Troubleshoot

| Task         | Make                                   | Ansible         | Kustomize                                |
| ------------ | -------------------------------------- | --------------- | ---------------------------------------- |
| Check logs   | `make logs-api`                        | `make logs-api` | `make logs-api`                          |
| Check status | `make status`                          | `make status`   | `kubectl get all -n api-deployment-demo` |
| Describe pod | `kubectl describe pod -l app=api-demo` | Same            | Same                                     |
| Events       | `make events`                          | `make events`   | `make events`                            |

### Cleanup

| Task          | Make             | Ansible                | Kustomize                               |
| ------------- | ---------------- | ---------------------- | --------------------------------------- |
| Remove deploy | `make destroy`   | `make destroy-ansible` | `make destroy-kustomize-prod`           |
| Keep cluster  | `make clean`     | `make clean`           | `kubectl delete -k overlays/production` |
| Full cleanup  | `make clean-all` | `make clean-all`       | `make clean-all`                        |

## Environment Management

### Make

```bash
ENV=staging make deploy
ENV=production make deploy
```

### Ansible

```bash
# Using variables
ansible-playbook deploy.yml -e "environment=staging"
ansible-playbook deploy.yml -e "environment=production"

# Using inventory
ansible-playbook deploy.yml -i inventory.ini -l staging
ansible-playbook deploy.yml -i inventory.ini -l production
```

### Kustomize

```bash
kubectl apply -k kustomize/overlays/staging
kubectl apply -k kustomize/overlays/production
```

## Secret Management

### Make

```bash
# Generate
./scripts/generate-secrets.sh production
./scripts/generate-tls-secrets.sh api-deployment-demo nginx-ssl-certs

# Apply
kubectl apply -f kubernetes/secrets.yaml
```

### Ansible

```bash
# Using Ansible Vault
ansible-vault create ansible/group_vars/production/vault.yml
ansible-vault edit ansible/group_vars/production/vault.yml

# Deploy with vault
ansible-playbook deploy.yml --ask-vault-pass
```

### Kustomize

```yaml
# In kustomization.yaml
secretGenerator:
  - name: db-credentials
    literals:
      - password=changeme

# Or use external tools
# - sealed-secrets
# - external-secrets-operator
# - sops
```

## Customization

### Make

```makefile
# Edit Makefile
deploy-custom:
 kubectl apply -f custom-manifest.yaml
 @$(MAKE) apply
```

### Ansible

```yaml
# Add to deploy.yml
- name: Custom task
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('file', 'custom.yaml') }}"
```

### Kustomize

```yaml
# In overlay kustomization.yaml
patchesStrategicMerge:
  - custom-patch.yaml

# custom-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 5
```

## CI/CD Integration

### GitHub Actions - Make

```yaml
- name: Deploy
  run: |
    make build
    make load-images
    make apply
```

### GitHub Actions - Ansible

```yaml
- name: Install Ansible
  run: pip install ansible

- name: Deploy
  run: |
    cd ansible
    ansible-playbook deploy.yml -e "environment=production"
```

### GitHub Actions - Kustomize

```yaml
- name: Deploy
  run: kubectl apply -k kustomize/overlays/production
```

### ArgoCD - Kustomize

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-demo
spec:
  source:
    path: kustomize/overlays/production
  syncPolicy:
    automated:
      prune: true
```

## Troubleshooting

### All Methods

```bash
# Check cluster
kubectl cluster-info
kubectl get nodes

# Check pods
kubectl get pods -A
kubectl get pods -n api-deployment-demo

# Check services
kubectl get svc -n api-deployment-demo

# Port forwarding (if NodePort not working)
kubectl port-forward -n api-deployment-demo svc/api-service 8000:8000
```

### Make-Specific

```bash
# Verbose output
make deploy V=1

# Check individual steps
make build
make load-images
make cluster
make apply
```

### Ansible-Specific

```bash
# Verbose output
ansible-playbook deploy.yml -vvv

# Check mode (dry run)
ansible-playbook deploy.yml --check

# Step through
ansible-playbook deploy.yml --step

# Specific tags
ansible-playbook deploy.yml --tags database,api --list-tasks
```

### Kustomize-Specific

```bash
# Validate
kubectl kustomize overlays/production > /tmp/output.yaml
kubectl apply --dry-run=client -f /tmp/output.yaml

# Diff
kubectl diff -k overlays/production

# Debug
kubectl kustomize overlays/production --enable-alpha-plugins
```

## Performance Comparison

| Method    | First Deploy | Update | Cleanup |
| --------- | ------------ | ------ | ------- |
| Make      | ~90s         | ~30s   | ~20s    |
| Ansible   | ~120s        | ~45s   | ~30s    |
| Kustomize | ~75s         | ~20s   | ~15s    |

## When to Use What

| Scenario                 | Recommended Method   |
| ------------------------ | -------------------- |
| Local development        | Make                 |
| Learning Kubernetes      | Make                 |
| Production deployment    | Ansible or Kustomize |
| Multiple environments    | Kustomize            |
| GitOps workflow          | Kustomize            |
| Complex automation       | Ansible              |
| Configuration management | Ansible              |
| Compliance/auditing      | Ansible              |
| Kubernetes-native        | Kustomize            |
| No external deps         | Kustomize            |

## Resources

- **Make**: [Makefile Documentation](https://www.gnu.org/software/make/manual/)
- **Ansible**: [Kubernetes Collection Docs](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/)
- **Kustomize**: [Official Documentation](https://kustomize.io/)
- **kubectl**: [Reference Documentation](https://kubernetes.io/docs/reference/kubectl/)

## See Also

- [DEPLOYMENT-COMPARISON.md](DEPLOYMENT-COMPARISON.md) - Detailed comparison
- [DEPLOYMENT-METHODS.md](DEPLOYMENT-METHODS.md) - Overview of methods
- [ansible/README.md](../ansible/README.md) - Ansible specifics
- [kustomize/README.md](../kustomize/README.md) - Kustomize specifics
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - General commands
