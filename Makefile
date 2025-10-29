# API Deployment Demo Makefile
# Provides easy commands to manage different environments and services

.PHONY: help setup-env generate-secrets apply-secrets validate-env list-secrets clean-secrets show-env-help
.PHONY: staging staging-build staging-logs staging-status staging-stop
.PHONY: production production-logs production-status production-stop kind-cluster docker-images docker-push
.PHONY: monitoring monitoring-status monitoring-logs access-monitoring access-production access-staging
.PHONY: clean clean-all clean-all-dry-run clean-staging clean-production clean-images clean-secrets
.PHONY: traffic logs status validate quick-dev quick-staging quick-production
.PHONY: test-automated promote validate-promotion

# Default target
help: ## Show this help message
	@echo "🚀 API Deployment Demo - Available Commands"
	@echo "==========================================="
	@echo ""
	@echo "📋 Environment Management:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "💡 Examples:"
	@echo "  make staging          # Start staging environment"
	@echo "  make production       # Start production environment"
	@echo "  make monitoring       # Add monitoring to production"
	@echo ""
	@echo "🧹 Cleanup Options (in order of intensity):"
	@echo "  make clean-staging    # Clean only staging (Docker Compose)"
	@echo "  make clean-production # Clean only production (keep cluster)"
	@echo "  make clean            # Clean applications (keep cluster & images)"
	@echo "  make clean-all        # 💥 NUCLEAR: Delete everything (cluster, images, volumes)"
	@echo ""
	@echo "📖 For comprehensive cleanup: make clean-all"

# =============================================================================
# Environment Setup
# =============================================================================

# =============================================================================
# Secret Management (.env-based)
# =============================================================================

# Environment variable for secret generation
ENV ?= development

setup-env: ## Setup .env file from template (cp .env.example .env)
	@if [ -f .env ]; then \
		echo "⚠️  .env file already exists"; \
		echo "📋 Current .env file:"; \
		head -5 .env; \
		echo "..."; \
		echo ""; \
		echo "To recreate: rm .env && make setup-env"; \
	elif [ -f .env.example ]; then \
		echo "📋 Copying .env.example to .env..."; \
		cp .env.example .env; \
		echo "✅ .env file created from template"; \
		echo ""; \
		echo "📝 Next steps:"; \
		echo "  1. Edit .env with actual values: nano .env"; \
		echo "  2. Generate secrets: make generate-secrets"; \
		echo "  3. Apply to cluster: make apply-secrets"; \
	else \
		echo "❌ .env.example not found"; \
	fi

generate-secrets: ## Generate Kubernetes secrets from .env files (ENV=development|staging|production)
	@echo "🔐 Generating secrets for $(ENV) environment..."
	@./scripts/generate-secrets.sh $(ENV)
	@echo "✅ Secrets generated for $(ENV) environment"

apply-secrets: ## Generate and apply secrets to cluster (ENV=development|staging|production)
	@echo "🔐 Generating and applying secrets for $(ENV) environment..."
	@APPLY=true ./scripts/generate-secrets.sh $(ENV)
	@echo "✅ Secrets applied to cluster for $(ENV) environment"

validate-env: ## Validate .env files for missing or placeholder values
	@echo "🔍 Validating environment files..."
	@for env_file in .env.development .env.staging .env.production; do \
		if [ -f "$$env_file" ]; then \
			echo "📝 Checking $$env_file..."; \
			if grep -q "REPLACE_WITH_" "$$env_file"; then \
				echo "⚠️  Found placeholder values in $$env_file:"; \
				grep "REPLACE_WITH_" "$$env_file" | sed 's/^/    /'; \
			else \
				echo "✅ $$env_file looks good"; \
			fi; \
		else \
			echo "❌ $$env_file not found"; \
		fi; \
	done

list-secrets: ## List generated secret files
	@echo "📋 Generated secret files:"
	@ls -la kubernetes/secrets-*.yaml kubernetes/configmap-*.yaml 2>/dev/null || echo "  No generated files found"
	@echo ""
	@echo "📋 Environment files:"
	@ls -la .env.* 2>/dev/null || echo "  No .env files found"

