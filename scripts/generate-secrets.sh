#!/bin/bash

# =======================================================================
# Secret Generator - Kubernetes & Terraform
# =======================================================================
# Generate secure secrets for both Kubernetes deployments and Terraform
#
# Modes:
#   ./scripts/generate-secrets.sh [environment] [namespace]
#     - Generates Kubernetes secrets from .env file
#     - environment: development|staging|production (default: development)
#     - namespace: kubernetes namespace (default: api-deployment-demo)
#
#   ./scripts/generate-secrets.sh terraform
#     - Generates terraform.tfvars with secure random passwords
#     - Creates backup of existing file
#     - Auto-generates db_password, secret_key, grafana_password

set -euo pipefail

# Default values
ENVIRONMENT="${1:-development}"
NAMESPACE="${2:-api-deployment-demo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to update or add environment variables in .env files
update_env_file() {
    local env_file="$1"
    local var_name="$2"
    local var_value="$3"
    local temp_file="${env_file}.tmp.$$"
    
    # Update or add variable using awk (more efficient than multiple greps)
    if grep -q "^${var_name}=\|^# ${var_name}=" "$env_file"; then
        # Update or uncomment existing variable
        awk -v var="$var_name" -v val="$var_value" '
            $0 ~ "^" var "=" || $0 ~ "^# " var "=" { print var "=" val; next }
            { print }
        ' "$env_file" > "$temp_file"
        mv "$temp_file" "$env_file"
    else
        # Append new variable
        echo "${var_name}=${var_value}" >> "$env_file"
    fi
}

# Determine and validate environment file
get_env_file() {
    # Check for environment-specific .env file first
    if [[ -f "$PROJECT_ROOT/.env.$ENVIRONMENT" ]]; then
        echo "$PROJECT_ROOT/.env.$ENVIRONMENT"
        return 0
    fi
    
    # Fall back to .env file (single file mode)
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        echo "$PROJECT_ROOT/.env"
        return 0
    fi
    
    # If no files exist, try environment-specific as last resort
    echo "$PROJECT_ROOT/.env.$ENVIRONMENT"
}

# Validate environment
validate_environment() {
    env_file=$(get_env_file)
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_info ""
        log_info "Available options:"
        if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
            log_info "📋 Copy example file to create needed file:"
            if [[ "$env_file" == "$PROJECT_ROOT/.env" ]]; then
                log_info "  cp .env.example .env"
            else
                log_info "  cp .env.example $(basename "$env_file")"
            fi
        fi
        find "$PROJECT_ROOT" -maxdepth 1 -name '.env.*' -type f 2>/dev/null | sed 's/.*\.env\./  - .env./' || echo "  No .env files found"
        log_info ""
        exit 1
    fi
    
    log_info "Using .env file: $env_file"
    
    # Check for placeholder values that need replacement
    if grep -q "REPLACE_WITH_" "$env_file" 2>/dev/null; then
        log_info "Found placeholder values that will be auto-generated:"
        grep "REPLACE_WITH_" "$env_file" | sed 's/^/    /'
    fi
}

# Helper to check if password needs generation
needs_password() {
    local value="${!1:-}"
    [[ -z "$value" ]] || [[ "$value" =~ ^(insecure_|REPLACE_WITH_) ]]
}

