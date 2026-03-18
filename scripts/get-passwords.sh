#!/bin/bash

# Password Extraction Helper Script
# Displays all passwords from Terraform and Kubernetes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Password Extraction Tool${NC}\n"

# =============================================================================
# Terraform Passwords
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Terraform Configuration (terraform.tfvars)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [[ -f "terraform/terraform.tfvars" ]]; then
	DB_PASS=$(grep 'db_password' terraform/terraform.tfvars | cut -d'"' -f2)
	SECRET_KEY=$(grep 'secret_key' terraform/terraform.tfvars | cut -d'"' -f2)
	GRAFANA_PASS=$(grep 'grafana_password' terraform/terraform.tfvars | cut -d'"' -f2)

	# Check if these are placeholder values
	if [[ $DB_PASS == "REPLACE_WITH_SECURE_DB_PASSWORD" || $DB_PASS == "" ]]; then
		echo -e "  ${YELLOW}⚠️  terraform.tfvars contains placeholder values${NC}"
		echo -e "  ${YELLOW}Run: ./scripts/generate-secrets.sh terraform${NC}"
		echo -e "  ${YELLOW}Or manually update terraform/terraform.tfvars${NC}"
	else
		echo -e "  ${GREEN}Database Password:${NC}"
		echo -e "    $DB_PASS"
		echo ""
		echo -e "  ${GREEN}API Secret Key:${NC}"
		echo -e "    $SECRET_KEY"
		echo ""
		echo -e "  ${GREEN}Grafana Password:${NC}"
		echo -e "    $GRAFANA_PASS"
	fi
else
	echo -e "  ${YELLOW}⚠️  terraform.tfvars not found${NC}"
	echo -e "  ${YELLOW}Run: ./scripts/generate-secrets.sh terraform${NC}"
fi

# =============================================================================
# Kubernetes Passwords
# =============================================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}☸️  Kubernetes Secrets${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
	echo -e "  ${YELLOW}⚠️  kubectl not installed${NC}"
elif ! kubectl cluster-info &>/dev/null; then
	echo -e "  ${YELLOW}⚠️  Kubernetes cluster not accessible${NC}"
	echo -e "  ${YELLOW}Start cluster: make cluster${NC}"