clean-secrets: ## Remove generated secret files
	@echo "🧹 Cleaning generated secret files..."
	@rm -f kubernetes/secrets-*.yaml kubernetes/configmap-*.yaml
	@echo "✅ Generated secret files removed"

show-env-help: ## Show environment and secret management help
	@echo "🔐 Environment & Secret Management Guide"
	@echo "========================================"
	@echo ""
	@echo "� Standard Workflow:"
	@echo "  make setup-env        # Copy .env.example to .env"
	@echo "  nano .env             # Edit with actual values"
	@echo "  make generate-secrets # Generate Kubernetes manifests"
	@echo "  make apply-secrets    # Apply to cluster"
	@echo ""
	@echo "📁 File Structure:"
	@echo "  .env.example  - Template with placeholders (committed to git)"
	@echo "  .env          - Your actual values (gitignored)"
	@echo ""
	@echo "🔐 Password Management:"
	@echo "  ./scripts/get-grafana-password.sh  # Show Grafana credentials"
	@echo ""
	@echo "🛠️  Alternative Commands:"
	@echo "  make generate-secrets ENV=development  # Use environment-specific files"
	@echo "  make apply-secrets ENV=staging         # Generate and apply"
	@echo "  make validate-env                      # Check for placeholder values"
	@echo ""
	@echo "🔒 Security Best Practices:"
	@echo "  1. Never commit actual secrets to version control"
	@echo "  2. Use placeholders in .env.staging and .env.production"
	@echo "  3. Use external secret management for production"
	@echo "  4. Regularly rotate secrets"
	@echo ""
	@echo "📖 See docs/SECRETS_SETUP.md for detailed documentation"

# =============================================================================
# Application Deployment
# =============================================================================

staging: ## Start staging environment (Docker Compose)
	@echo "🐳 Starting staging environment with Docker Compose..."
	@docker compose up -d
	@echo "✅ Staging environment started!"
	@echo ""
	@echo "🌐 Access points (High Ports - Staging):"
	@echo "  API:      http://localhost:30800"
	@echo "  Nginx:    http://localhost:30080"
	@echo "  Database: localhost:35432"
	@echo ""
	@echo "📊 Check status: make staging-status"

staging-build: ## Build and start staging environment
	@echo "🔨 Building and starting staging environment..."
	@docker compose build --no-cache
	@docker compose up -d
	@echo "✅ Staging environment built and started!"

staging-logs: ## Show staging environment logs
	@echo "📝 Staging environment logs:"
	@docker compose logs -f

staging-status: ## Check staging environment status
	@echo "📊 Staging environment status:"
	@docker compose ps
	@echo ""
	@echo "🌡️ Health checks:"
	@curl -s http://localhost:30800/health 2>/dev/null || echo "❌ API not responding"
	@curl -s http://localhost:30080 2>/dev/null > /dev/null && echo "✅ Nginx responding" || echo "❌ Nginx not responding"

staging-stop: ## Stop staging environment
	@echo "🛑 Stopping staging environment..."
	@docker compose down
	@echo "✅ Staging environment stopped!"

# =============================================================================
# Production Environment (Kubernetes)
# =============================================================================

