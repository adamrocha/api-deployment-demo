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

# =============================================================================
# Help
# =============================================================================

help: ## Show this help message
	@echo "🚀 API Deployment Demo - Available Commands"
	@echo "============================================"
	@echo ""
	@echo "📋 Quick Start:"
	@echo "  make quick-start          # Complete setup from scratch"
	@echo "  make production           # Deploy production (Terraform + Ansible)"
	@echo "  make status               # Check deployment status"
	@echo ""
	@echo "🔨 Build & Deploy:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  make clean                # Remove deployments (keep cluster)"
	@echo "  make clean-all            # Remove everything including cluster"

# =============================================================================
# Docker Images
# =============================================================================

docker-images: ## Build Docker images for API and Nginx
	@echo "🔨 Building Docker images..."
	@docker build -t api-deployment-demo-api:latest api/
	@docker build -t api-deployment-demo-nginx:latest nginx/
	@echo "✅ Images built successfully"

load-images: docker-images ## Load images into Kind cluster
	@echo "📤 Loading images into Kind cluster..."
	@kind load docker-image api-deployment-demo-api:latest --name $(CLUSTER_NAME)
	@kind load docker-image api-deployment-demo-nginx:latest --name $(CLUSTER_NAME)
	@echo "✅ Images loaded into cluster"

# =============================================================================
# Cluster Management
# =============================================================================

cluster-create: ## Create Kind Kubernetes cluster
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
	@echo ""
	@kubectl get nodes

# =============================================================================
# Terraform Infrastructure
# =============================================================================

tf-init: ## Initialize Terraform
	@echo "🔧 Initializing Terraform..."
	@cd terraform && terraform init

tf-plan: tf-init ## Plan infrastructure changes
	@echo "📋 Planning Terraform changes..."
	@cd terraform && terraform plan \
		-var="environment=$(ENV)" \
		-var="enable_monitoring=true"

tf-apply: tf-init cluster-create ## Apply Terraform infrastructure
	@echo "🚀 Deploying infrastructure with Terraform..."
	@cd terraform && terraform apply \
		-var="environment=$(ENV)" \
		-var="enable_monitoring=true" \
		-auto-approve
	@echo "✅ Infrastructure deployed"

tf-destroy: ## Destroy Terraform infrastructure
	@echo "🗑️  Destroying infrastructure..."
	@cd terraform && terraform destroy \
		-var="environment=$(ENV)" \
		-auto-approve
	@echo "✅ Infrastructure destroyed"

tf-output: ## Show Terraform outputs
	@echo "📊 Terraform Outputs"
	@echo "===================="
	@echo ""
	@cd terraform && terraform output -json | jq -r '"🏗️  Infrastructure:", "  Cluster:     " + .cluster_name.value, "  Environment: " + .environment.value, "  Namespace:   " + .namespace.value, "", "🐳 Docker Images:", "  API:   " + .docker_images.value.api, "  Nginx: " + .docker_images.value.nginx, "", "🌐 Production URLs:", "  Web (HTTP):       " + .production_urls.value.web, "  Web (HTTPS):      " + .production_urls.value.web_https, "  API Direct:       " + .production_urls.value.api, "  API via Nginx:    " + .production_urls.value.api_via_nginx, "  API Docs:         " + .production_urls.value.api_docs, "", "📊 Monitoring:", "  Prometheus: " + .production_urls.value.prometheus, "  Grafana:    " + .production_urls.value.grafana'

tf-clean: ## Clean Terraform state files
	@echo "🧹 Cleaning Terraform state..."
	@rm -rf terraform/.terraform terraform/.terraform.lock.hcl
	@rm -f terraform/terraform.tfstate terraform/terraform.tfstate.backup
	@echo "✅ Terraform state cleaned"

# =============================================================================
# Ansible Configuration Management
# =============================================================================

ansible-config: ## Configure Kubernetes resources with Ansible
	@echo "🔧 Configuring Kubernetes with Ansible..."
	@cd ansible && ansible-playbook kubernetes.yml \
		-e "environment=$(ENV)" \
		--tags config
	@echo "✅ Configuration applied"

ansible-tune: ## Tune and optimize deployments
	@echo "⚡ Optimizing deployments with Ansible..."
	@cd ansible && ansible-playbook kubernetes.yml \
		-e "environment=$(ENV)" \
		--tags tuning
	@echo "✅ Optimization complete"

ansible-all: ## Run all Ansible playbooks
	@echo "🚀 Running complete Ansible configuration..."
	@cd ansible && ansible-playbook kubernetes.yml \
		-e "environment=$(ENV)"
	@echo "✅ Ansible configuration complete"

