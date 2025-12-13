# API Deployment Demo Makefile
# Terraform-driven Infrastructure as Code with Ansible Configuration Management

.PHONY: help
.DEFAULT_GOAL := help

# =============================================================================
# Configuration
# =============================================================================

ENV ?= production
CLUSTER_NAME := api-demo-cluster
NAMESPACE := api-deployment-demo
MONITORING_NS := monitoring
TF_DIR := terraform
ANSIBLE_DIR := ansible

# Port settings
GRAFANA_PORT := 3000
PROMETHEUS_PORT := 9090
API_PORT := 8000

# Image settings
API_IMAGE := api-deployment-demo-api:latest
NGINX_IMAGE := api-deployment-demo-nginx:latest
IMAGES := $(API_IMAGE) $(NGINX_IMAGE)

# Terraform variables
TF_VARS := -var="environment=$(ENV)" -var="enable_monitoring=true"

# =============================================================================
# Help
# =============================================================================

help: ## Show this help message
	@echo "🚀 API Deployment Demo - Available Commands"
	@echo "============================================"
	@echo ""
	@echo "📋 Quick Start:"
	@echo "  make deploy               # Full deployment (build + terraform + config)"
	@echo "  make status               # Check deployment status"
	@echo "  make urls                 # Show access URLs"
	@echo ""
	@echo "🔨 Build & Infrastructure:"
	@echo "  make build                # Build Docker images"
	@echo "  make cluster              # Create Kind cluster"
	@echo "  make apply                # Deploy with Terraform"
	@echo "  make config               # Apply Ansible configuration"
	@echo ""
	@echo "📊 Monitoring & Logs:"
	@echo "  make logs                 # Show all logs"
	@echo "  make logs-api             # Show API logs (follow)"
	@echo "  make health               # Check health"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  make test                 # Run tests"
	@echo "  make test-traffic         # Generate traffic"
	@echo "  make validate             # Validate configs"
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  make clean                # Remove deployments"
	@echo "  make clean-all            # Nuclear cleanup"
	@echo ""
	@echo "💡 More commands: make help-all"

help-all: ## Show all available commands
	@echo "🚀 API Deployment Demo - All Commands"
	@echo "======================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Docker Images
# =============================================================================

build: ## Build Docker images for API and Nginx
	@echo "🔨 Building Docker images..."
	@docker build -t $(API_IMAGE) api/
	@docker build -t $(NGINX_IMAGE) nginx/
	@echo "✅ Images built successfully"

load-images: build ## Load images into Kind cluster
	@echo "📤 Loading images into Kind cluster..."
	@for img in $(IMAGES); do kind load docker-image $$img --name $(CLUSTER_NAME); done
	@echo "✅ Images loaded into cluster"

# =============================================================================
# Cluster Management
# =============================================================================

cluster: ## Create Kind Kubernetes cluster
	@echo "🏗️  Creating Kind cluster..."
	@if kind get clusters 2>/dev/null | grep -q $(CLUSTER_NAME); then \
		echo "✅ Cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml; \
		echo "✅ Cluster created successfully"; \
	fi

cluster-delete: ## Delete Kind cluster
	@echo "🗑️  Deleting Kind cluster..."
	@kind delete cluster --name $(CLUSTER_NAME)
	@echo "✅ Cluster deleted"

cluster-info: ## Show cluster information
	@kubectl cluster-info --context kind-$(CLUSTER_NAME)
	@kubectl get nodes

# =============================================================================
# Terraform Infrastructure
# =============================================================================

init: ## Initialize Terraform
	@echo "🔧 Initializing Terraform..."
	@cd $(TF_DIR) && terraform init

plan: init ## Plan infrastructure changes
	@echo "📋 Planning Terraform changes..."
	@cd $(TF_DIR) && terraform plan $(TF_VARS)

apply: init cluster ## Apply Terraform infrastructure
	@echo "🚀 Deploying infrastructure with Terraform..."
	@cd $(TF_DIR) && terraform apply $(TF_VARS) -auto-approve
	@echo "✅ Infrastructure deployed"

