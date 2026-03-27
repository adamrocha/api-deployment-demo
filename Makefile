# API Deployment Demo Makefile
# Kubernetes Manifest-driven Infrastructure with Ansible Configuration Management

.PHONY: help
.DEFAULT_GOAL := help

# =============================================================================
# Configuration
# =============================================================================

ENV ?= production
CLUSTER_NAME := api-demo-cluster
NAMESPACE := api-deployment-demo-ns
MONITORING_NS := api-deployment-demo-ns
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

# Component settings
COMPONENT ?= api

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
	@echo "  make deploy               # Deploy with Kustomize + Ansible"
	@echo "  make deploy ENV=staging   # Deploy to staging"
	@echo "  make status               # Check deployment status"
	@echo "  make urls                 # Show access URLs"
	@echo "  make destroy              # Remove deployment"
	@echo ""
	@echo "🔨 Build & Infrastructure:"
	@echo "  make build                # Build Docker images"
	@echo "  make cluster              # Create Kind cluster"
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
	@echo "  make clean-all            # Complete cleanup"
	@echo ""
	@echo "💡 More: make help-all"

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
# Primary Deployment Method (Kustomize + Ansible)
# =============================================================================

deploy: build load-images install-collections ## Deploy with Kustomize + Ansible orchestration
	@echo "🚀 Deploying API Demo (Environment: $(ENV))"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@cd $(ANSIBLE_DIR) && ansible-playbook deploy.yml -e "deployment_env=$(ENV)"
	@echo "✅ Deployment complete!"
	@$(MAKE) urls

# =============================================================================
# Ansible Support
# =============================================================================

install-collections: ## Install required Ansible collections
	@echo "📦 Installing Ansible collections..."
	@cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml --force

# =============================================================================
# Deployment Cleanup
# =============================================================================

destroy: install-collections ## Destroy deployment using Ansible
	@echo "🗑️  Destroying with Ansible..."
	@cd $(ANSIBLE_DIR) && ansible-playbook destroy.yml
	@echo "✅ Deployment destroyed"

# =============================================================================
# Kustomize Utilities
# =============================================================================

kustomize-preview: ## Preview Kustomize output for current environment
	@echo "👀 Previewing Kustomize $(ENV) overlay..."
	@kubectl kustomize kustomize/overlays/$(ENV)

kustomize-diff: ## Show diff for current environment
	@echo "🔍 Checking diff for $(ENV) environment..."
	@kubectl diff -k kustomize/overlays/$(ENV) || true

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
		echo "📦 Application Pods:"; \
		kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "  No pods found"; \
		echo ""; \
		echo "📊 Monitoring Pods:"; \
		kubectl get pods -n $(MONITORING_NS) 2>/dev/null || echo "  No pods found"; \
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
	@echo "  API:        https://localhost:8000"
	@echo "  API Docs:   https://localhost:8000/docs"
	@echo "  Grafana:    https://localhost:3000"
	@echo "  Prometheus: https://localhost:9090"

# =============================================================================
# Testing & Validation
# =============================================================================

test: ## Run deployment tests
	@./scripts/test-automated-deployment.sh

test-load: ## Run load test
	@./scripts/load-test.sh

test-traffic: ## Generate test traffic
	@./scripts/generate-traffic.sh

verify-metrics: ## Verify metrics server and HPA status
	@./scripts/verify-metrics.sh