# Load environment variables
load_env() {
    local env_file=$(get_env_file)
    
    log_info "Loading environment variables from $env_file"
    
    # Create one-time backup before modifications
    [[ ! -f "${env_file}.backup" ]] && cp "$env_file" "${env_file}.backup"
    
    # Load variables
    set -a; source "$env_file"; set +a
    
    # Set defaults
    CORS_ORIGINS="${CORS_ORIGINS:-*}"
    ALLOWED_HOSTS="${ALLOWED_HOSTS:-localhost,127.0.0.1}"
    GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
    
    # Generate passwords if needed
    local updated=false
    
    if needs_password DB_PASSWORD; then
        DB_PASSWORD=$(openssl rand -base64 24)
        update_env_file "$env_file" "DB_PASSWORD" "$DB_PASSWORD"
        log_info "Generated secure database password"
        updated=true
        
        # Update DATABASE_URL if it exists
        if [[ -n "${DATABASE_URL:-}" ]]; then
            DB_NAME_FROM_URL=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
            DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME_FROM_URL:-$DB_NAME}"
            update_env_file "$env_file" "DATABASE_URL" "$DATABASE_URL"
        fi
    fi
    
    if needs_password SECRET_KEY; then
        SECRET_KEY=$(openssl rand -base64 32)
        update_env_file "$env_file" "SECRET_KEY" "$SECRET_KEY"
        log_info "Generated secure API secret key"
        updated=true
    fi
    
    if needs_password GRAFANA_ADMIN_PASSWORD; then
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
        update_env_file "$env_file" "GRAFANA_ADMIN_PASSWORD" "$GRAFANA_ADMIN_PASSWORD"
        log_info "Generated secure Grafana password"
        updated=true
    fi
    
    [[ "$updated" == true ]] && log_success "Updated $env_file with secure passwords"
    
    # Override environment-specific variables based on ENVIRONMENT parameter
    case "$ENVIRONMENT" in
        production)
            DB_NAME="api_production"
            API_ENV="production"
            log_info "Setting production-specific configuration: DB_NAME=$DB_NAME, API_ENV=$API_ENV"
            # Update DATABASE_URL with correct database name
            DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
            ;;
        staging)
            DB_NAME="api_staging"
            API_ENV="staging"
            log_info "Setting staging-specific configuration: DB_NAME=$DB_NAME, API_ENV=$API_ENV"
            # Update DATABASE_URL with correct database name
            DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
            ;;
        development)
            DB_NAME="${DB_NAME:-api_dev}"
            API_ENV="${API_ENV:-development}"
            log_info "Setting development-specific configuration: DB_NAME=$DB_NAME, API_ENV=$API_ENV"
            # Update DATABASE_URL with correct database name
            DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
            ;;
    esac
    
    # Set defaults for ConfigMap variables
    DB_HOST="${DB_HOST:-postgres}"
    DB_PORT="${DB_PORT:-5432}"
    DB_HOST_AUTH_METHOD="${DB_HOST_AUTH_METHOD:-md5}"
    API_WORKERS="${API_WORKERS:-4}"
    API_PORT="${API_PORT:-8000}"
    SERVER_NAME="${SERVER_NAME:-localhost}"
    HTTP_PORT="${HTTP_PORT:-80}"
    HTTPS_PORT="${HTTPS_PORT:-443}"
    PROMETHEUS_RETENTION="${PROMETHEUS_RETENTION:-30d}"
    POSTGRES_DATA_PATH="${POSTGRES_DATA_PATH:-/var/lib/postgresql/data}"
    PROMETHEUS_DATA_PATH="${PROMETHEUS_DATA_PATH:-/prometheus}"
}

# Generate API secrets
generate_api_secrets() {
    local output_file="$PROJECT_ROOT/kubernetes/secrets-$ENVIRONMENT.yaml"
    local source_file
    
    # Determine source file name for documentation
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source_file=".env"
    else
        source_file=".env.$ENVIRONMENT"
    fi
    
    log_info "Generating API secrets for $ENVIRONMENT environment"
    
    cat > "$output_file" << EOF
# =======================================================================
# Auto-generated Kubernetes Secrets for $ENVIRONMENT environment
# Generated on: $(date)
# Source: $source_file
# =======================================================================
# ⚠️  This file contains sensitive data - handle according to your security policy
# 🔐 For production: Use external secret management (Vault, AWS Secrets Manager, etc.)

apiVersion: v1
kind: Secret
metadata:
  name: api-secrets
  namespace: $NAMESPACE
  labels:
    app: api-demo
    environment: $ENVIRONMENT
    generated-by: generate-secrets.sh
  annotations:
    generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    source-file: "$source_file"
type: Opaque
stringData:
  SECRET_KEY: "$SECRET_KEY"
  DB_PASSWORD: "$DB_PASSWORD"
  DATABASE_URL: "$DATABASE_URL"
  API_ENV: "$API_ENV"
  DEBUG: "$DEBUG"
  LOG_LEVEL: "$LOG_LEVEL"
  CORS_ORIGINS: "$CORS_ORIGINS"
  ALLOWED_HOSTS: "$ALLOWED_HOSTS"

---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: $NAMESPACE
  labels:
    app: api-demo
    component: database
    environment: $ENVIRONMENT
    generated-by: generate-secrets.sh
  annotations:
    generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    source-file: "$source_file"
type: Opaque
stringData:
  DB_PASSWORD: "$DB_PASSWORD"
  DB_NAME: "$DB_NAME"
  DB_USER: "$DB_USER"

---
apiVersion: v1
kind: Secret
metadata:
  name: grafana-admin-secret
  namespace: monitoring
  labels:
    app: grafana
    component: monitoring
    environment: $ENVIRONMENT
    generated-by: generate-secrets.sh
  annotations:
    generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    source-file: "$source_file"
type: Opaque
stringData:
  admin-password: "$GRAFANA_ADMIN_PASSWORD"
  admin-user: "$GRAFANA_ADMIN_USER"
EOF

    log_success "Generated secrets file: $output_file"
}

