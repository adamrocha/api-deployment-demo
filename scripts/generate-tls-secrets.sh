#!/usr/bin/env bash

# =======================================================================
# TLS Secret Generator for Kubernetes
# =======================================================================
# Generates kubernetes/tls-secret.yaml from SSL certificates
# 
# Usage:
#   ./scripts/generate-tls-secrets.sh [namespace] [secret-name]
#
# Examples:
#   ./scripts/generate-tls-secrets.sh                                    # Default: api-deployment-demo/nginx-tls-secret
#   ./scripts/generate-tls-secrets.sh monitoring grafana-tls-secret      # Custom namespace/name
# =======================================================================

set -euo pipefail

# Configuration
NAMESPACE=${1:-api-deployment-demo}
SECRET_NAME=${2:-nginx-tls-secret}
CERT_FILE="nginx/ssl/nginx-selfsigned.crt"
KEY_FILE="nginx/ssl/nginx-selfsigned.key"
OUTPUT_FILE="kubernetes/tls-secret.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Header
echo -e "${BLUE}"
echo "=================================================================="
echo "🔐 TLS Secret Generator for Kubernetes"
echo "=================================================================="
echo -e "${NC}"

log_info "Configuration:"
echo "  Namespace:   ${NAMESPACE}"
echo "  Secret Name: ${SECRET_NAME}"
echo "  Certificate: ${CERT_FILE}"
echo "  Private Key: ${KEY_FILE}"
echo "  Output File: ${OUTPUT_FILE}"
echo ""

# Check if SSL certificates exist
if [[ ! -f "$CERT_FILE" ]]; then
    log_error "Certificate file not found: $CERT_FILE"
    log_info "Generating SSL certificates first..."
    
    # Generate SSL certificates using the nginx script
    if [[ -f "nginx/generate-ssl.sh" ]]; then
        cd nginx
        ./generate-ssl.sh
        cd ..
        log_success "SSL certificates generated"
    else
        log_error "SSL generation script not found: nginx/generate-ssl.sh"
        exit 1
    fi
fi

if [[ ! -f "$KEY_FILE" ]]; then
    log_error "Private key file not found: $KEY_FILE"
    exit 1
fi

# Validate certificates
log_info "Validating SSL certificates..."
if openssl x509 -in "$CERT_FILE" -text -noout >/dev/null 2>&1; then
    log_success "Certificate is valid"
else
    log_error "Invalid certificate file: $CERT_FILE"
    exit 1
fi

# Get certificate and key in base64 encoding
log_info "Encoding certificates to base64..."
CERT_B64=$(base64 -i "$CERT_FILE" | tr -d '\n')
KEY_B64=$(base64 -i "$KEY_FILE" | tr -d '\n')

# Generate the Kubernetes TLS secret YAML
log_info "Generating TLS secret YAML..."
cat > "$OUTPUT_FILE" << EOF
# =======================================================================
# TLS Secret for Kubernetes
# =======================================================================
# Generated on: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
# Namespace: ${NAMESPACE}
# Secret Name: ${SECRET_NAME}
# Certificate: ${CERT_FILE}
# Private Key: ${KEY_FILE}
# =======================================================================

apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: api-demo
    component: ssl
    generated-by: generate-tls-secrets.sh
    generated-at: "$(date -u +%s)"
type: kubernetes.io/tls
data:
  tls.crt: ${CERT_B64}
  tls.key: ${KEY_B64}
EOF

# Success message
log_success "TLS secret YAML generated: ${OUTPUT_FILE}"
echo ""

# Display certificate information
log_info "Certificate Information:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After |DNS:|IP Address:)" | sed 's/^/  /'

echo ""

# Apply to cluster if APPLY environment variable is set
if [[ "${APPLY:-false}" == "true" ]]; then
    log_info "Applying TLS secret to cluster..."
    if kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
        log_warning "TLS secret ${SECRET_NAME} already exists in namespace ${NAMESPACE}"
        echo "  Use 'kubectl delete secret ${SECRET_NAME} -n ${NAMESPACE}' to recreate"
    else
        if kubectl apply -f "${OUTPUT_FILE}" >/dev/null 2>&1; then
            log_success "TLS secret applied to cluster successfully"
        else
            log_error "Failed to apply TLS secret to cluster"
            exit 1
        fi
    fi
    echo ""
fi

# Usage instructions
log_info "Usage Instructions:"
echo "  1. Apply to cluster:   kubectl apply -f ${OUTPUT_FILE}"
echo "  2. Verify creation:    kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}"
echo "  3. View details:       kubectl describe secret ${SECRET_NAME} -n ${NAMESPACE}"
echo ""
echo "  Alternative: Set APPLY=true to auto-apply:"
echo "    APPLY=true ./scripts/generate-tls-secrets.sh"
echo ""

# Security reminder
log_warning "Security Reminder:"
echo "  • This file contains base64-encoded certificate data"
echo "  • Do not commit this file to version control"
echo "  • The file is gitignored for security"
echo ""

log_success "TLS secret generation complete! 🔐"