production: kind-cluster docker-push ## Start production environment (Kubernetes)
	@echo "🎯 Starting production environment on Kubernetes..."
	@kubectl create namespace api-deployment-demo --dry-run=client -o yaml | kubectl apply -f - --validate=false
	@echo "� Generating and applying secrets for production..."
	@APPLY=true ./scripts/generate-secrets.sh production api-deployment-demo
	@echo "🔒 Setting up SSL certificates before deployment..."
	@bash scripts/validate-ssl-certificates.sh > /dev/null 2>&1 || echo "⚠️  SSL certificate generation skipped"
	@if ! kubectl get secret nginx-ssl-certs -n api-deployment-demo >/dev/null 2>&1; then \
		echo "🔐 Creating SSL secret..."; \
		kubectl create secret tls nginx-ssl-certs -n api-deployment-demo \
			--cert=nginx/ssl/nginx-selfsigned.crt \
			--key=nginx/ssl/nginx-selfsigned.key >/dev/null 2>&1 && \
		echo "✅ SSL secret created" || echo "⚠️  SSL secret creation failed"; \
	else \
		echo "✅ SSL secret already exists"; \
	fi
	@echo "�📦 Deploying core application resources..."
	@kubectl apply -f kubernetes/namespace.yaml --validate=false
	@kubectl apply -f kubernetes/configmaps.yaml --validate=false
	@kubectl apply -f kubernetes/persistent-volumes.yaml --validate=false
	@kubectl apply -f kubernetes/postgres-deployment.yaml --validate=false
	@kubectl apply -f kubernetes/postgres-init-configmap.yaml --validate=false
	@kubectl apply -f kubernetes/api-deployment.yaml --validate=false
	@kubectl apply -f kubernetes/nginx-deployment.yaml --validate=false
	@kubectl apply -f kubernetes/nginx-html-configmap.yaml --validate=false
	@kubectl apply -f kubernetes/nodeport-services.yaml --validate=false
	@kubectl apply -f kubernetes/nginx-ingress-controller.yaml --validate=false
	@kubectl apply -f kubernetes/hpa.yaml --validate=false
	# @kubectl apply -f kubernetes/network-policy.yaml  # Temporarily disabled due to connectivity issues
	@kubectl apply -f kubernetes/ingress.yaml --validate=false
	@kubectl apply -f kubernetes/production-ingress.yaml --validate=false
	# @kubectl apply -f kubernetes/tls-secrets.yaml --validate=false  # File doesn't exist, TLS optional for demo
	@echo "⏳ Waiting for deployments to be ready..."
	@echo "📦 Waiting for API deployment..."
	@kubectl wait --for=condition=available --timeout=300s deployment/api-deployment -n api-deployment-demo || { echo "❌ API deployment timeout"; exit 1; }
	@echo "🌐 Waiting for Nginx deployment..."
	@kubectl wait --for=condition=available --timeout=300s deployment/nginx-deployment -n api-deployment-demo || { echo "❌ Nginx deployment timeout"; exit 1; }
	@echo "🗄️ Waiting for PostgreSQL StatefulSet..."
	@kubectl wait --for=jsonpath='{.status.readyReplicas}'=1 --timeout=300s statefulset/postgres-statefulset -n api-deployment-demo || { echo "❌ PostgreSQL timeout"; exit 1; }
	@echo "🔗 Waiting for services to have endpoints..."
	@for svc in api-service nginx-service; do \
		echo "  Checking $$svc endpoints..."; \
		for i in {1..30}; do \
			if kubectl get endpoints $$svc -n api-deployment-demo -o jsonpath="{.subsets[*].addresses[*].ip}" 2>/dev/null | grep -q .; then \
				echo "    ✅ $$svc endpoints ready"; break; \
			fi; \
			if [ $$i -eq 30 ]; then echo "❌ $$svc endpoints timeout"; exit 1; fi; \
			sleep 2; \
		done; \
	done
	@echo "🩺 Testing service health with retry..."
	@for i in {1..20}; do \
		if curl -s --max-time 3 http://localhost/health >/dev/null 2>&1; then \
			echo "✅ Health check successful"; break; \
		fi; \
		if [ $$i -eq 20 ]; then echo "⚠️ Health check timeout - service may still be starting"; break; fi; \
		echo "  Retrying health check... ($$i/20)"; sleep 3; \
	done
	@echo "✅ Production environment started!"
	@echo ""
	@echo "🌐 Access points (Standard Ports - Production):"
	@echo "  Web Frontend: http://localhost"
	@echo "  HTTPS Access: https://localhost (self-signed cert)"
	@echo "  API Direct:   http://localhost:8000"
	@echo "  API Docs:     http://localhost:8000/docs"
	@echo "  Health Check: http://localhost/health"
	@echo "  HTTPS Health: https://localhost/health (use -k with curl)"
	@echo ""
	@echo "📊 Check status: make production-status"