# Apply secrets to cluster
apply_secrets() {
    local secrets_file="$PROJECT_ROOT/kubernetes/secrets-$ENVIRONMENT.yaml"
    
    if [[ "${APPLY:-false}" == "true" ]]; then
        log_info "Applying secrets to Kubernetes cluster"
        
        # Create namespaces if they don't exist
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        # Check for and delete immutable secrets before applying
        log_info "Checking for immutable secrets..."
        local secrets_to_check=("api-secrets" "postgres-secrets")
        for secret in "${secrets_to_check[@]}"; do
            if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
                local is_immutable=$(kubectl get secret "$secret" -n "$NAMESPACE" -o jsonpath='{.immutable}' 2>/dev/null)
                if [[ "$is_immutable" == "true" ]]; then
                    log_warning "Secret $secret is immutable, deleting before recreating..."
                    kubectl delete secret "$secret" -n "$NAMESPACE"
                fi
            fi
        done
        
        # Check monitoring namespace for grafana secret
        if kubectl get namespace monitoring &>/dev/null; then
            if kubectl get secret grafana-admin-secret -n monitoring &>/dev/null; then
                local is_immutable=$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.immutable}' 2>/dev/null)
                if [[ "$is_immutable" == "true" ]]; then
                    log_warning "Secret grafana-admin-secret is immutable, deleting before recreating..."
                    kubectl delete secret grafana-admin-secret -n monitoring
                fi
            fi
        fi
        
        # Apply secrets
        kubectl apply -f "$secrets_file"
        log_success "Applied secrets to cluster"
        
        # Verify secrets
        log_info "Verifying secrets in cluster:"
        kubectl get secrets -n "$NAMESPACE" -l "generated-by=generate-secrets.sh"
    else
        log_info "Files generated. To apply to cluster, run:"
        log_info "  kubectl apply -f $secrets_file"
        log_info "Or run this script with APPLY=true"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [mode] [namespace]"
    echo ""
    echo "🔧 Kubernetes Secrets Workflow:"
    echo "  1. cp .env.example .env     # Copy template"
    echo "  2. nano .env                # Edit with actual values"
    echo "  3. $0 development           # Generate secrets"
    echo "  4. APPLY=true $0            # Apply to cluster"
    echo ""
    echo "🔧 Terraform Secrets Workflow:"
    echo "  1. $0 terraform             # Generate terraform.tfvars"
    echo "  2. cd terraform && terraform apply"
    echo ""
    echo "Arguments:"
    echo "  mode           terraform | development | staging | production"
    echo "  namespace      Kubernetes namespace (default: api-deployment-demo)"
    echo ""
    echo "Environment variables:"
    echo "  APPLY=true     Automatically apply secrets to cluster"
    echo ""
    echo "Examples:"
    echo "  $0 terraform               # Generate terraform.tfvars"
    echo "  $0 development             # Generate Kubernetes secrets"
    echo "  APPLY=true $0 production   # Generate and apply secrets"
    echo ""
    echo "Available files:"
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        echo "  ✅ .env (ready to use)"
    elif [[ -f "$PROJECT_ROOT/.env.example" ]]; then
        echo "  📋 .env.example (copy to .env first)"
    fi
    
    # List other .env files (excluding .env.example)
    for file in "$PROJECT_ROOT"/.env.*; do
        if [[ -f "$file" && "$file" != *".env.example" ]]; then
            basename "$file" | sed 's/^/  - /'
        fi
    done
}

