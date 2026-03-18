#!/bin/bash

# Terraform & Kubernetes Security Audit Script
# Checks for exposed secrets, hardcoded passwords, and security misconfigurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Security Audit - Terraform & Kubernetes${NC}\n"

cd /opt/github/api-deployment-demo

ISSUES_FOUND=0

# =============================================================================
# 1. Check for terraform.tfvars in git
# =============================================================================
echo -e "${BLUE}1. Checking Git Repository for Exposed Secrets${NC}"
echo "   Scanning for terraform.tfvars..."

if git ls-files | grep -q "terraform.tfvars$"; then
	echo -e "   ${RED}❌ terraform.tfvars is tracked in git!${NC}"
	echo -e "   ${YELLOW}   This file contains secrets and should NOT be committed${NC}"
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} terraform.tfvars is not tracked in git"
fi

# Check git history for accidentally committed secrets
echo "   Checking git history for terraform.tfvars..."
if git log --all --full-history -- "terraform/terraform.tfvars" 2>/dev/null | grep -q "commit"; then
	echo -e "   ${YELLOW}⚠️  terraform.tfvars was previously committed to git${NC}"
	echo -e "   ${YELLOW}   Consider removing from history: git filter-branch${NC}"
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} terraform.tfvars has never been committed"
fi

# =============================================================================
# 2. Check for hardcoded passwords in Terraform
# =============================================================================
echo -e "\n${BLUE}2. Scanning Terraform Files for Hardcoded Credentials${NC}"

# Check for password = "..." patterns (excluding variables, examples, documentation, and terraform.tfvars)
if grep -r 'password\s*=\s*"[^$]' terraform/ 2>/dev/null | grep -v "var\." | grep -v "example" | grep -v "random_password" | grep -v "SECRETS.md" | grep -v "README.md" | grep -v "REPLACE_WITH" | grep -v "terraform.tfvars" >/dev/null; then
	echo -e "   ${RED}❌ Found hardcoded passwords in Terraform .tf files:${NC}"
	grep -r 'password\s*=\s*"[^$]' terraform/ 2>/dev/null | grep -v "var\." | grep -v "example" | grep -v "random_password" | grep -v "SECRETS.md" | grep -v "README.md" | grep -v "REPLACE_WITH" | grep -v "terraform.tfvars" | sed 's/^/      /'
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} No hardcoded passwords found in Terraform .tf files"
fi

# Check for weak default values in variables.tf
echo "   Checking for weak default values..."
if grep -E 'default\s*=\s*"(admin|password|secret|123456)"' terraform/variables.tf >/dev/null 2>&1; then
	echo -e "   ${RED}❌ Found weak default values in variables.tf:${NC}"
	grep -E 'default\s*=\s*"(admin|password|secret|123456)"' terraform/variables.tf | sed 's/^/      /'
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} No weak default values in variables.tf"
fi

# =============================================================================
# 3. Check terraform.tfvars file permissions and content
# =============================================================================
echo -e "\n${BLUE}3. Checking terraform.tfvars Security${NC}"

if [[ -f "terraform/terraform.tfvars" ]]; then
	# Check file permissions
	perms=$(ls -l terraform/terraform.tfvars | awk '{print $1}')
	if [[ $perms == "-rw-------" ]]; then
		echo -e "   ${GREEN}✅${NC} terraform.tfvars has secure permissions (600)"
	else
		echo -e "   ${YELLOW}⚠️  terraform.tfvars permissions: $perms${NC}"
		echo -e "   ${YELLOW}   Recommended: chmod 600 terraform/terraform.tfvars${NC}"
		((ISSUES_FOUND++))
	fi

	# Check for placeholder values
	if grep -E '(CHANGE_ME|TODO|REPLACEME|xxx|password123)' terraform/terraform.tfvars >/dev/null 2>&1; then
		echo -e "   ${YELLOW}⚠️  Found placeholder values in terraform.tfvars${NC}"
		echo -e "   ${YELLOW}   Run: ./scripts/generate-secrets.sh terraform${NC}"
		((ISSUES_FOUND++))
	else
		echo -e "   ${GREEN}✅${NC} No placeholder values detected"
	fi

	# Check for empty password fields
	if grep -E '(db_password|secret_key|grafana_password)\s*=\s*""' terraform/terraform.tfvars >/dev/null 2>&1; then
		echo -e "   ${RED}❌ Found empty password fields in terraform.tfvars${NC}"
		grep -E '(db_password|secret_key|grafana_password)\s*=\s*""' terraform/terraform.tfvars | sed 's/^/      /'
		((ISSUES_FOUND++))
	else
		echo -e "   ${GREEN}✅${NC} All password fields are populated"
	fi
else
	echo -e "   ${YELLOW}⚠️  terraform.tfvars does not exist${NC}"
	echo -e "   ${YELLOW}   Generate it: ./scripts/generate-secrets.sh terraform${NC}"
	((ISSUES_FOUND++))
fi

# =============================================================================
# 4. Check Kubernetes secrets
# =============================================================================
echo -e "\n${BLUE}4. Checking Kubernetes Secrets Configuration${NC}"

