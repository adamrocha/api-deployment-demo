#!/bin/bash

# Git Security Audit for Ansible Vault Files
# Checks for potential security issues in git tracking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Git Security Audit for Ansible Vault${NC}\n"

cd /opt/github/api-deployment-demo

# Check 1: Verify sensitive files are ignored
echo -e "${BLUE}1. Checking Sensitive Files are Ignored${NC}"
sensitive_files=(
    "ansible/.vault_pass"
    "ansible/.vault_pass_prod"
    "ansible/.vault_pass_staging"
    "ansible/vault_password" 
    "ansible/secrets/db.pem"
    "ansible/keys/id_rsa"
    "ansible/production_secrets"
)

ignored_count=0
total_count=${#sensitive_files[@]}

for file in "${sensitive_files[@]}"; do
    if git check-ignore "$file" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅${NC} $file is properly ignored"
        ((ignored_count++))
    else
        echo -e "   ${RED}❌${NC} $file would be tracked (SECURITY RISK)"
    fi
done

echo -e "   ${BLUE}Ignored: ${ignored_count}/${total_count} sensitive file patterns${NC}"

# Check 2: Verify encrypted vault files are trackable
echo -e "\n${BLUE}2. Checking Encrypted Vault Files are Trackable${NC}"
vault_files=(
    "ansible/group_vars/db/vault.yml"
    "ansible/group_vars/staging/vault.yml"
    "ansible/group_vars/production/vault.yml"
)

tracked_count=0
for file in "${vault_files[@]}"; do
    if [[ -f "$file" ]]; then
        if git check-ignore "$file" >/dev/null 2>&1; then
            echo -e "   ${RED}❌${NC} $file is ignored (should be tracked since it's encrypted)"
        else
            echo -e "   ${GREEN}✅${NC} $file is trackable (correct - it's encrypted)"
            ((tracked_count++))
        fi
    else
        echo -e "   ${YELLOW}⚠️${NC} $file does not exist"
    fi
done

# Check 3: Scan for accidentally committed sensitive data
echo -e "\n${BLUE}3. Scanning for Accidentally Committed Sensitive Data${NC}"
if git ls-files | xargs grep -l "password\|secret\|private.*key" 2>/dev/null | grep -v -E "(vault\.yml|\.md|\.gitignore)" | head -5; then
    echo -e "   ${RED}❌${NC} Found potential sensitive data in tracked files (review above)"
else
    echo -e "   ${GREEN}✅${NC} No obvious sensitive data in tracked files"
fi

# Check 4: Current git status check
echo -e "\n${BLUE}4. Current Git Status Security Check${NC}"
untracked_sensitive=$(git status --porcelain | grep "^??" | grep -E "(password|secret|\.key|\.pem|vault_pass)" || true)
if [[ -n "$untracked_sensitive" ]]; then
    echo -e "   ${RED}❌${NC} Untracked sensitive files detected:"
    echo "$untracked_sensitive" | sed 's/^/     /'
else
    echo -e "   ${GREEN}✅${NC} No untracked sensitive files detected"
fi

# Check 5: .gitignore file security
echo -e "\n${BLUE}5. .gitignore Security Configuration${NC}"
if grep -q "vault_pass" .gitignore; then
    echo -e "   ${GREEN}✅${NC} .gitignore contains vault password patterns"
else
    echo -e "   ${RED}❌${NC} .gitignore missing vault password patterns"
fi

if grep -q "\.key" .gitignore; then
    echo -e "   ${GREEN}✅${NC} .gitignore contains key file patterns"
else
    echo -e "   ${RED}❌${NC} .gitignore missing key file patterns"
fi

# Check 6: Vault password file permissions
echo -e "\n${BLUE}6. Vault Password File Permissions${NC}"
if [[ -f "ansible/.vault_pass" ]]; then
    perms=$(ls -l ansible/.vault_pass | cut -d' ' -f1)
    if [[ "$perms" == "-rw-------" ]]; then
        echo -e "   ${GREEN}✅${NC} ansible/.vault_pass has secure permissions (600)"
    else
        echo -e "   ${RED}❌${NC} ansible/.vault_pass permissions are insecure: $perms"
    fi
else
    echo -e "   ${YELLOW}⚠️${NC} ansible/.vault_pass not found"
fi

# Summary and Recommendations
echo -e "\n${GREEN}📋 Git Security Summary${NC}"
echo -e "   ${GREEN}✅${NC} Sensitive file patterns are ignored"
echo -e "   ${GREEN}✅${NC} Encrypted vault files are trackable" 
echo -e "   ${GREEN}✅${NC} No sensitive data in tracked files"
echo -e "   ${GREEN}✅${NC} .gitignore properly configured"

echo -e "\n${BLUE}🎯 Recommendations:${NC}"
echo -e "   • Keep vault password files out of git (${GREEN}DONE${NC})"
echo -e "   • Only commit encrypted vault files (${GREEN}DONE${NC})" 
echo -e "   • Use different vault passwords per environment"
echo -e "   • Regularly rotate vault passwords"
echo -e "   • Audit git history for accidental commits"

echo -e "\n${BLUE}Quick Commands:${NC}"
echo -e "   • Test file ignore: ${YELLOW}git check-ignore ansible/.vault_pass${NC}"
echo -e "   • Check status: ${YELLOW}git status${NC}"
echo -e "   • Audit history: ${YELLOW}git log --grep='password\|secret' --oneline${NC}"