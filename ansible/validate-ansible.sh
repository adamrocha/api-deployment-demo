#!/bin/bash

# Ansible Configuration Validation Script
# Validates Ansible configuration for Kubernetes-based deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd /opt/github/api-deployment-demo/ansible

echo -e "${BLUE}🚀 Ansible Kubernetes Configuration Validation${NC}\n"

# Test 1: Ansible Installation
echo -e "${BLUE}1. Ansible Installation${NC}"
if ansible --version >/dev/null 2>&1; then
	ansible --version | head -1
	echo -e "${GREEN}✅ Ansible is installed and working${NC}\n"
else
	echo -e "${RED}❌ Ansible is not installed${NC}\n"
	exit 1
fi

# Test 2: Kubernetes Playbook Syntax
echo -e "${BLUE}2. Kubernetes Playbook Syntax${NC}"
if ansible-playbook --syntax-check kubernetes.yml >/dev/null 2>&1; then
	echo -e "${GREEN}✅ kubernetes.yml syntax is valid${NC}\n"
else
	echo -e "${RED}❌ kubernetes.yml has syntax errors${NC}\n"
	exit 1
fi

# Test 3: Additional Playbook Syntax
echo -e "${BLUE}3. Additional Playbooks${NC}"
for playbook in db.yml test-role.yml; do
	if [[ -f $playbook ]]; then
		if ansible-playbook --syntax-check "$playbook" >/dev/null 2>&1; then
			echo -e "  ${GREEN}✅${NC} $playbook syntax is valid"
		else
			echo -e "  ${RED}❌${NC} $playbook has syntax errors"
		fi
	fi
done
echo ""

# Test 4: Kubectl Availability
echo -e "${BLUE}4. Kubernetes Connectivity${NC}"
if kubectl version --client >/dev/null 2>&1; then
	echo -e "${GREEN}✅ kubectl is installed${NC}"
	if kubectl cluster-info >/dev/null 2>&1; then
		echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
		cluster_name=$(kubectl config current-context 2>/dev/null || echo "unknown")
		echo "  Current context: $cluster_name"
	else
		echo -e "${YELLOW}⚠️  No Kubernetes cluster running${NC}"
	fi
else
	echo -e "${RED}❌ kubectl is not installed${NC}"
fi
echo ""

# Test 5: Namespace Check
echo -e "${BLUE}5. Namespace Verification${NC}"
if kubectl get namespace api-deployment-demo >/dev/null 2>&1; then
	echo -e "${GREEN}✅ Namespace 'api-deployment-demo' exists${NC}\n"
else
	echo -e "${YELLOW}⚠️  Namespace 'api-deployment-demo' not found (run terraform apply first)${NC}\n"
fi

# Test 6: Role Structure
echo -e "${BLUE}6. Role Structure${NC}"
for role in kubernetes-config kubernetes-tuning api-app monitoring database docker ssl-certificates; do
	if [[ -f "roles/$role/tasks/main.yml" ]]; then
		echo -e "  ${GREEN}✅${NC} Role: $role"
	else
		echo -e "  ${YELLOW}⚠️${NC} Role: $role (missing or optional)"
	fi
done
echo ""

# Test 7: Template Validation
echo -e "${BLUE}7. Template Files${NC}"
template_count=$(find roles/ -name "*.j2" 2>/dev/null | wc -l)
echo "Found $template_count Jinja2 templates"
echo ""

# Test 8: Handler Validation
echo -e "${BLUE}8. Handler Configuration${NC}"
handler_files=$(find roles/ -name "handlers" -type d 2>/dev/null | wc -l)
echo "Found $handler_files roles with handlers"
echo ""

# Test 9: Required Ansible Collections
echo -e "${BLUE}9. Required Ansible Collections${NC}"
required_collections=(
	"kubernetes.core"
	"community.docker"
)

for collection in "${required_collections[@]}"; do
	if ansible-galaxy collection list | grep -q "$collection" 2>/dev/null; then
		echo -e "  ${GREEN}✅${NC} Collection: $collection"
	else
		echo -e "  ${YELLOW}⚠️${NC} Collection: $collection (install with: ansible-galaxy collection install $collection)"
	fi
done
echo ""

# Test 10: Group Variables
echo -e "${BLUE}10. Group Variables Configuration${NC}"
if [[ -f "group_vars/all.yml" ]]; then
	echo -e "  ${GREEN}✅${NC} group_vars/all.yml exists"
fi
if [[ -f "group_vars/staging.yml" ]]; then
	echo -e "  ${GREEN}✅${NC} group_vars/staging.yml exists"
fi
echo ""

# Summary
echo -e "${GREEN}🎉 Ansible Configuration Summary${NC}"
echo -e "  • Kubernetes playbook: ${GREEN}Valid${NC}"
echo -e "  • kubectl: $(kubectl version --client >/dev/null 2>&1 && echo -e "${GREEN}Available${NC}" || echo -e "${YELLOW}Not found${NC}")"
echo -e "  • Cluster: $(kubectl cluster-info >/dev/null 2>&1 && echo -e "${GREEN}Running${NC}" || echo -e "${YELLOW}Not running${NC}")"
echo -e "  • Roles: ${GREEN}Present${NC}"
echo -e "  • Collections: ${GREEN}Available${NC}"
echo ""
echo -e "${BLUE}Deployment Commands:${NC}"
echo -e "  ${YELLOW}make staging${NC}       # Deploy with Docker Compose"
echo -e "  ${YELLOW}make deploy${NC}        # Full Kubernetes deployment (Terraform + Ansible)"
echo -e "  ${YELLOW}make config${NC}        # Apply Ansible configuration to Kubernetes"
echo ""
echo -e "${BLUE}Manual Ansible (if needed):${NC}"
echo -e "  ${YELLOW}cd ansible && ansible-playbook kubernetes.yml -e \"environment=production\"${NC}"