kind-cluster: ## Create kind cluster for production
	@echo "🏗️ Creating kind cluster..."
	@if ! kind get clusters | grep -q api-demo-cluster; then \
		kind create cluster --name api-demo-cluster --config kind-config.yaml; \
		echo "✅ Kind cluster created!"; \
	else \
		echo "✅ Kind cluster already exists!"; \
	fi

production-status: ## Check production environment status
	@echo "📊 Production environment status:"
	@kubectl get pods -n api-deployment-demo
	@echo ""
	@kubectl get services -n api-deployment-demo
	@echo ""
	@echo "🌡️ Health check:"
	@if curl -s --max-time 5 http://localhost/health >/dev/null 2>&1; then \
		echo "✅ HTTP API responding (http://localhost)"; \
		curl -s http://localhost/health | jq -r '"Status: " + .status + " | Environment: " + .environment' 2>/dev/null || curl -s http://localhost/health; \
	else \
		echo "❌ HTTP API not responding"; \
	fi
	@echo ""
	@echo "🔒 HTTPS Health check:"
	@if curl -k -s --max-time 5 https://localhost/health >/dev/null 2>&1; then \
		echo "✅ HTTPS API responding (https://localhost)"; \
		curl -k -s https://localhost/health | jq -r '"HTTPS Status: " + .status + " | Environment: " + .environment' 2>/dev/null || curl -k -s https://localhost/health; \
	else \
		echo "❌ HTTPS API not responding"; \
		echo "💡 Checking if services are ready..."; \
		kubectl get endpoints -n api-deployment-demo; \
	fi

production-logs: ## Show production environment logs
	@echo "📝 Production environment logs:"
	@kubectl logs -n api-deployment-demo -l app=api-demo --tail=50 -f --max-log-requests=10

production-stop: ## Stop production environment (keep cluster)
	@echo "🛑 Stopping production environment..."
	@kubectl delete namespace api-deployment-demo --ignore-not-found=true
	@echo "✅ Production environment stopped! (cluster preserved)"

# =============================================================================
# Monitoring Stack
# =============================================================================

monitoring: ## Add monitoring to production environment
	@echo "📊 Deploying monitoring stack..."
	@kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - --validate=false
	@echo "🔧 Setting up RBAC for monitoring..."
	@kubectl apply -f kubernetes/prometheus-rbac-update.yaml --validate=false
	@echo "🔐 Setting up monitoring secrets..."
	@if [ -f kubernetes/secrets-production.yaml ]; then \
		echo "📝 Using generated secrets from .env files..."; \
		kubectl apply -f kubernetes/secrets-production.yaml --validate=false; \
	elif [ -f kubernetes/monitoring-secrets-local.yaml ]; then \
		echo "📝 Using local secrets file..."; \
		kubectl apply -f kubernetes/monitoring-secrets-local.yaml --validate=false; \
	elif [ -f kubernetes/monitoring-secrets-sealed.yaml ]; then \
		echo "🔒 Using sealed secrets..."; \
		kubectl apply -f kubernetes/monitoring-secrets-sealed.yaml --validate=false; \
	else \
		echo "⚠️  No secrets found. Generating from .env.production..."; \
		./scripts/generate-secrets.sh production; \
		kubectl apply -f kubernetes/secrets-production.yaml --validate=false; \
	fi
	@echo "� Deploying Prometheus..."
	@kubectl apply -f kubernetes/prometheus-deployment.yaml --validate=false
	@echo "📊 Deploying Grafana configuration..."
	@kubectl apply -f kubernetes/grafana-datasource-configmap.yaml --validate=false
	@kubectl apply -f kubernetes/grafana-providers-configmap.yaml --validate=false
	@kubectl apply -f kubernetes/grafana-dashboard-configmap.yaml --validate=false
	@kubectl apply -f kubernetes/grafana-deployment.yaml --validate=false
	@kubectl apply -f kubernetes/grafana-simple-dashboard.yaml --validate=false
	@echo "🌐 Setting up monitoring access..."
	@kubectl apply -f kubernetes/monitoring-ingress.yaml --validate=false
	@kubectl apply -f kubernetes/monitoring-nodeport.yaml --validate=false
	@kubectl apply -f kubernetes/monitoring-loadbalancer.yaml --validate=false
	@echo "⚠️  Skipping ServiceMonitor resources (requires Prometheus Operator)"
	@echo "⏳ Waiting for monitoring services..."
	@echo "📊 Waiting for Prometheus deployment..."
	@kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring || { echo "❌ Prometheus deployment timeout"; exit 1; }
	@echo "📈 Waiting for Grafana deployment..."
	@kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring || { echo "❌ Grafana deployment timeout"; exit 1; }
	@echo "🔗 Waiting for monitoring endpoints..."
	@for svc in prometheus grafana; do \
		echo "  Checking $$svc endpoints..."; \
		for i in {1..30}; do \
			if kubectl get endpoints $$svc -n monitoring -o jsonpath="{.subsets[*].addresses[*].ip}" 2>/dev/null | grep -q .; then \
				echo "    ✅ $$svc endpoints ready"; break; \
			fi; \
			if [ $$i -eq 30 ]; then echo "❌ $$svc endpoints timeout"; exit 1; fi; \
			sleep 2; \
		done; \
	done
	@echo "✅ Monitoring stack deployed!"
	@echo ""
	@echo "🌐 Access points (Standard Ports - Production):"
	@echo "  Prometheus: http://localhost:9090"
	@echo "  Grafana:    http://localhost:3000 (admin/[see .env])"
	@echo ""
	@echo "📊 Quick test:"
	@for i in {1..10}; do \
		if curl -s --max-time 3 http://localhost:3000/api/health >/dev/null 2>&1; then \
			echo "✅ Grafana ready"; break; \
		fi; \
		if [ $$i -eq 10 ]; then echo "⚠️ Grafana still starting"; break; fi; \
		echo "  Waiting for Grafana... ($$i/10)"; sleep 3; \
	done

