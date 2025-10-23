#!/bin/bash

# =======================================================================
# Kubernetes Secret Generator from .env files
# =======================================================================
# This script generates Kubernetes secrets from environment files
# 
# Single File Mode (preferred):
#   - Uses .env file if it exists
#   - Simpler workflow for single-environment setups
#
# Multi-File Mode (advanced):
#   - Uses .env.[environment] files
#   - Supports multiple environments
#
# Usage: ./scripts/generate-secrets.sh [environment] [namespace]
#   environment: development|staging|production (default: development)
#   namespace: kubernetes namespace (default: api-deployment-demo)

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

# Validate environment
validate_environment() {
    local env_file
    
    # Check for .env file first (single file mode)
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        env_file="$PROJECT_ROOT/.env"
        log_info "Using .env file: $env_file"
        
        # Check if .env looks like it came from .env.example (has placeholder values)
        if grep -q "your_secure_database_password_here\|your-very-secure-secret-key-change-this-in-production" "$env_file"; then
            log_warning "Your .env file appears to contain placeholder values from .env.example"
            log_info "Please update the placeholder values with actual secrets before proceeding"
            log_info "Placeholder values found:"
            grep -n "your_secure_database_password_here\|your-very-secure-secret-key-change-this-in-production" "$env_file" | sed 's/^/    /'
            exit 1
        fi
        return 0
    fi
    
    # If no .env file exists, check if .env.example exists and guide user
    if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
        log_error "No .env file found, but .env.example exists"
        log_info ""
        log_info "🔧 Recommended workflow:"
        log_info "1. Copy the example file:    cp .env.example .env"
        log_info "2. Edit with actual values:  nano .env"
        log_info "3. Generate secrets:         ./scripts/generate-secrets.sh"
        log_info "4. Apply to cluster:         APPLY=true ./scripts/generate-secrets.sh"
        log_info ""
        exit 1
    fi
    
    # Fall back to environment-specific files
    env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_info ""
        log_info "Available options:"
        if [[ -f "$PROJECT_ROOT/.env.example" ]]; then
            log_info "📋 Copy example file:  cp .env.example .env"
        fi
        ls -1 "$PROJECT_ROOT"/.env.* 2>/dev/null | sed 's/.*\.env\./  - .env./' || echo "  No .env files found"
        log_info ""
        log_info "💡 Recommended: Use single .env file (copy from .env.example)"
        exit 1
    fi
    
    log_info "Using environment file: $env_file"
}

# Check for placeholder values
check_placeholders() {
    local env_file
    
    # Determine which env file to check
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        env_file="$PROJECT_ROOT/.env"
    else
        env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    fi
    
    if grep -q "REPLACE_WITH_" "$env_file"; then
        log_warning "Found placeholder values in $env_file:"
        grep "REPLACE_WITH_" "$env_file" | sed 's/^/    /'
        
        if [[ "$ENVIRONMENT" == "production" || "$ENVIRONMENT" == "staging" ]]; then
            log_error "Placeholder values detected in $ENVIRONMENT environment"
            log_info "Please replace all REPLACE_WITH_* values with actual secrets"
            exit 1
        else
            log_warning "Continuing with placeholders for $ENVIRONMENT environment"
        fi
    fi
}