destroy: ## Destroy Terraform infrastructure
	@echo "🗑️  Destroying infrastructure..."
	@docker compose down -v 2>/dev/null || true
	@kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true
	@echo "🧹 Cleaning up Terraform state..."
	@cd $(TF_DIR) && rm -rf .terraform.lock.hcl .terraform/ terraform.tfstate terraform.tfstate.backup 2>/dev/null || true
	@echo "✅ Infrastructure destroyed"

output: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output -json | jq -r '"🏗️  Cluster: " + .cluster_name.value, "🌐 Environment: " + .environment.value, "📦 Namespace: " + .namespace.value, "", "🌐 URLs:", "  Web:       https://localhost", "  API:       http://localhost:$(API_PORT)", "  Docs:      http://localhost:$(API_PORT)/docs", "  Grafana:   http://localhost:$(GRAFANA_PORT) (admin/admin)", "  Prometheus: http://localhost:$(PROMETHEUS_PORT)"'

# =============================================================================
# Ansible Configuration Management
# =============================================================================

config: ## Configure Kubernetes resources with Ansible
	@echo "🔧 Configuring with Ansible..."
	@cd $(ANSIBLE_DIR) && ansible-playbook kubernetes.yml -e "environment=$(ENV)" --tags config

tune: ## Tune and optimize deployments
	@echo "⚡ Optimizing with Ansible..."
	@cd $(ANSIBLE_DIR) && ansible-playbook kubernetes.yml -e "environment=$(ENV)" --tags tuning

ansible: ## Run all Ansible playbooks
	@echo "🚀 Running Ansible configuration..."
	@cd $(ANSIBLE_DIR) && ansible-playbook kubernetes.yml -e "environment=$(ENV)"

validate-ansible: ## Validate Ansible configuration
	@cd $(ANSIBLE_DIR) && ./validate-ansible.sh

# =============================================================================
# Deployment Workflows
# =============================================================================

deploy: build apply config ## Full production deployment
	@$(MAKE) urls

production: deploy ## Alias for deploy

staging: ## Deploy staging environment (Docker Compose)
	@echo "🐳 Starting staging with Docker Compose..."
	@docker compose up -d
	@echo "✅ Staging URLs:"
	@echo "  HTTPS: https://localhost:30443"
	@echo "  API:   http://localhost:30800"

quick-start: deploy ## Complete setup from scratch

# =============================================================================
# Monitoring & Observability
# =============================================================================

logs: ## Show all application logs
	@kubectl logs -n $(NAMESPACE) -l app=api-demo --tail=50 --all-containers=true

logs-api: ## Show API logs (follow)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo,component=api --tail=50 -f

logs-nginx: ## Show Nginx logs (follow)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo,component=nginx --tail=50 -f

logs-grafana: ## Show Grafana logs
	@kubectl logs -n $(MONITORING_NS) -l app=grafana --tail=50

logs-prometheus: ## Show Prometheus logs
	@kubectl logs -n $(MONITORING_NS) -l app=prometheus --tail=50

# =============================================================================
# Status & Health Checks
# =============================================================================

status: ## Show deployment status
	@echo "📊 Deployment Status"
	@echo "===================="
	@if kind get clusters 2>/dev/null | grep -q $(CLUSTER_NAME); then \
		echo "🏗️  Cluster: ✅ Running"; \
		echo ""; \
		echo "📦 Pods:"; \
		kubectl get pods -n $(NAMESPACE) -n $(MONITORING_NS) 2>/dev/null || echo "  No pods found"; \
		echo ""; \
		echo "🌐 Services:"; \
		kubectl get svc -n $(NAMESPACE) 2>/dev/null || echo "  No services found"; \
	else \
		echo "❌ Cluster not running"; \
	fi