else
	NAMESPACE="api-deployment-demo"

	# Check if namespace exists
	if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
		echo -e "  ${YELLOW}⚠️  Namespace '$NAMESPACE' not found${NC}"
		echo -e "  ${YELLOW}Deploy with: make deploy${NC}"
	else
		echo -e "${GREEN}Database Credentials:${NC}"
		# Try postgres-secrets first (our new secret name), then fall back to database-credentials
		if kubectl get secret postgres-secrets -n "$NAMESPACE" &>/dev/null; then
			DB_USER=$(kubectl get secret postgres-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_USER}' 2>/dev/null | base64 -d 2>/dev/null || echo "postgres")
			DB_NAME=$(kubectl get secret postgres-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_NAME}' 2>/dev/null | base64 -d 2>/dev/null || echo "api_db")
			K8S_DB_PASS=$(kubectl get secret postgres-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")

			echo -e "  User:     ${DB_USER}"
			echo -e "  Database: ${DB_NAME}"
			echo -e "  Password: ${K8S_DB_PASS}"
		elif kubectl get secret database-credentials -n "$NAMESPACE" &>/dev/null; then
			DB_USER=$(kubectl get secret database-credentials -n "$NAMESPACE" -o jsonpath='{.data.db-user}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
			DB_NAME=$(kubectl get secret database-credentials -n "$NAMESPACE" -o jsonpath='{.data.db-name}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
			K8S_DB_PASS=$(kubectl get secret database-credentials -n "$NAMESPACE" -o jsonpath='{.data.db-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")

			echo -e "  User:     ${DB_USER}"
			echo -e "  Database: ${DB_NAME}"
			echo -e "  Password: ${K8S_DB_PASS}"
		else
			echo -e "  ${YELLOW}⚠️  Database secrets not found${NC}"
		fi

		echo ""
		echo -e "${GREEN}API Secret:${NC}"
		if kubectl get secret api-secrets -n "$NAMESPACE" &>/dev/null; then
			# Try different possible field names
			K8S_SECRET=$(kubectl get secret api-secrets -n "$NAMESPACE" -o jsonpath='{.data.SECRET_KEY}' 2>/dev/null | base64 -d 2>/dev/null)
			if [[ -z $K8S_SECRET ]]; then
				K8S_SECRET=$(kubectl get secret api-secrets -n "$NAMESPACE" -o jsonpath='{.data.secret-key}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
			fi
			echo -e "  Secret Key: ${K8S_SECRET}"
		else
			echo -e "  ${YELLOW}⚠️  api-secrets secret not found${NC}"
		fi

		echo ""
		echo -e "${GREEN}Grafana (Monitoring):${NC}"
		if kubectl get namespace monitoring &>/dev/null; then
			# Try different possible Grafana secret names and field names
			if kubectl get secret grafana-admin-secret -n monitoring &>/dev/null 2>&1; then
				# Try with 'admin-user' and 'admin-password' fields (hyphenated)
				GRAFANA_USER=$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-user}' 2>/dev/null | base64 -d 2>/dev/null)
				GRAFANA_PASS=$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null)

				# If that didn't work, try with underscores
				if [[ -z $GRAFANA_USER ]]; then
					GRAFANA_USER=$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin_user}' 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
				fi
				if [[ -z $GRAFANA_PASS ]]; then
					GRAFANA_PASS=$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin_password}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
				fi

				echo -e "  Username: ${GRAFANA_USER:-admin}"
				echo -e "  Password: ${GRAFANA_PASS}"
			elif kubectl get secret grafana-admin-credentials -n monitoring &>/dev/null 2>&1; then
				GRAFANA_USER=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.admin-user}' 2>/dev/null | base64 -d 2>/dev/null || echo "admin")
				GRAFANA_PASS=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
				echo -e "  Username: ${GRAFANA_USER}"
				echo -e "  Password: ${GRAFANA_PASS}"
			elif kubectl get secret grafana -n monitoring &>/dev/null 2>&1; then
				GRAFANA_PASS=$(kubectl get secret grafana -n monitoring -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || echo "N/A")
				echo -e "  Username: admin"
				echo -e "  Password: ${GRAFANA_PASS}"
			elif kubectl get deployment grafana -n monitoring &>/dev/null 2>&1; then
				# Extract from deployment environment variables
				GRAFANA_PASS=$(kubectl get deployment grafana -n monitoring -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GF_SECURITY_ADMIN_PASSWORD")].value}' 2>/dev/null || echo "N/A")
				if [[ $GRAFANA_PASS != "N/A" && -n $GRAFANA_PASS ]]; then
					echo -e "  Username: admin"
					echo -e "  Password: ${GRAFANA_PASS}"
				else
					echo -e "  ${YELLOW}⚠️  Could not extract Grafana password${NC}"
					echo -e "  ${YELLOW}Try: kubectl get secret -n monitoring | grep grafana${NC}"
				fi
			else
				echo -e "  ${YELLOW}⚠️  Grafana not found in monitoring namespace${NC}"
				echo -e "  ${YELLOW}Try: kubectl get secret -n monitoring${NC}"
			fi
		else
			echo -e "  ${YELLOW}⚠️  Monitoring namespace not found${NC}"
		fi
	fi
fi

# =============================================================================
# Connection Strings
# =============================================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔗 Connection Information${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Use Kubernetes secret values if available, otherwise fall back to terraform.tfvars
if kubectl cluster-info &>/dev/null && kubectl get namespace api-deployment-demo &>/dev/null; then
	# Get from Kubernetes secrets
	if kubectl get secret postgres-secrets -n api-deployment-demo &>/dev/null; then
		DB_USER_CONN=$(kubectl get secret postgres-secrets -n api-deployment-demo -o jsonpath='{.data.DB_USER}' 2>/dev/null | base64 -d 2>/dev/null || echo "postgres")
		DB_NAME_CONN=$(kubectl get secret postgres-secrets -n api-deployment-demo -o jsonpath='{.data.DB_NAME}' 2>/dev/null | base64 -d 2>/dev/null || echo "api_db")
		DB_PASS_CONN=$(kubectl get secret postgres-secrets -n api-deployment-demo -o jsonpath='{.data.DB_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

		if [[ -n $DB_PASS_CONN ]]; then
			echo -e "${GREEN}Database Connection String (from Kubernetes):${NC}"
			echo -e "  postgresql://${DB_USER_CONN}:${DB_PASS_CONN}@localhost:5432/${DB_NAME_CONN}"
			echo ""
		fi
	fi
elif [[ -f "terraform/terraform.tfvars" ]]; then
	# Fall back to terraform.tfvars
	DB_USER_CONN=$(grep 'db_user' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "postgres")
	DB_NAME_CONN=$(grep 'db_name' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2 || echo "api_db")
	DB_PASS_CONN=$(grep 'db_password' terraform/terraform.tfvars 2>/dev/null | cut -d'"' -f2)
	[[ -z $DB_USER_CONN ]] && DB_USER_CONN="postgres"
	[[ -z $DB_NAME_CONN ]] && DB_NAME_CONN="api_db"

	if [[ -n $DB_PASS_CONN && $DB_PASS_CONN != "REPLACE_WITH_SECURE_DB_PASSWORD" ]]; then
		echo -e "${GREEN}Database Connection String (from terraform.tfvars):${NC}"
		echo -e "  postgresql://${DB_USER_CONN}:${DB_PASS_CONN}@localhost:5432/${DB_NAME_CONN}"
		echo ""
	fi
fi

echo -e "${GREEN}Access URLs:${NC}"
echo -e "  Web (HTTPS):   https://localhost"
echo -e "  API:           http://localhost:8000"
echo -e "  API Docs:      http://localhost:8000/docs"
echo -e "  Grafana:       http://localhost:3000"
echo -e "  Prometheus:    http://localhost:9090"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}💡 Tips:${NC}"
echo -e "  • To regenerate passwords: ./scripts/generate-secrets.sh terraform"
echo -e "  • To apply new secrets:    make clean && make deploy"
echo -e "  • Security audit:          ./scripts/security-audit.sh"
echo ""
