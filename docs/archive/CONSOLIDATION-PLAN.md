# Ansible & Kustomize Consolidation Plan

## Goal

Eliminate duplication between Ansible and Kustomize by establishing Kustomize as the single source of truth for Kubernetes resources, while using Ansible for orchestration and external dependencies.

## Current Duplication Matrix

| Resource/Setting       | Ansible Location                                           | Kustomize Location                          | Action                    |
| ---------------------- | ---------------------------------------------------------- | ------------------------------------------- | ------------------------- |
| API replicas           | `kubernetes-config/tasks/main.yml` (kubectl scale)         | `overlays/{env}/kustomization.yaml`         | **Keep in Kustomize**     |
| Resource limits        | `kubernetes-config/tasks/main.yml` (kubectl set)           | `overlays/{env}/kustomization.yaml` patches | **Keep in Kustomize**     |
| HPA settings           | `kubernetes-tuning/tasks/main.yml` (kubectl autoscale)     | `base/hpa.yaml`                             | **Keep in Kustomize**     |
| PodDisruptionBudget    | `kubernetes-tuning/tasks/main.yml` (kubectl apply heredoc) | **Missing**                                 | **Add to Kustomize base** |
| Environment vars       | `kubernetes-config/tasks/main.yml` (kubectl set env)       | `base/configmaps.yaml` + overlays           | **Keep in Kustomize**     |
| Monitoring annotations | `kubernetes-tuning/tasks/main.yml`                         | `base/*-deployment.yaml`                    | **Keep in Kustomize**     |

## Phase 1: Enhance Kustomize (Add Missing Resources)

### 1.1 Add PodDisruptionBudgets to Kustomize

Create `kustomize/base/pdb.yaml`:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
  namespace: api-deployment-demo
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: api-demo
      component: api
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-pdb
  namespace: api-deployment-demo
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: api-demo
      component: nginx
```

Add to `kustomize/base/kustomization.yaml`:

```yaml
resources:
  - pdb.yaml
```

### 1.2 Ensure Overlays Handle All Environment Differences

- Production overlay: Higher replicas, stricter PDB, more resources
- Staging overlay: Lower replicas, relaxed PDB, fewer resources

## Phase 2: Refactor Ansible to Orchestration-Only

### 2.1 Create New `deployment-orchestrator` Role

**Purpose:** High-level deployment workflow using Kustomize

File: `ansible/roles/deployment-orchestrator/tasks/main.yml`

```yaml
---
# Deployment orchestration using Kustomize
- name: Verify kubectl context
  command: kubectl config current-context
  register: current_context
  changed_when: false

- name: Display target context
  debug:
    msg: "Deploying to context: {{ current_context.stdout }}"

- name: Apply Kustomize manifests for {{ deployment_env }}
  command: kubectl apply -k kustomize/overlays/{{ deployment_env }}/
  environment:
    KUBECONFIG: "{{ kubeconfig_path | default('~/.kube/config') }}"

- name: Wait for deployments to be ready
  command: >
    kubectl wait --for=condition=available --timeout=300s
    deployment/{{ item }}
    -n {{ k8s_namespace }}
  loop:
    - api-deployment
    - nginx-deployment
    - postgres
  when: wait_for_ready | default(true)

- name: Verify deployment health
  command: kubectl get deployments -n {{ k8s_namespace }}
  register: deployment_status
  changed_when: false

- name: Display deployment status
  debug:
    var: deployment_status.stdout_lines
```

### 2.2 Keep Ansible for These Tasks

**`ssl-certificates` role:** (External, non-K8s)

- Generate SSL certificates
- Create Kubernetes secrets from generated certs

**`database` role:** (Application-level)

- Database migrations
- Initial seed data
- Backup/restore operations

**`monitoring` role:** (Post-deployment verification)

- Verify Prometheus scrape targets
- Check Grafana dashboard availability
- Send deployment notifications

### 2.3 Remove These Ansible Roles

- ❌ `kubernetes-config` → Replaced by Kustomize overlays
- ❌ `kubernetes-tuning` → Moved to Kustomize base resources

## Phase 3: Update Makefile for Single Deployment Path

Simplify to one primary deployment method:

```makefile
# Primary deployment using Kustomize + Ansible orchestration
deploy: build load-images
	@echo "🚀 Deploying with Kustomize ($(ENV) environment)..."
	ansible-playbook ansible/deploy.yml -e "deployment_env=$(ENV)"

# Legacy Terraform deployment (deprecated)
terraform-apply:
	@echo "⚠️  DEPRECATED: Use 'make deploy' instead"
	cd $(TF_DIR) && terraform apply $(TF_VARS)
```

## Phase 4: Update Documentation

### 4.1 Update README.md

- Document Kustomize as the authoritative source
- Explain Ansible's orchestration role
- Remove references to multiple deployment methods

### 4.2 Update MIGRATION-GUIDE.md

- Add section on Ansible → Kustomize consolidation
- Provide examples of common tasks in new structure

## Benefits of This Approach

1. **Single Source of Truth**: All K8s resources defined declaratively in Kustomize
2. **GitOps Ready**: Kustomize manifests can be directly applied by ArgoCD/Flux
3. **Environment Consistency**: Overlays ensure staging/production differences are explicit
4. **Reduced Complexity**: No imperative vs declarative conflicts
5. **Better Testing**: Can test `kubectl kustomize build` without cluster access
6. **Clear Separation**:
   - Kustomize = WHAT to deploy (resources)
   - Ansible = HOW to deploy (workflow, pre/post tasks)

## Migration Checklist

- [ ] Add PDB resources to Kustomize base
- [ ] Add monitoring annotations to deployment manifests
- [ ] Create `deployment-orchestrator` Ansible role
- [ ] Update `ansible/deploy.yml` to use new role
- [ ] Archive `kubernetes-config` and `kubernetes-tuning` roles
- [ ] Update all Makefile targets to use unified deployment
- [ ] Update documentation (README, MIGRATION-GUIDE)
- [ ] Test deployment in staging environment
- [ ] Deploy to production

## Rollback Plan

If issues arise, the old Ansible roles are still available. Simply:

```bash
git revert <consolidation-commit>
make deploy-ansible  # Use legacy method
```

## Timeline Estimate

- Phase 1 (Enhance Kustomize): 2-3 hours
- Phase 2 (Refactor Ansible): 3-4 hours
- Phase 3 (Makefile updates): 1 hour
- Phase 4 (Documentation): 2 hours
- **Total**: ~8-12 hours of work