# Check if kubectl is available
if command -v kubectl &>/dev/null; then
	if kubectl cluster-info &>/dev/null; then
		# Check for secrets in api-deployment-demo namespace
		if kubectl get namespace api-deployment-demo &>/dev/null; then
			secret_count=$(kubectl get secrets -n api-deployment-demo 2>/dev/null | grep -v "default-token" | tail -n +2 | wc -l | tr -d ' ')

			if [[ $secret_count -gt 0 ]]; then
				echo -e "   ${GREEN}✅${NC} Found $secret_count Kubernetes secret(s)"

				# Check for required secrets
				required_secrets=("api-secrets" "db-secrets" "tls-secret")
				for secret in "${required_secrets[@]}"; do
					if kubectl get secret "$secret" -n api-deployment-demo &>/dev/null; then
						echo -e "   ${GREEN}✅${NC} Secret '$secret' exists"
					else
						echo -e "   ${YELLOW}⚠️  Secret '$secret' not found${NC}"
					fi
				done
			else
				echo -e "   ${YELLOW}⚠️  No secrets found in api-deployment-demo namespace${NC}"
				echo -e "   ${YELLOW}   Deploy with: make deploy${NC}"
			fi
		else
			echo -e "   ${YELLOW}⚠️  Namespace 'api-deployment-demo' not found${NC}"
			echo -e "   ${YELLOW}   Deploy with: make deploy${NC}"
		fi
	else
		echo -e "   ${YELLOW}⚠️  Kubernetes cluster not accessible${NC}"
	fi
else
	echo -e "   ${YELLOW}⚠️  kubectl not installed, skipping Kubernetes checks${NC}"
fi

# =============================================================================
# 5. Check for exposed secrets in configuration files
# =============================================================================
echo -e "\n${BLUE}5. Scanning Configuration Files for Exposed Secrets${NC}"

# Check docker-compose.yml for hardcoded passwords
if grep -E 'POSTGRES_PASSWORD:\s*[^$]' docker-compose.yml 2>/dev/null | grep -v '${' >/dev/null; then
	echo -e "   ${RED}❌ Found hardcoded password in docker-compose.yml${NC}"
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} docker-compose.yml uses environment variables"
fi

# Check Ansible files for plain text secrets
if find ansible/ -name "*.yml" -exec grep -l "password:\s*[\"'][^{$]" {} \; 2>/dev/null | grep -v vault | grep -v example >/dev/null; then
	echo -e "   ${YELLOW}⚠️  Found potential plain text passwords in Ansible files:${NC}"
	find ansible/ -name "*.yml" -exec grep -l "password:\s*[\"'][^{$]" {} \; 2>/dev/null | grep -v vault | grep -v example | sed 's/^/      /'
	((ISSUES_FOUND++))
else
	echo -e "   ${GREEN}✅${NC} No plain text passwords in Ansible files"
fi

# =============================================================================
# 6. Check .gitignore coverage
# =============================================================================
echo -e "\n${BLUE}6. Verifying .gitignore Configuration${NC}"

required_patterns=("*.tfvars" ".vault_pass" "*.pem" "*.key" ".env")
missing_patterns=()

for pattern in "${required_patterns[@]}"; do
	# Check if pattern exists in .gitignore (handles wildcards and path-specific entries)
	if grep -F "$pattern" .gitignore 2>/dev/null >/dev/null; then
		echo -e "   ${GREEN}✅${NC} '$pattern' is in .gitignore"
	else
		echo -e "   ${YELLOW}⚠️  '$pattern' not found in .gitignore${NC}"
		missing_patterns+=("$pattern")
		((ISSUES_FOUND++))
	fi
done

if [[ ${#missing_patterns[@]} -gt 0 ]]; then
	echo -e "\n   ${YELLOW}Add to .gitignore:${NC}"
	for pattern in "${missing_patterns[@]}"; do
		echo -e "      $pattern"
	done
fi

# =============================================================================
# 7. Check file permissions on sensitive files
# =============================================================================
echo -e "\n${BLUE}7. Checking File Permissions on Sensitive Files${NC}"

sensitive_files=(
	"nginx/ssl/nginx-selfsigned.key"
	"terraform/terraform.tfvars"
)

for file in "${sensitive_files[@]}"; do
	if [[ -f $file ]]; then
		perms=$(ls -l "$file" | awk '{print $1}')
		if [[ $perms =~ ^-rw------- ]]; then
			echo -e "   ${GREEN}✅${NC} $file has secure permissions"
		else
			echo -e "   ${YELLOW}⚠️  $file permissions: $perms (recommend 600)${NC}"
			((ISSUES_FOUND++))
		fi
	fi
done

# =============================================================================
# SUMMARY
# =============================================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Security Audit Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [[ $ISSUES_FOUND -eq 0 ]]; then
	echo -e "${GREEN}🎉 Security Audit: PASSED${NC}"
	echo -e "${GREEN}✅ No security issues detected${NC}\n"
else
	echo -e "${YELLOW}⚠️  Security Audit: $ISSUES_FOUND issue(s) found${NC}"
	echo -e "${YELLOW}Review the output above for details${NC}\n"
fi

echo -e "${BLUE}💡 Security Best Practices:${NC}"
echo -e "   • Generate secrets: ${YELLOW}./scripts/generate-secrets.sh terraform${NC}"
echo -e "   • Verify .gitignore: ${YELLOW}git status --ignored${NC}"
echo -e "   • Check git history: ${YELLOW}git log --all --full-history -- '*tfvars'${NC}"
echo -e "   • Rotate secrets regularly and use strong random passwords"
echo -e "   • Never commit terraform.tfvars, .vault_pass, or private keys${NC}\n"

exit $ISSUES_FOUND