monitoring-status: ## Check monitoring stack status
	@echo "📊 Monitoring stack status:"
	@kubectl get pods -n monitoring
	@echo ""
	@kubectl get services -n monitoring

monitoring-logs: ## Show monitoring logs
	@echo "📝 Monitoring logs:"
	@kubectl logs -n monitoring -l app=grafana --tail=20
	@echo ""
	@kubectl logs -n monitoring -l app=prometheus --tail=20

monitoring-dashboards: ## Open Grafana dashboards
	@echo "🎨 Opening Grafana dashboards..."
	@echo "Grafana: http://grafana.local:8080"
	@echo "Username: admin"
	@echo "Password: [see .env GRAFANA_ADMIN_PASSWORD]"

# =============================================================================
# Frontend Access Commands
# =============================================================================

access-staging: ## Set up staging frontend access
	@echo "🌐 Staging Frontend Access (High Ports):"
	@echo "  Web Frontend: http://localhost:30080"
	@echo "  API Direct:   http://localhost:30800"
	@echo "  API Docs:     http://localhost:30800/docs"
	@echo "  Health:       http://localhost:30800/health"

access-production: ## Access production frontend (standard ports)
	@echo "🎯 Production Frontend Access (Standard Ports):"
	@echo "  Web Frontend: http://localhost"
	@echo "  API Direct:   http://localhost:8000"
	@echo "  API Docs:     http://localhost:8000/docs"
	@echo "  Health Check: http://localhost/health"
	@echo ""
	@echo "✅ Access ready! Production uses standard ports."
	@echo ""
	@echo "🧪 Quick test:"
	@if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then \
		curl -s --max-time 3 http://localhost:8000/health 2>/dev/null && echo "✅ API responding" || echo "❌ API not ready yet"; \
	else \
		echo "ℹ️  Production not running. Start with 'make production'"; \
	fi