# Load environment variables
load_env() {
    local env_file
    
    # Determine which env file to load
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        env_file="$PROJECT_ROOT/.env"
    else
        env_file="$PROJECT_ROOT/.env.$ENVIRONMENT"
    fi
    
    log_info "Loading environment variables from $env_file"
    
    # Export variables while preserving existing environment
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
    
    # Set defaults for optional variables that might be commented out
    CORS_ORIGINS="${CORS_ORIGINS:-*}"
    ALLOWED_HOSTS="${ALLOWED_HOSTS:-localhost,127.0.0.1}"
    GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
    GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
    
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

# Generate ConfigMap for non-sensitive environment variables
generate_configmap() {
    local output_file="$PROJECT_ROOT/kubernetes/configmap-$ENVIRONMENT.yaml"
    local source_file
    
    # Determine source file name for documentation
    if [[ -f "$PROJECT_ROOT/.env" ]]; then
        source_file=".env"
    else
        source_file=".env.$ENVIRONMENT"
    fi
    
    log_info "Generating ConfigMap for $ENVIRONMENT environment"
    
    cat > "$output_file" << EOF
# =======================================================================
# Auto-generated Kubernetes ConfigMap for $ENVIRONMENT environment
# Generated on: $(date)
# Source: $source_file
# =======================================================================
# 📝 This file contains non-sensitive configuration data

apiVersion: v1
kind: ConfigMap
metadata:
  name: api-config
  namespace: $NAMESPACE
  labels:
    app: api-demo
    environment: $ENVIRONMENT
    generated-by: generate-secrets.sh
  annotations:
    generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    source-file: "$source_file"
data:
  DB_NAME: "$DB_NAME"
  DB_USER: "$DB_USER"
  DB_HOST: "$DB_HOST"
  DB_PORT: "$DB_PORT"
  DB_HOST_AUTH_METHOD: "$DB_HOST_AUTH_METHOD"
  API_ENV: "$API_ENV"
  API_WORKERS: "$API_WORKERS"
  API_PORT: "$API_PORT"
  SERVER_NAME: "$SERVER_NAME"
  HTTP_PORT: "$HTTP_PORT"
  HTTPS_PORT: "$HTTPS_PORT"
  PROMETHEUS_RETENTION: "$PROMETHEUS_RETENTION"
  POSTGRES_DATA_PATH: "$POSTGRES_DATA_PATH"
  PROMETHEUS_DATA_PATH: "$PROMETHEUS_DATA_PATH"
EOF

    # Add production-specific config if available
    if [[ -n "${REPLICA_COUNT:-}" ]]; then
        cat >> "$output_file" << EOF
  REPLICA_COUNT: "$REPLICA_COUNT"
  MAX_REPLICAS: "$MAX_REPLICAS"
  CPU_LIMIT: "$CPU_LIMIT"
  MEMORY_LIMIT: "$MEMORY_LIMIT"
EOF
    fi

    log_success "Generated ConfigMap file: $output_file"
}

# Apply secrets to cluster
apply_secrets() {
    local secrets_file="$PROJECT_ROOT/kubernetes/secrets-$ENVIRONMENT.yaml"
    local configmap_file="$PROJECT_ROOT/kubernetes/configmap-$ENVIRONMENT.yaml"
    
    if [[ "${APPLY:-false}" == "true" ]]; then
        log_info "Applying secrets to Kubernetes cluster"
        
        # Create namespace if it doesn't exist
        kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        # Apply ConfigMap first
        kubectl apply -f "$configmap_file"
        log_success "Applied ConfigMap to cluster"
        
        # Apply secrets
        kubectl apply -f "$secrets_file"
        log_success "Applied secrets to cluster"
        
        # Verify secrets
        log_info "Verifying secrets in cluster:"
        kubectl get secrets -n "$NAMESPACE" -l "generated-by=generate-secrets.sh"
        kubectl get secrets -n monitoring -l "generated-by=generate-secrets.sh"
    else
        log_info "Files generated. To apply to cluster, run:"
        log_info "  kubectl apply -f $configmap_file"
        log_info "  kubectl apply -f $secrets_file"
        log_info "Or run this script with APPLY=true"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [environment] [namespace]"
    echo ""
    echo "🔧 Recommended Workflow:"
    echo "  1. cp .env.example .env     # Copy template"
    echo "  2. nano .env                # Edit with actual values"
    echo "  3. $0                       # Generate secrets"
    echo "  4. APPLY=true $0            # Apply to cluster"
    echo ""
    echo "File Modes:"
    echo "  Single File Mode: Uses .env (recommended for simple setups)"
    echo "  Multi-File Mode:  Uses .env.[environment] files"
    echo ""
    echo "Arguments:"
    echo "  environment    Environment name (development, staging, production)"
    echo "  namespace      Kubernetes namespace (default: api-deployment-demo)"
    echo ""
    echo "Environment variables:"
    echo "  APPLY=true     Automatically apply secrets to cluster"
    echo ""
    echo "Examples:"
    echo "  $0 development     # Uses .env or .env.development"
    echo "  $0 production api-prod"
    echo "  APPLY=true $0 staging"
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

# Main function
main() {
    log_info "🔐 Kubernetes Secret Generator"
    log_info "Environment: $ENVIRONMENT"
    log_info "Namespace: $NAMESPACE"
    echo ""
    
    if [[ "$ENVIRONMENT" == "--help" || "$ENVIRONMENT" == "-h" ]]; then
        show_usage
        exit 0
    fi
    
    validate_environment
    check_placeholders
    load_env
    generate_api_secrets
    generate_configmap
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