health: ## Check application health
	@printf "API:        "; curl -sf http://localhost:$(API_PORT)/health >/dev/null 2>&1 && echo "✅" || echo "❌"
	@printf "Web:        "; curl -sfk https://localhost >/dev/null 2>&1 && echo "✅" || echo "❌"
	@printf "Grafana:    "; curl -sf http://localhost:$(GRAFANA_PORT)/api/health >/dev/null 2>&1 && echo "✅" || echo "❌"
	@printf "Prometheus: "; curl -sf http://localhost:$(PROMETHEUS_PORT)/-/healthy >/dev/null 2>&1 && echo "✅" || echo "❌"

urls: ## Display access URLs
	@echo "🌐 Access URLs"
	@echo "=============="
	@echo "  Web:        https://localhost"
	@echo "  API:        http://localhost:$(API_PORT)"
	@echo "  API Docs:   http://localhost:$(API_PORT)/docs"
	@echo "  Grafana:    http://localhost:$(GRAFANA_PORT) (admin/admin)"
	@echo "  Prometheus: http://localhost:$(PROMETHEUS_PORT)"

# =============================================================================
# Testing & Validation
# =============================================================================

test: ## Run deployment tests
	@./scripts/test-automated-deployment.sh

test-load: ## Run load test
	@./scripts/load-test.sh

test-traffic: ## Generate test traffic
	@./scripts/generate-traffic.sh

validate: ## Validate all configurations
	@echo "✅ Validating..."
	@docker compose config >/dev/null && echo "  ✅ Docker Compose"
	@cd $(ANSIBLE_DIR) && ./validate-ansible.sh
	@for script in scripts/*.sh; do bash -n "$$script" 2>/dev/null && echo "  ✅ $$script"; done

# =============================================================================
# Secrets Management
# =============================================================================

secrets: ## Generate and apply secrets
	@APPLY=true ./scripts/generate-secrets.sh $(ENV)

secrets-tls: ## Generate TLS secrets
	@./scripts/generate-tls-secrets.sh $(NAMESPACE) nginx-ssl-certs

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean deployments (keep cluster and images)
	@echo "🧹 Cleaning deployments..."
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@kubectl delete namespace $(MONITORING_NS) --ignore-not-found=true
	@echo "✅ Deployments cleaned"

clean-staging: ## Clean staging environment
	@docker compose down -v

clean-tf: ## Clean Terraform state files
	@echo "🧹 Cleaning Terraform state..."
	@rm -rf $(TF_DIR)/.terraform $(TF_DIR)/.terraform.lock.hcl
	@rm -f $(TF_DIR)/terraform.tfstate $(TF_DIR)/terraform.tfstate.backup

clean-all: ## Complete cleanup - remove everything
	@echo "💥 Complete cleanup..."
	@echo "⚠️  This removes: deployments, cluster, images, terraform state"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose down -v 2>/dev/null || true
	@kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true
	@docker images "api-deployment-demo*" -q | xargs -r docker rmi -f 2>/dev/null || true
	@docker rmi -f postgres:15-alpine prometheuscommunity/postgres-exporter:latest nginx/nginx-prometheus-exporter:latest 2>/dev/null || true
	@docker image prune -f >/dev/null 2>&1
	@$(MAKE) clean-tf
	@echo "✅ Complete cleanup finished"

# =============================================================================
# Development & Operations
# =============================================================================

restart: ## Restart all deployments
	@kubectl rollout restart deployment -n $(NAMESPACE) -n $(MONITORING_NS)

scale: ## Scale deployments (COMPONENT=api|nginx REPLICAS=3)
	@kubectl scale deployment/$(COMPONENT)-deployment -n $(NAMESPACE) --replicas=$(REPLICAS)

pods: ## List all pods
	@kubectl get pods -A

events: ## Show recent cluster events
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

describe: ## Describe deployment (COMPONENT=api|nginx)
	@kubectl describe deployment $(COMPONENT)-deployment -n $(NAMESPACE)

shell: ## Open shell in pod (COMPONENT=api|nginx)
	@kubectl exec -it -n $(NAMESPACE) deployment/$(COMPONENT)-deployment -- sh