ansible-validate: ## Validate Ansible configuration
	@cd ansible && ./validate-ansible.sh

# =============================================================================
# Integrated Deployment Workflows
# =============================================================================

production: docker-images tf-apply ansible-config ## Deploy production environment (full workflow)
	@echo ""
	@echo "✅ Production deployment complete!"
	@$(MAKE) show-urls

staging: ## Deploy staging environment (Docker Compose)
	@echo "🐳 Starting staging with Docker Compose..."
	@docker compose up -d
	@echo "✅ Staging started"
	@echo ""
	@echo "🌐 Staging URLs:"
	@echo "  HTTPS: https://localhost:30443"
	@echo "  API:   http://localhost:30800"

quick-start: production ## Complete setup from scratch
	@echo "🎉 Environment ready!"

# =============================================================================
# Monitoring & Observability
# =============================================================================

monitoring-forward: ## Start port forwarding for monitoring
	@echo "🚀 Starting port forwarding..."
	@pkill -f "kubectl.*port-forward.*monitoring" 2>/dev/null || true
	@sleep 1
	@kubectl port-forward -n monitoring svc/grafana 3000:3000 > /dev/null 2>&1 &
	@kubectl port-forward -n monitoring svc/prometheus 9090:9090 > /dev/null 2>&1 &
	@echo "✅ Port forwarding active"
	@echo "  Grafana:    http://localhost:3000"
	@echo "  Prometheus: http://localhost:9090"

monitoring-stop: ## Stop port forwarding
	@pkill -f "kubectl.*port-forward.*monitoring" 2>/dev/null || true
	@echo "✅ Port forwarding stopped"

logs-api: ## Show API logs (follow mode)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo -l '!component' --tail=50 -f

logs-api-once: ## Show API logs (no follow)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo -l '!component' --tail=50

logs-nginx: ## Show Nginx logs (follow mode)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo,component=nginx --tail=50 -f

logs-nginx-once: ## Show Nginx logs (no follow)
	@kubectl logs -n $(NAMESPACE) -l app=api-demo,component=nginx --tail=50

logs-monitoring: ## Show monitoring logs
	@echo "📊 Grafana logs:"
	@kubectl logs -n monitoring -l app=grafana --tail=20
	@echo ""
	@echo "📊 Prometheus logs:"
	@kubectl logs -n monitoring -l app=prometheus --tail=20

# =============================================================================
# Status & Health Checks
# =============================================================================

status: ## Show deployment status
	@echo "📊 Deployment Status"
	@echo "===================="
	@echo ""
	@if kind get clusters 2>/dev/null | grep -q $(CLUSTER_NAME); then \
		echo "🏗️  Cluster: ✅ Running"; \
		echo ""; \
		echo "📦 Application Pods:"; \
		kubectl get pods -n $(NAMESPACE) 2>/dev/null || echo "  No pods found"; \
		echo ""; \
		echo "📊 Monitoring Pods:"; \
		kubectl get pods -n monitoring 2>/dev/null || echo "  No pods found"; \
		echo ""; \
		echo "🌐 Services:"; \
		kubectl get svc -n $(NAMESPACE) 2>/dev/null || echo "  No services found"; \
	else \
		echo "❌ Cluster not running"; \
	fi

health: ## Check application health
	@echo "🏥 Health Checks"
	@echo "================"
	@echo ""
	@printf "API Health:     "
	@if curl -sf http://localhost:8000/health >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ Not responding"; fi
	@printf "Web Frontend:   "
	@if curl -sfk https://localhost:443 >/dev/null 2>&1; then echo "✅ OK"; else echo "❌ Not responding"; fi
	@printf "Grafana:        "
	@if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then echo "✅ OK"; else echo "⚠️  Not forwarded (run: make monitoring-forward)"; fi
	@printf "Prometheus:     "
	@if curl -sf http://localhost:9090/-/healthy >/dev/null 2>&1; then echo "✅ OK"; else echo "⚠️  Not forwarded (run: make monitoring-forward)"; fi

show-urls: ## Display access URLs
	@echo ""
	@echo "🌐 Access URLs"
	@echo "=============="
	@echo "Production:"
	@echo "  Web:        https://localhost (or http://localhost)"
	@echo "  API:        http://localhost:8000"
	@echo "  API Health: http://localhost:8000/health"
	@echo "  API Docs:   http://localhost:8000/docs"
	@echo ""
	@echo "Monitoring (requires port-forward):"
	@echo "  Grafana:    http://localhost:3000 (admin/admin)"
	@echo "  Prometheus: http://localhost:9090"
	@echo ""
	@echo "💡 Run 'make monitoring-forward' to enable monitoring access"