# Generate terraform.tfvars with secure passwords
generate_terraform_vars() {
    local tfvars_file="$PROJECT_ROOT/terraform/terraform.tfvars"
    local tfvars_example="$PROJECT_ROOT/terraform/terraform.tfvars.example"
    
    log_info "Generating terraform.tfvars with secure passwords..."
    
    # Check if terraform.tfvars already exists
    if [[ -f "$tfvars_file" ]]; then
        log_warning "terraform.tfvars already exists"
        read -p "Do you want to regenerate it? This will backup the existing file. (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping terraform.tfvars generation"
            return
        fi
        
        # Create backup
        local backup_file="${tfvars_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$tfvars_file" "$backup_file"
        log_success "Backed up existing file to $backup_file"
    fi
    
    # Generate secure passwords
    local db_password=$(openssl rand -base64 32)
    local secret_key=$(openssl rand -base64 32)
    local grafana_password=$(openssl rand -base64 24)
    
    # Create terraform.tfvars from example
    if [[ -f "$tfvars_example" ]]; then
        cp "$tfvars_example" "$tfvars_file"
    else
        log_error "terraform.tfvars.example not found"
        exit 1
    fi
    
    # Replace placeholders with generated values
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|REPLACE_WITH_SECURE_DB_PASSWORD|$db_password|g" "$tfvars_file"
        sed -i '' "s|REPLACE_WITH_SECURE_API_SECRET_KEY|$secret_key|g" "$tfvars_file"
        sed -i '' "s|REPLACE_WITH_SECURE_GRAFANA_PASSWORD|$grafana_password|g" "$tfvars_file"
    else
        # Linux
        sed -i "s|REPLACE_WITH_SECURE_DB_PASSWORD|$db_password|g" "$tfvars_file"
        sed -i "s|REPLACE_WITH_SECURE_API_SECRET_KEY|$secret_key|g" "$tfvars_file"
        sed -i "s|REPLACE_WITH_SECURE_GRAFANA_PASSWORD|$grafana_password|g" "$tfvars_file"
    fi
    
    log_success "Generated terraform.tfvars with secure passwords"
    echo ""
    log_info "📋 Generated credentials:"
    echo "  Database password: ${db_password:0:8}... (${#db_password} chars)"
    echo "  API secret key: ${secret_key:0:8}... (${#secret_key} chars)"
    echo "  Grafana password: ${grafana_password:0:8}... (${#grafana_password} chars)"
    echo ""
    log_warning "🔐 IMPORTANT: Backup terraform.tfvars securely!"
    log_warning "   This file contains sensitive credentials"
    log_warning "   It is excluded from git via .gitignore"
    echo ""
    log_info "You can now run: cd terraform && terraform apply"
}

# Main function
main() {
    log_info "🔐 Kubernetes Secret Generator"
    
    # Special mode: terraform tfvars generation
    if [[ "$ENVIRONMENT" == "terraform" ]]; then
        generate_terraform_vars
        exit 0
    fi
    
    log_info "Environment: $ENVIRONMENT"
    log_info "Namespace: $NAMESPACE"
    echo ""
    
    if [[ "$ENVIRONMENT" == "--help" || "$ENVIRONMENT" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    validate_environment
    load_env
    generate_api_secrets
    apply_secrets
    
    echo ""
    log_success "Secret generation complete!"
    
    if [[ "$ENVIRONMENT" != "development" ]]; then
        echo ""
        log_warning "Security reminders for $ENVIRONMENT:"
        log_warning "1. Review generated files before committing"
        log_warning "2. Consider using external secret management"
        log_warning "3. Rotate secrets regularly"
        log_warning "4. Audit secret access logs"
    fi
}

# Run main function
main "$@"