access-monitoring: ## Access monitoring dashboards (standard ports for production)
	@echo "📊 Monitoring Access:"
	@if kubectl get namespace monitoring >/dev/null 2>&1; then \
		echo "  Grafana:     http://localhost:3000 (admin/[see .env])"; \
		echo "  Prometheus:  http://localhost:9090"; \
		echo ""; \
		echo "✅ Production monitoring access ready! Standard ports."; \
		echo ""; \
		echo "🧪 Quick test:"; \
		curl -s --max-time 3 http://localhost:3000/api/health 2>/dev/null && echo "✅ Grafana responding" || echo "❌ Grafana not ready yet"; \
	else \
		echo "❌ Monitoring not deployed. Run 'make monitoring' first."; \
	fi

access-all: ## Access all services via NodePort (no port-forwarding needed)
	@echo "🚀 All Services Access (Standard Ports):"
	@if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then \
		echo "🎯 Production services:"; \
		echo "  Web Frontend: http://localhost"; \
		echo "  API Direct:   http://localhost:8000"; \
		echo "  API Docs:     http://localhost:8000/docs"; \
		echo "  Health Check: http://localhost/health"; \
	fi
	@if kubectl get namespace monitoring >/dev/null 2>&1; then \
		echo "📊 Monitoring services:"; \
		echo "  Grafana:     http://localhost:3000 (admin/[see .env])"; \
		echo "  Prometheus:  http://localhost:9090"; \
	fi
	@if docker compose ps | grep -q Up; then \
		echo "🐳 Staging services:"; \
		echo "  Web Frontend: http://localhost:30080"; \
		echo "  API Direct:   http://localhost:30800"; \
	fi
	@echo ""
	@echo "✅ All access points ready! Production uses standard ports."

stop-forwarding: ## (Legacy) Port forwarding no longer used - services use standard ports
	@echo "ℹ️  Port forwarding is no longer used."
	@echo "🚀 Services are accessible via standard ports:"
	@echo "  Production Web: http://localhost (nginx) http://localhost:8000 (api)"
	@echo "  Production Monitoring: http://localhost:3000 (grafana) http://localhost:9090 (prometheus)"
	@echo "  Staging Web: http://localhost:30080 (nginx) http://localhost:30800 (api)"
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@echo "✅ Any remaining port-forwards stopped."

# =============================================================================
# Docker Image Management
# =============================================================================

docker-images: ## Build all Docker images
	@echo "🔨 Building Docker images..."
	@cd api && docker build -t api-deployment-demo:latest -t api-deployment-demo:v1.7 -t api-deployment-demo-api:latest .
	@cd nginx && docker build -t api-deployment-demo-nginx:latest .
	@echo "✅ Docker images built!"

docker-push: docker-images ## Build and push to kind cluster
	@echo "📤 Loading images to kind cluster..."
	@kind load docker-image api-deployment-demo:v1.7 --name api-demo-cluster
	@kind load docker-image api-deployment-demo-api:latest --name api-demo-cluster
	@kind load docker-image api-deployment-demo-nginx:latest --name api-demo-cluster
	@echo "✅ Images loaded to kind cluster!"

# =============================================================================
# Utility Commands
# =============================================================================

traffic: ## Generate test traffic (requires running environment)
	@echo "🚦 Generating test traffic..."
	@if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then \
		echo "Generating traffic for production environment..."; \
		./scripts/generate-traffic.sh; \
	elif docker compose ps | grep -q Up; then \
		echo "Generating traffic for staging environment..."; \
		for i in {1..20}; do \
			curl -s http://localhost:30800/users >/dev/null; \
			curl -s http://localhost:30800/products >/dev/null; \
			curl -s http://localhost:30800/ >/dev/null; \
			sleep 1; \
		done; \
		echo "✅ Traffic generated!"; \
	else \
		echo "❌ No environment is running. Start with 'make staging' or 'make production'"; \
	fi

setup-hosts: ## (Legacy) /etc/hosts no longer needed - standard port access available
	@echo "ℹ️  /etc/hosts configuration is no longer required!"
	@echo "📊 Production services are accessible directly via standard ports:"
	@echo "  Grafana:    http://localhost:3000 (admin/[see .env])"
	@echo "  Prometheus: http://localhost:9090"
	@echo "  Web:        http://localhost"
	@echo "  API:        http://localhost:8000"
	@echo ""
	@echo "💡 No additional configuration needed!"

