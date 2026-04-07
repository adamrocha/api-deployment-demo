#!/bin/bash

# Get Grafana password from .env or Kubernetes secret
# Usage: ./scripts/get-grafana-password.sh

set -euo pipefail

# Configuration - can be overridden via environment variables
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring-ns}"

echo "🔐 Grafana Password Retrieval"
echo "============================="

# Check if .env file exists and has the password
if [[ -f ".env" ]] && grep -q "GRAFANA_ADMIN_PASSWORD" .env; then
	echo "📝 From .env file:"
	grep "GRAFANA_ADMIN_PASSWORD" .env | cut -d'=' -f2 | tr -d '"'
	echo ""
fi

# Check if Kubernetes secret exists
if kubectl get secret grafana-admin-secret -n "${MONITORING_NAMESPACE}" >/dev/null 2>&1; then
	echo "🔒 From Kubernetes secret:"
	kubectl get secret grafana-admin-secret -n "${MONITORING_NAMESPACE}" -o jsonpath='{.data.admin-password}' | base64 -d
	echo ""
	echo ""
	echo "👤 Login credentials:"
	echo "   Username: admin"
	echo "   Password: $(kubectl get secret grafana-admin-secret -n "${MONITORING_NAMESPACE}" -o jsonpath='{.data.admin-password}' | base64 -d)"
	echo ""
	echo "🌐 Access URL: http://localhost:3000"
else
	echo "❌ Kubernetes secret 'grafana-admin-secret' not found in 'monitoring' namespace"
	echo "   Run 'make apply-secrets' to create the secret"
fi
