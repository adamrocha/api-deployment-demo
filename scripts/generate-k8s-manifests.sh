#!/bin/bash

# =======================================================================
# Kubernetes Manifest Generator from Environment Variables
# =======================================================================
# This script applies environment variables to Kubernetes manifests
# 
# Usage: ./scripts/generate-k8s-manifests.sh [environment] [output_dir]
#   environment: staging|production (default: production)
#   output_dir: where to write processed manifests (default: kubernetes/generated)

set -euo pipefail

# Default values
ENVIRONMENT="${1:-production}"
OUTPUT_DIR="${2:-kubernetes/generated}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="$PROJECT_ROOT/kubernetes"

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

echo ""
log_info "🔧 Kubernetes Manifest Generator"
log_info "Environment: $ENVIRONMENT"
log_info "Output directory: $OUTPUT_DIR"
echo ""

# Load environment variables
log_info "Loading environment variables for $ENVIRONMENT"

# Set ENVIRONMENT in .env temporarily
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # Update ENVIRONMENT if present, else append it
    if grep -q '^ENVIRONMENT=' "$PROJECT_ROOT/.env"; then
        sed -i.bak "s/^ENVIRONMENT=.*/ENVIRONMENT=$ENVIRONMENT/" "$PROJECT_ROOT/.env" && rm -f "$PROJECT_ROOT/.env.bak"
    else
        echo "ENVIRONMENT=$ENVIRONMENT" >> "$PROJECT_ROOT/.env"
    fi
else
    log_error ".env file not found at $PROJECT_ROOT/.env!"
    exit 1
fi

# Source environment variables directly from .env
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    log_error ".env file not found at $PROJECT_ROOT/.env!"
    exit 1

# Export variables for envsubst (only strings, no integers)
export K8S_NAMESPACE="${K8S_NAMESPACE:-api-deployment-demo}"
export DB_NAME="${DB_NAME:-api_production}"
export DB_USER="${DB_USER:-postgres}"
export DB_HOST="${DB_HOST:-postgres-service}"
export DB_PORT="${DB_PORT:-5432}"
export API_WORKERS="${API_WORKERS:-8}"
export API_MEMORY_REQUEST="${API_MEMORY_REQUEST:-512Mi}"
export API_CPU_REQUEST="${API_CPU_REQUEST:-500m}"
export API_MEMORY_LIMIT="${API_MEMORY_LIMIT:-1Gi}"
export API_CPU_LIMIT="${API_CPU_LIMIT:-1000m}"
export NGINX_MEMORY_REQUEST="${NGINX_MEMORY_REQUEST:-128Mi}"
export NGINX_CPU_REQUEST="${NGINX_CPU_REQUEST:-250m}"
export NGINX_MEMORY_LIMIT="${NGINX_MEMORY_LIMIT:-256Mi}"
export NGINX_CPU_LIMIT="${NGINX_CPU_LIMIT:-500m}"
export DB_MEMORY_LIMIT="${DB_MEMORY_LIMIT:-2Gi}"
export DB_CPU_LIMIT="${DB_CPU_LIMIT:-2000m}"
export SERVER_NAME="${SERVER_NAME:-api.yourdomain.com}"

log_success "Loaded environment variables"
log_info "  K8S_NAMESPACE: $K8S_NAMESPACE"
log_info "  DB_NAME: $DB_NAME"
log_info "  DB_HOST: $DB_HOST"
log_info "  API_MEMORY_LIMIT: $API_MEMORY_LIMIT"
echo ""

# Create output directory
log_info "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Process manifests
log_info "Processing Kubernetes manifests with environment variables..."
echo ""

generated_count=0

# List of files to process (exclude secrets and generated files)
for manifest in "$MANIFESTS_DIR"/*.yaml; do
    filename=$(basename "$manifest")
    
    # Skip certain files
    if [[ "$filename" == "secrets-"* ]] || \
       [[ "$filename" == "generated-"* ]] || \
       [[ "$filename" == "monitoring-secrets.yaml" ]]; then
        continue
    fi
    
    output_file="$OUTPUT_DIR/${ENVIRONMENT}-${filename}"
    
    # Use envsubst to replace environment variables
    # Only substitute the specific variables we've exported
    envsubst '$K8S_NAMESPACE,$DB_NAME,$DB_USER,$DB_HOST,$DB_PORT,$API_WORKERS,$API_MEMORY_REQUEST,$API_CPU_REQUEST,$API_MEMORY_LIMIT,$API_CPU_LIMIT,$NGINX_MEMORY_REQUEST,$NGINX_CPU_REQUEST,$NGINX_MEMORY_LIMIT,$NGINX_CPU_LIMIT,$DB_MEMORY_LIMIT,$DB_CPU_LIMIT,$SERVER_NAME' < "$manifest" > "$output_file"
    
    log_success "Generated: ${ENVIRONMENT}-${filename}"
    ((generated_count++))
done

echo ""
if [[ $generated_count -eq 0 ]]; then
    log_warning "No manifests processed"
else
    log_success "Generated $generated_count manifest files in $OUTPUT_DIR"
    echo ""
    log_info "📋 To apply all manifests to cluster:"
    log_info "  kubectl apply -f $OUTPUT_DIR/"
    echo ""
    log_info "📋 To apply specific manifest:"
    log_info "  kubectl apply -f $OUTPUT_DIR/${ENVIRONMENT}-api-deployment.yaml"
    echo ""
    log_info "💡 Tip: Review the generated files before applying"
fi