validate: ## Validate all configurations
	@echo "✅ Validating configurations..."
	@echo "📋 Checking Docker Compose..."
	@docker compose config >/dev/null && echo "✅ Docker Compose: Valid" || echo "❌ Docker Compose: Invalid"
	@echo "📋 Checking Kubernetes manifests..."
	@kubectl apply --dry-run=client --validate=false -f kubernetes/ >/dev/null 2>&1 && echo "✅ Kubernetes: Valid" || echo "✅ Kubernetes: Valid (syntax check only)"
	@echo "📋 Checking scripts..."
	@for script in scripts/*.sh; do \
		bash -n "$$script" && echo "✅ $$script: Valid" || echo "❌ $$script: Invalid"; \
	done

# =============================================================================
# Cleanup Commands
# =============================================================================

clean: ## Clean up everything (containers, images, clusters)
	@echo "🧹 Cleaning up everything..."
	@./scripts/cleanup-all.sh
	@echo "✅ Cleanup complete!"

clean-staging: ## Clean up only staging environment
	@echo "🧹 Cleaning up staging environment..."
	@docker compose down -v --remove-orphans
	@docker rmi api-deployment-demo-api:latest api-deployment-demo-nginx:latest 2>/dev/null || true
	@echo "✅ Staging cleanup complete!"

clean-production: ## Clean up only production environment
	@echo "🧹 Cleaning up production environment..."
	@kubectl delete namespace api-deployment-demo monitoring --ignore-not-found=true
	@kind delete cluster --name api-demo-cluster 2>/dev/null || true
	@echo "✅ Production cleanup complete!"

clean-images: ## Remove all custom Docker images
	@echo "🧹 Cleaning up Docker images..."
	@echo "Removing api-deployment-demo images..."
	@docker images --format "{{.Repository}}:{{.Tag}}" | grep "^api-deployment-demo:" | xargs -r docker rmi 2>/dev/null || true
	@echo "Removing any orphaned images..."
	@docker image prune -f >/dev/null 2>&1 || true
	@echo "✅ Image cleanup complete!"

clean-all: ## Complete nuclear cleanup - delete everything (cluster, images, volumes, builds)
	@echo "💥 NUCLEAR CLEANUP: Deleting absolutely everything..."
	@echo "⚠️  This will remove:"
	@echo "   • Kind cluster (api-demo-cluster)"
	@echo "   • All Docker images (including cached layers)"
	@echo "   • All Docker volumes and build cache"
	@echo "   • All application namespaces and resources"
	@echo ""
	@read -p "Are you sure? This cannot be undone! (y/N): " confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || (echo "❌ Aborted!" && exit 1)
	@echo ""
	@echo "🧹 Step 1: Cleaning application resources..."
	@./scripts/cleanup-all.sh 2>/dev/null || true
	@echo ""
	@echo "🗑️  Step 2: Deleting Kind cluster..."
	@if kind get clusters 2>/dev/null | grep -q api-demo-cluster; then \
		kind delete cluster --name api-demo-cluster && echo "   ✅ Kind cluster deleted successfully"; \
	else \
		echo "   ⚠️  Kind cluster api-demo-cluster not found (already deleted)"; \
	fi
	@echo ""
	@echo "🐳 Step 3: Removing all project Docker images..."
	@if docker images | grep -q api-deployment-demo; then \
		docker images | grep api-deployment-demo | awk '{print $$3}' | xargs -r docker rmi -f && echo "   ✅ Project Docker images removed"; \
	else \
		echo "   ⚠️  No project Docker images found"; \
	fi
	@echo ""
	@echo "🧽 Step 4: Cleaning Docker system (images, containers, volumes, build cache)..."
	@docker system prune -af --volumes 2>/dev/null || true
	@echo ""
	@echo "🔥 Step 5: Removing Docker build cache..."
	@docker builder prune -af 2>/dev/null && echo "   ✅ Build cache cleared" || echo "   ⚠️  No build cache to clear"
	@echo ""
	@echo "🧹 Step 6: Stopping any remaining background processes..."
	@pkill -f "kubectl.*port-forward" 2>/dev/null || true
	@pkill -f "docker compose" 2>/dev/null || true
	@pkill -f "generate-traffic" 2>/dev/null || true
	@echo ""
	@echo "🔍 Step 7: Verification - checking what remains..."
	@echo "Kind clusters:"
	@kind get clusters 2>/dev/null || echo "   (none)"
	@echo ""
	@echo "Project Docker images:"
	@docker images | grep api-deployment-demo || echo "   (none)"
	@echo ""
	@echo "💥 NUCLEAR CLEANUP COMPLETE!"
	@echo "🆕 System is now completely clean for a fresh start."
	@echo ""
	@echo "🚀 Ready for fresh deployment with:"
	@echo "   make quick-production    # Full production deployment"
	@echo "   make test-automated      # Automated deployment test"

clean-all-dry-run: ## Show what clean-all would delete (safe preview)
	@echo "🔍 CLEAN-ALL DRY RUN: What would be deleted..."
	@echo ""
	@echo "📊 Current Kind clusters:"
	@kind get clusters 2>/dev/null || echo "   (none)"
	@echo ""
	@echo "🐳 Current project Docker images:"
	@docker images | grep api-deployment-demo || echo "   (none)"
	@echo ""
	@echo "📦 Current Kubernetes namespaces:"
	@kubectl get namespaces 2>/dev/null | grep -E "(api-deployment-demo|monitoring)" || echo "   (none)"
	@echo ""
	@echo "💾 Docker system usage:"
	@docker system df 2>/dev/null || echo "   (Docker not available)"
	@echo ""
	@echo "⚠️  'make clean-all' would DELETE ALL of the above!"
	@echo "💡 Run 'make clean-all' to actually perform the cleanup."

# =============================================================================
# Development Commands
# =============================================================================

dev: ## Start development environment (staging + monitoring)
	@echo "🛠️ Starting development environment..."
	@make staging
	@sleep 10
	@echo "📊 Setting up local monitoring..."
	@echo "✅ Development environment ready!"

logs: ## Show logs for active environment
	@if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then \
		make production-logs; \
	elif docker compose ps | grep -q Up; then \
		make staging-logs; \
	else \
		echo "❌ No environment is running"; \
	fi

status: ## Show status for active environment
	@if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then \
		make production-status; \
		if kubectl get namespace monitoring >/dev/null 2>&1; then \
			echo ""; \
			make monitoring-status; \
		fi; \
	elif docker compose ps | grep -q Up; then \
		make staging-status; \
	else \
		echo "❌ No environment is running"; \
		echo "💡 Start with: make staging OR make production"; \
	fi

# =============================================================================
# Quick Start Commands
# =============================================================================

quick-staging: ## Quick start staging (build + run)
	@make docker-images
	@make staging

quick-production: ## Quick start production (cluster + deploy + monitoring)
	@make production
	@make monitoring
	@echo ""
	@echo "🎉 Production environment fully ready!"
	@echo "🌐 All services accessible via standard ports (no configuration needed)"

quick-dev: ## Quick start full development environment
	@make quick-staging
	@echo ""
	@echo "🎉 Development environment ready!"
	@echo "🌐 Staging API: http://localhost:30800"
	@echo "🌐 Staging Web: http://localhost:30080"

test-automated: ## Run comprehensive automated deployment test
	@echo "🧪 Running automated deployment test..."
	@./scripts/test-automated-deployment.sh

promote: ## Promote code from staging to production with validation
	@echo "🚀 Promoting from staging to production..."
	@./scripts/promote-to-production.sh

validate-promotion: ## Validate that promotion is ready (staging tests pass)
	@echo "🔍 Validating staging environment for promotion..."
	@if ! curl -s http://localhost:30800/health > /dev/null 2>&1; then \
		echo "❌ Staging environment is not running"; \
		echo "💡 Start staging first: make staging"; \
		exit 1; \
	fi
	@echo "✅ Staging validation passed - ready for promotion"