# =============================================================================
# Testing & Validation
# =============================================================================

test: ## Run all tests
	@echo "🧪 Running tests..."
	@./scripts/test-automated-deployment.sh

test-load: ## Run load test
	@echo "🚦 Running load test..."
	@./scripts/load-test.sh

test-traffic: ## Generate test traffic
	@echo "🚦 Generating traffic..."
	@./scripts/generate-traffic.sh

validate: ## Validate all configurations
	@echo "✅ Validating configurations..."
	@docker compose config >/dev/null && echo "✅ Docker Compose valid"
	@cd ansible && ./validate-ansible.sh
	@for script in scripts/*.sh; do bash -n "$$script" && echo "✅ $$script valid"; done

# =============================================================================
# Secrets Management
# =============================================================================

secrets-generate: ## Generate Kubernetes secrets
	@echo "🔐 Generating secrets..."
	@./scripts/generate-secrets.sh $(ENV)

secrets-apply: ## Apply secrets to cluster
	@echo "🔐 Applying secrets..."
	@APPLY=true ./scripts/generate-secrets.sh $(ENV)

secrets-tls: ## Generate TLS secrets
	@./scripts/generate-tls-secrets.sh $(NAMESPACE) nginx-ssl-certs

# =============================================================================
# Cleanup
# =============================================================================

clean: ## Clean deployments (keep cluster and images)
	@echo "🧹 Cleaning deployments..."
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@kubectl delete namespace monitoring --ignore-not-found=true
	@$(MAKE) monitoring-stop
	@echo "✅ Deployments cleaned"

clean-staging: ## Clean staging environment
	@echo "🧹 Cleaning staging..."
	@docker compose down -v
	@echo "✅ Staging cleaned"

clean-all: ## Nuclear cleanup - remove everything
	@echo "💥 Complete cleanup..."
	@echo "⚠️  This will remove:"
	@echo "   • All deployments and namespaces"
	@echo "   • Kind cluster"
	@echo "   • Docker images"
	@echo "   • Terraform state"
	@echo ""
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo ""
	@echo "🧹 Stopping services..."
	@docker compose down -v 2>/dev/null || true
	@$(MAKE) monitoring-stop
	@echo "🗑️  Deleting cluster..."
	@kind delete cluster --name $(CLUSTER_NAME) 2>/dev/null || true
	@echo "🐳 Removing Docker images..."
	@docker images --format "{{.Repository}}:{{.Tag}}" | grep "^api-deployment-demo" | xargs -r docker rmi -f 2>/dev/null || true
	@echo "🗑️  Removing dangling images..."
	@docker image prune -f 2>/dev/null || true
	@$(MAKE) tf-clean
	@pkill -f "kubectl.*port-forward" 2>/dev/null || true
	@echo "✅ Complete cleanup finished"

# =============================================================================
# Development Shortcuts
# =============================================================================

dev: staging ## Start development environment
	@echo "✅ Development environment ready"

restart: ## Restart all deployments
	@echo "🔄 Restarting deployments..."
	@kubectl rollout restart deployment -n $(NAMESPACE)
	@kubectl rollout restart deployment -n monitoring
	@echo "✅ Restarts initiated"

scale-api: ## Scale API deployment (REPLICAS=3)
	@kubectl scale deployment/api-deployment -n $(NAMESPACE) --replicas=$(or $(REPLICAS),3)
	@echo "✅ API scaled to $(or $(REPLICAS),3) replicas"

scale-nginx: ## Scale Nginx deployment (REPLICAS=2)
	@kubectl scale deployment/nginx-deployment -n $(NAMESPACE) --replicas=$(or $(REPLICAS),2)
	@echo "✅ Nginx scaled to $(or $(REPLICAS),2) replicas"

pods: ## List all pods
	@kubectl get pods -A

events: ## Show recent cluster events
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20

describe-api: ## Describe API deployment
	@kubectl describe deployment api-deployment -n $(NAMESPACE)

describe-nginx: ## Describe Nginx deployment
	@kubectl describe deployment nginx-deployment -n $(NAMESPACE)

# =============================================================================
# CI/CD Workflows
# =============================================================================

ci-build: docker-images ## CI: Build images
	@echo "✅ Build complete"

ci-deploy: production ## CI: Deploy to production
	@echo "✅ Deployment complete"

ci-test: test ## CI: Run tests
	@echo "✅ Tests complete"

ci-pipeline: ci-build ci-test ci-deploy ## CI: Full pipeline
	@echo "✅ CI/CD pipeline complete"
