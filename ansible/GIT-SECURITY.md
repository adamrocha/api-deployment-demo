# Git Security Configuration for Ansible Vault

## 🔐 **Critical Security: What's Ignored by Git**

### ✅ **IGNORED (Not Tracked) - Security Critical:**

#### **Vault Password Files:**
- `ansible/.vault_pass` - Main vault password
- `ansible/.vault_pass_*` - Environment-specific vault passwords  
- `ansible/vault_pass*` - Any vault password variations
- `ansible/.ansible_vault_password` - Alternative naming

#### **SSH Keys and Certificates:**
- `ansible/**/*.pem` - SSH private keys
- `ansible/**/*.key` - Private keys
- `ansible/**/*.crt` - Certificates (if private)
- `ansible/**/id_rsa*` - RSA keys
- `ansible/**/id_ed25519*` - Ed25519 keys

#### **Sensitive Configuration:**
- `ansible/inventories/production/` - Production inventory
- `ansible/production_*` - Production-specific files
- `ansible/secrets/` - Secrets directory
- `ansible/**/*secret*` - Files with 'secret' in name
- `ansible/**/*password*` - Files with 'password' in name

#### **Temporary/Cache Files:**
- `ansible/.ansible/` - Ansible cache
- `ansible/ansible.log` - Log files
- `ansible/**/*.log` - Any log files
- `ansible/tmp/` - Temporary directories

### ✅ **TRACKED (Version Controlled) - Safe to Commit:**

#### **Encrypted Vault Files:**
- `ansible/group_vars/db/vault.yml` - ✅ ENCRYPTED with Ansible Vault
- `ansible/group_vars/staging/vault.yml` - ✅ ENCRYPTED with Ansible Vault  
- `ansible/group_vars/production/vault.yml` - ✅ ENCRYPTED with Ansible Vault

#### **Configuration Files:**
- `ansible/group_vars/all.yml` - Non-sensitive global config
- `ansible/group_vars/staging.yml` - Non-sensitive staging config
- `ansible/inventory.ini` - Server inventory (no secrets)
- `ansible/site.yml` - Main playbook
- `ansible/roles/` - All role definitions

#### **Documentation:**
- `ansible/*.md` - Documentation files
- `ansible/.vault_pass_example` - Example file (no real password)

## 🚨 **Security Verification Commands**

### Check if sensitive files are properly ignored:
```bash
# Test vault password files
git check-ignore ansible/.vault_pass          # Should be ignored
git check-ignore ansible/.vault_pass_prod     # Should be ignored

# Test SSH keys  
git check-ignore ansible/keys/id_rsa          # Should be ignored
git check-ignore ansible/ssl/server.key       # Should be ignored

# Test encrypted vault files (should NOT be ignored)
git check-ignore ansible/group_vars/db/vault.yml  # Should NOT be ignored
```

### Verify current status:
```bash
# Show what would be committed
git status

# Check for accidentally tracked sensitive files
git ls-files | grep -E "(password|secret|\.key|\.pem|vault_pass)"
```

## ⚠️ **Emergency: If Sensitive Data Was Committed**

### If you accidentally committed a vault password file:

```bash
# 1. Remove from staging
git reset HEAD ansible/.vault_pass

# 2. Remove from history (if already committed)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch ansible/.vault_pass' \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push (DANGEROUS - coordinate with team)
git push --force-with-lease --all

# 4. Change the vault password immediately
ansible-vault rekey ansible/group_vars/db/vault.yml
```

### If you accidentally committed unencrypted secrets:

```bash
# 1. Immediately rotate all exposed credentials
# 2. Remove from git history using BFG Repo-Cleaner or git filter-branch
# 3. Force push after team coordination
# 4. Update all affected systems with new credentials
```

## 📋 **Best Practices Checklist**

- [ ] Vault password files have 600 permissions
- [ ] Vault password files are in .gitignore
- [ ] All sensitive data is in encrypted vault files
- [ ] Production vault uses different password than dev/staging  
- [ ] SSH keys are not committed to repository
- [ ] Regular audit of git history for sensitive data
- [ ] Team training on vault security practices

## 🔍 **Regular Security Audit**

Run this monthly to check for security issues:

```bash
# Check for sensitive patterns in git history
git log --all --source --grep="password\|secret\|key" --oneline

# Check for sensitive files in current tree
git ls-files | xargs grep -l "password\|secret" | grep -v vault.yml

# Verify .gitignore is working
./ansible/security-audit.sh
```