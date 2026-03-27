#!/usr/bin/env bash

# =======================================================================
# Kustomize Secret Env Generator
# =======================================================================
# Generates secure random secrets into local overlay .env files for Kustomize.
#
# Usage:
#   ./scripts/generate-kustomize-secrets.sh [overlay] [--rotate]
#     overlay: staging|production (default: staging)
#
# This script:
# 1. Reads root .env values
# 2. Generates missing/random secrets (or rotates with --rotate)
# 3. Writes overlay-local .env files consumed by secretGenerator envs
# =======================================================================

set -euo pipefail

OVERLAY="${1:-staging}"
ROTATE=false
if [[ "${1:-}" == "--rotate" ]]; then
    OVERLAY="staging"
    ROTATE=true
fi
if [[ "${2:-}" == "--rotate" ]]; then
    ROTATE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_ENV_FILE="${ROOT_ENV_FILE:-${PROJECT_ROOT}/.env}"
OVERLAY_DIR="${PROJECT_ROOT}/kustomize/overlays/${OVERLAY}"
KUSTOMIZE_FILE="${OVERLAY_DIR}/kustomization.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

generate_secret() {
    local bytes="$1"
    openssl rand -base64 "${bytes}" | tr -d '\n'
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[&|]/\\&/g'
}

set_or_append_env() {
    local key="$1"
    local value="$2"
    local file="$3"
    local escaped
    escaped="$(escape_sed_replacement "${value}")"

    if grep -q "^${key}=" "${file}"; then
        sed -i '' -e "s|^${key}=.*$|${key}=${escaped}|" "${file}"
    else
        printf '\n%s=%s\n' "${key}" "${value}" >> "${file}"
    fi
}

echo -e "${BLUE}"
echo "=================================================================="
echo "🔐 Kustomize Secret Env Generator"
echo "=================================================================="
echo -e "${NC}"

# Validate overlay
if [[ ! -f "${KUSTOMIZE_FILE}" ]]; then
    log_error "Kustomization file not found: $KUSTOMIZE_FILE"
    log_info "Available overlays:"
    ls -1 "${PROJECT_ROOT}/kustomize/overlays/" | sed 's/^/  - /'
    exit 1
fi

if [[ ! -f "${ROOT_ENV_FILE}" ]]; then
    log_error "Root .env file not found: ${ROOT_ENV_FILE}"
    exit 1
fi

log_info "Overlay: ${OVERLAY}"
log_info "Root env: ${ROOT_ENV_FILE}"
log_info "Kustomize file: ${KUSTOMIZE_FILE}"
echo ""

# shellcheck disable=SC1090
set -a
source "${ROOT_ENV_FILE}"
set +a

# Generate or rotate root-level secrets
if [[ "${ROTATE}" == "true" ]] || [[ -z "${DB_PASSWORD:-}" ]]; then
    DB_PASSWORD="$(generate_secret 24)"
    set_or_append_env "DB_PASSWORD" "${DB_PASSWORD}" "${ROOT_ENV_FILE}"
    log_success "Updated DB_PASSWORD in root .env"
fi

if [[ "${ROTATE}" == "true" ]] || [[ -z "${SECRET_KEY:-}" ]]; then
    SECRET_KEY="$(generate_secret 32)"
    set_or_append_env "SECRET_KEY" "${SECRET_KEY}" "${ROOT_ENV_FILE}"
    log_success "Updated SECRET_KEY in root .env"
fi

if [[ "${ROTATE}" == "true" ]] || [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
    GRAFANA_ADMIN_PASSWORD="$(generate_secret 18)"
    set_or_append_env "GRAFANA_ADMIN_PASSWORD" "${GRAFANA_ADMIN_PASSWORD}" "${ROOT_ENV_FILE}"
    log_success "Updated GRAFANA_ADMIN_PASSWORD in root .env"
fi

DB_USER="${DB_USER:-postgres}"
ADMIN_EMAIL="${ADMIN_EMAIL:-${SSL_EMAIL:-admin@example.com}}"

if [[ "${OVERLAY}" == "production" ]]; then
    DB_NAME="api_production"
else
    DB_NAME="api_staging"
fi

umask 077
mkdir -p "${OVERLAY_DIR}"

cat > "${OVERLAY_DIR}/database-credentials.env" <<EOF
db-name=${DB_NAME}
db-user=${DB_USER}
db-password=${DB_PASSWORD}
EOF

cat > "${OVERLAY_DIR}/api-secrets.env" <<EOF
SECRET_KEY=${SECRET_KEY}
EOF

cat > "${OVERLAY_DIR}/grafana-secrets.env" <<EOF
admin-password=${GRAFANA_ADMIN_PASSWORD}
EOF

if [[ "${OVERLAY}" == "production" ]]; then
    cat > "${OVERLAY_DIR}/production-secrets.env" <<EOF
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF
fi

log_success "Generated overlay env files in ${OVERLAY_DIR}"
echo ""

# Test kustomize build
log_info "Testing kustomize build..."
if kubectl kustomize "${PROJECT_ROOT}/kustomize/overlays/${OVERLAY}" > /dev/null 2>&1; then
    log_success "Kustomize build successful"
else
    log_error "Kustomize build failed"
    log_warning "Ensure secretGenerator uses envs in ${KUSTOMIZE_FILE}"
    exit 1
fi

# Summary
echo ""
log_success "Secret generation complete!"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  1. Root secrets are in: ${ROOT_ENV_FILE}"
echo "  2. Overlay files are local: ${OVERLAY_DIR}/*.env"
echo "  3. Do not commit files that contain real secret values"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  • Deploy with: make deploy ENV=${OVERLAY}"
echo "  • Or manually: kubectl apply -k kustomize/overlays/${OVERLAY}"
if [[ "${ROTATE}" != "true" ]]; then
    echo "  • Use --rotate to force brand new random values"
fi
echo ""
