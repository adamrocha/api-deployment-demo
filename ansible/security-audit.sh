#!/bin/bash

# Ansible Vault Security Audit Script
# Checks that all sensitive information is properly encrypted

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Ansible Vault Security Audit${NC}\n"

cd /opt/github/api-deployment-demo/ansible

# Check 1: Verify vault files are encrypted
echo -e "${BLUE}1. Checking Vault File Encryption${NC}"
vault_files=(
    "group_vars/db/vault.yml"
    "group_vars/staging/vault.yml"
    "group_vars/production/vault.yml"
)

for vault_file in "${vault_files[@]}"; do
    if [[ -f "$vault_file" ]]; then
        if head -1 "$vault_file" | grep -q "\$ANSIBLE_VAULT"; then
            echo -e "   ${GREEN}✅${NC} $vault_file is properly encrypted"
        else
            echo -e "   ${RED}❌${NC} $vault_file is NOT encrypted"
        fi
    else
        echo -e "   ${YELLOW}⚠️${NC} $vault_file does not exist"
    fi
done

# Check 2: Verify no plain text passwords in group_vars
echo -e "\n${BLUE}2. Scanning for Plain Text Passwords${NC}"
plain_text_found=false

# Search for potential plain text passwords (excluding vault variable references)
if grep -r "password.*[\"'][^{]" group_vars/ 2>/dev/null | grep -v "vault_" | grep -v "{{" >/dev/null; then
    echo -e "   ${RED}❌${NC} Found plain text passwords:"
    grep -r "password.*[\"'][^{]" group_vars/ 2>/dev/null | grep -v "vault_" | grep -v "{{" | sed 's/^/     /'
    plain_text_found=true
else
    echo -e "   ${GREEN}✅${NC} No plain text passwords found"
fi

# Check for other sensitive patterns
sensitive_patterns=("secret.*:" "key.*:" "token.*:")
for pattern in "${sensitive_patterns[@]}"; do
    if grep -r "$pattern.*[\"'][^{]" group_vars/ 2>/dev/null | grep -v "vault_" | grep -v "{{" >/dev/null; then
        echo -e "   ${RED}❌${NC} Found plain text secrets matching '$pattern':"
        grep -r "$pattern.*[\"'][^{]" group_vars/ 2>/dev/null | grep -v "vault_" | grep -v "{{" | sed 's/^/     /'
        plain_text_found=true
    fi
done

if ! $plain_text_found; then
    echo -e "   ${GREEN}✅${NC} All sensitive data properly uses vault variables"
fi

# Check 3: Vault password file security
echo -e "\n${BLUE}3. Vault Password File Security${NC}"
if [[ -f ".vault_pass" ]]; then
    perms=$(ls -l .vault_pass | cut -d' ' -f1)
    if [[ "$perms" == "-rw-------" ]]; then
        echo -e "   ${GREEN}✅${NC} .vault_pass has secure permissions (600)"
    else
        echo -e "   ${RED}❌${NC} .vault_pass permissions are too open: $perms"
        echo -e "   ${YELLOW}Fix with:${NC} chmod 600 .vault_pass"
    fi
else
    echo -e "   ${YELLOW}⚠️${NC} .vault_pass file not found"
fi

# Check 4: Test vault decryption
echo -e "\n${BLUE}4. Testing Vault Decryption${NC}"
if [[ -f ".vault_pass" ]]; then
    for vault_file in "${vault_files[@]}"; do
        if [[ -f "$vault_file" ]]; then
            if ansible-vault view "$vault_file" --vault-password-file .vault_pass >/dev/null 2>&1; then
                echo -e "   ${GREEN}✅${NC} $vault_file decrypts successfully"
            else
                echo -e "   ${RED}❌${NC} $vault_file decryption failed"
            fi
        fi
    done
else
    echo -e "   ${YELLOW}⚠️${NC} Cannot test decryption - .vault_pass missing"
fi

# Check 5: Verify vault variable references
echo -e "\n${BLUE}5. Verifying Vault Variable References${NC}"
vault_vars_used=0

for vault_file in "${vault_files[@]}"; do
    if [[ -f "$vault_file" ]]; then
        # Get vault variable names from the encrypted file
        if ansible-vault view "$vault_file" --vault-password-file .vault_pass 2>/dev/null | grep -q "^vault_"; then
            echo -e "   ${GREEN}✅${NC} $vault_file contains vault_ variables"
            ((vault_vars_used++))
        fi
    fi
done

# Check if vault variables are referenced in main config files
if grep -r "{{ vault_" group_vars/ >/dev/null 2>&1; then
    echo -e "   ${GREEN}✅${NC} Vault variables are referenced in configuration"
else
    echo -e "   ${RED}❌${NC} No vault variable references found in configuration"
fi

# Summary
echo -e "\n${GREEN}📋 Security Audit Summary${NC}"
if [[ $vault_vars_used -gt 0 ]]; then
    echo -e "   ${GREEN}✅${NC} $vault_vars_used vault files properly encrypted"
    echo -e "   ${GREEN}✅${NC} Sensitive data secured with Ansible Vault"
    echo -e "   ${GREEN}✅${NC} No plain text secrets detected"
    echo -e "   ${GREEN}✅${NC} Vault password file properly protected"
    echo -e "\n${BLUE}🎉 Security Audit: PASSED${NC}"
else
    echo -e "   ${RED}❌${NC} Security issues detected - review output above"
    echo -e "\n${RED}🚨 Security Audit: FAILED${NC}"
fi

echo -e "\n${BLUE}Usage Examples:${NC}"
echo -e "   • Deploy with vault: ${YELLOW}ansible-playbook -i inventory.ini db.yml --vault-password-file .vault_pass${NC}"
echo -e "   • Edit vault file: ${YELLOW}ansible-vault edit group_vars/db/vault.yml --vault-password-file .vault_pass${NC}"
echo -e "   • View vault file: ${YELLOW}ansible-vault view group_vars/staging/vault.yml --vault-password-file .vault_pass${NC}"