validate: ## Validate all configurations
	@echo "✅ Validating..."
	@docker compose config >/dev/null && echo "  ✅ Docker Compose"
	@kubectl kustomize kustomize/overlays/production >/dev/null && echo "  ✅ Kustomize production" || echo "  ❌ Kustomize production"
	@kubectl kustomize kustomize/overlays/staging >/dev/null && echo "  ✅ Kustomize staging" || echo "  ❌ Kustomize staging"
	@cd $(ANSIBLE_DIR) && ansible-playbook deploy.yml --syntax-check && echo "  ✅ Ansible deploy.yml"
	@for script in scripts/*.sh; do bash -n "$$script" 2>/dev/null && echo "  ✅ $$script"; done

# =============================================================================
# Secrets Management
# =============================================================================

secrets: ## Generate and apply secrets
	@APPLY=true ./scripts/generate-secrets.sh $(ENV)

secrets-tls: ## Generate TLS secrets
	@./scripts/generate-tls-secrets.sh $(NAMESPACE) nginx-ssl-certs

get-secrets: ## Display all passwords and credentials
	@./scripts/get-passwords.sh

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

clean-all: ## Complete cleanup - remove everything
	@echo "💥 Complete cleanup..."
	@echo "⚠️  This removes: deployments, cluster, and images"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose down -v 2>/dev/null || true
	@kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true
	@docker images "api-deployment-demo*" -q | xargs -r docker rmi -f 2>/dev/null || true
	@docker rmi -f postgres:15-alpine prometheuscommunity/postgres-exporter:latest nginx/nginx-prometheus-exporter:latest 2>/dev/null || true
	@docker image prune -f >/dev/null 2>&1
	@echo "✅ Complete cleanup finished"

# =============================================================================
# Development & Operations
# =============================================================================

restart: ## Restart all deployments
	@echo "🔄 Restarting deployments..."
	@kubectl rollout restart deployment -n $(NAMESPACE)
	@kubectl rollout restart deployment -n $(MONITORING_NS)
	@echo "✅ All deployments restarted"

scale: ## Scale deployments (usage: make scale COMPONENT=api REPLICAS=3)
	@if [ -z "$(REPLICAS)" ]; then \
		echo "❌ REPLICAS parameter is required"; \
		echo "Usage: make scale COMPONENT=<component-name> REPLICAS=<number>"; \
		exit 1; \
	fi
	@echo "⚖️  Scaling $(COMPONENT) deployment to $(REPLICAS) replicas..."
	@if kubectl get deployment $(COMPONENT)-deployment -n $(NAMESPACE) > /dev/null 2>&1; then \
		kubectl scale deployment/$(COMPONENT)-deployment -n $(NAMESPACE) --replicas=$(REPLICAS); \
	else \
		echo "❌ Deployment $(COMPONENT)-deployment not found in namespace $(NAMESPACE)"; \
		echo "Available deployments:"; \
		kubectl get deployments -n $(NAMESPACE) --no-headers | awk '{print "  - " $$1}'; \
		echo "Usage: make scale COMPONENT=<component-name> REPLICAS=<number>"; \
	fi

pods: ## List all pods
	@kubectl get pods -A

events: ## Show last 20 cluster events (one-time)
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

watch-events: ## Watch cluster events continuously (Ctrl+C to exit)
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' -w

describe: ## Describe deployment (usage: make describe COMPONENT=api)
	@echo "📋 Describing $(COMPONENT) deployment..."
	@if kubectl get deployment $(COMPONENT)-deployment -n $(NAMESPACE) > /dev/null 2>&1; then \
		kubectl describe deployment $(COMPONENT)-deployment -n $(NAMESPACE); \
	else \
		echo "❌ Deployment $(COMPONENT)-deployment not found in namespace $(NAMESPACE)"; \
		echo "Available deployments:"; \
		kubectl get deployments -n $(NAMESPACE) --no-headers | awk '{print "  - " $$1}'; \
		echo "Usage: make describe COMPONENT=<component-name>"; \
	fi

shell: ## Open shell in pod (usage: make shell COMPONENT=api)
	@echo "🐚 Opening shell in $(COMPONENT) pod..."
	@if kubectl get deployment $(COMPONENT)-deployment -n $(NAMESPACE) > /dev/null 2>&1; then \
		kubectl exec -it -n $(NAMESPACE) deployment/$(COMPONENT)-deployment -- sh; \
	else \
		echo "❌ Deployment $(COMPONENT)-deployment not found in namespace $(NAMESPACE)"; \
		echo "Available deployments:"; \
		kubectl get deployments -n $(NAMESPACE) --no-headers | awk '{print "  - " $$1}'; \
		echo "Usage: make shell COMPONENT=<component-name>"; \
	fi
