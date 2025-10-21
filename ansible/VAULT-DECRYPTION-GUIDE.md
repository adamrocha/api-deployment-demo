# 🔐 How Ansible Vault Decryption Works

## **Decryption Process Overview**

Ansible Vault uses **AES-256-CBC encryption** with **HMAC-SHA256** authentication to secure sensitive data. Here's how the decryption process works:

### **1. File Format Structure**

```
$ANSIBLE_VAULT;1.1;AES256
38393166383934353062313532633264613065666633343964343065666436653632363037623239
6636306539653834353833663461366533356630633330620a363732346634336136393066616136
63363061623730656237363166323135316163363034343637663937356465386264366432393937
3833343163366335340a313261356463313738333332383061373438636630633761396365376363
```

- **Header**: `$ANSIBLE_VAULT;1.1;AES256`
- **Salt**: First 32 hex characters of line 2
- **HMAC**: Next 64 hex characters  
- **Encrypted Data**: Remaining hex-encoded content

### **2. Decryption Methods**

#### **Method 1: Password File (Recommended for Automation)**
```bash
ansible-vault view vault.yml --vault-password-file .vault_pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
```

#### **Method 2: Interactive Prompt**
```bash
ansible-vault view vault.yml --ask-vault-pass
ansible-playbook playbook.yml --ask-vault-pass
```

#### **Method 3: Environment Variable**
```bash
export ANSIBLE_VAULT_PASSWORD="your_password"
ansible-vault view vault.yml --vault-password-file <(echo $ANSIBLE_VAULT_PASSWORD)
```

#### **Method 4: Script-based Password Provider**
```bash
#!/bin/bash
# vault-password-script.sh
echo "password_from_secure_source"
```
```bash
ansible-playbook playbook.yml --vault-password-file ./vault-password-script.sh
```

### **3. Automatic Decryption During Playbook Execution**

When Ansible runs a playbook:

1. **Detection**: Ansible automatically detects vault-encrypted files by the `$ANSIBLE_VAULT` header
2. **Decryption**: Uses the provided password to decrypt files in memory
3. **Variable Loading**: Decrypted variables become available as normal Ansible variables
4. **Template Rendering**: Vault variables are resolved in Jinja2 templates like `{{ vault_db_password }}`
5. **Security**: Decrypted content is never written to disk - only kept in memory

### **4. Key Derivation Process**

```
1. User Password → PBKDF2 → Master Key
2. Master Key + Salt → AES-256 Key + HMAC Key  
3. AES Key decrypts data, HMAC Key verifies integrity
```

### **5. Multiple Vault IDs (Advanced)**

For complex environments, you can use different vault passwords:

```bash
# Encrypt with different vault IDs
ansible-vault encrypt --vault-id dev@.vault_pass_dev vault_dev.yml
ansible-vault encrypt --vault-id prod@.vault_pass_prod vault_prod.yml

# Run with multiple vault passwords
ansible-playbook playbook.yml --vault-id dev@.vault_pass_dev --vault-id prod@.vault_pass_prod
```

### **6. Security Best Practices**

#### **Password File Security:**
```bash
chmod 600 .vault_pass          # Read-write for owner only
chown $USER:$USER .vault_pass   # Owner-only access
```

#### **Password Strength:**
- Minimum 12 characters
- Include uppercase, lowercase, numbers, symbols
- Use password managers for generation
- Rotate regularly

#### **Environment Separation:**
```bash
# Different passwords per environment
.vault_pass_dev      # Development password
.vault_pass_staging  # Staging password  
.vault_pass_prod     # Production password
```

### **7. Common Vault Operations**

```bash
# View encrypted file
ansible-vault view group_vars/db/vault.yml --vault-password-file .vault_pass

# Edit encrypted file
ansible-vault edit group_vars/db/vault.yml --vault-password-file .vault_pass

# Encrypt new file
ansible-vault encrypt group_vars/new/secrets.yml --vault-password-file .vault_pass

# Decrypt file (temporarily)
ansible-vault decrypt group_vars/db/vault.yml --vault-password-file .vault_pass

# Change vault password
ansible-vault rekey group_vars/db/vault.yml --vault-password-file .vault_pass

# Encrypt string value
ansible-vault encrypt_string 'secret_password' --name 'vault_password'
```

### **8. Integration with CI/CD**

```bash
# GitLab CI example
script:
  - echo "$VAULT_PASSWORD" > .vault_pass
  - chmod 600 .vault_pass
  - ansible-playbook deploy.yml --vault-password-file .vault_pass
  - rm .vault_pass
```

### **9. Troubleshooting Decryption Issues**

#### **Common Error: "Decryption failed"**
```bash
# Check password file
cat .vault_pass

# Verify file is actually encrypted
head -1 group_vars/db/vault.yml

# Test decryption manually
ansible-vault view group_vars/db/vault.yml --vault-password-file .vault_pass
```

#### **Common Error: "Vault format unhashable type"**
- Usually means password is incorrect
- Check for extra whitespace in password file

### **10. Performance Considerations**

- **Memory Usage**: Large vault files are decrypted into memory
- **CPU Impact**: PBKDF2 key derivation adds ~100ms per file
- **Network**: Encrypted files are smaller than plain text
- **Caching**: Ansible caches decrypted content per task run

This comprehensive decryption process ensures that sensitive data remains encrypted at rest while being seamlessly available during Ansible execution.