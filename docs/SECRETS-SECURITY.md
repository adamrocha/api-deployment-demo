# Secrets Security Guide

## 🔐 Overview

This guide outlines security best practices for managing secrets, credentials, and sensitive data in the API Deployment Demo project.

## Table of Contents

- [Security Principles](#security-principles)
- [Secret Types](#secret-types)
- [Storage and Management](#storage-and-management)
- [Terraform Secrets](#terraform-secrets)
- [Kubernetes Secrets](#kubernetes-secrets)
- [Ansible Vault](#ansible-vault)
- [Docker Secrets](#docker-secrets)
- [Pre-commit Hooks](#pre-commit-hooks)
- [Secret Rotation](#secret-rotation)
- [Incident Response](#incident-response)
- [Tools and Resources](#tools-and-resources)

---

## Security Principles

### Core Principles

1. **Never commit secrets to version control**
   - All secret files are in `.gitignore`
   - Use example files with placeholder values
   - Scan commits before pushing

2. **Use strong, unique secrets**
   - Minimum 32 characters
   - Cryptographically random
   - Different for each environment

3. **Principle of least privilege**
   - Grant minimal necessary access
   - Use RBAC for Kubernetes secrets
   - Separate secrets per service

4. **Encryption at rest and in transit**
   - Enable encryption for Kubernetes secrets
   - Use TLS for all network communication
   - Encrypt backup storage

5. **Regular rotation**
   - Rotate secrets every 90 days
   - Immediate rotation after incidents
   - Automated rotation where possible

---

## Secret Types

### Current Secrets in Project

| Secret Type | Location | Environments | Rotation Frequency |
| --- | --- | --- | --- |
| Database Password | `terraform.tfvars`, K8s secrets | All | 90 days |
| API Secret Key | `terraform.tfvars`, K8s secrets | All | 90 days |
| TLS Certificates | `nginx/ssl/`, K8s secrets | Production | 365 days |
| Monitoring Passwords | Ansible Vault, K8s secrets | Production | 90 days |
| SSH Keys | Ansible Vault | Production | 180 days |

---

## Storage and Management

### Local Development

**✅ DO:**

- Use `.env` files (in `.gitignore`)
- Use example files for documentation
- Keep secrets in password manager
- Use secure file permissions (600/400)

**❌ DON'T:**

- Commit secrets to git
- Share secrets via email/chat
- Store in plaintext notes
- Use weak/default passwords

### Production Environments

**Recommended Solutions:**

1. **HashiCorp Vault** (Best for multi-cloud)

   ```bash
   # Store secret
   vault kv put secret/api/production \
     db_password="..." \
     secret_key="..."
   
   # Retrieve in Terraform
   data "vault_generic_secret" "api" {
     path = "secret/api/production"
   }
   ```

2. **AWS Secrets Manager**

   ```bash
   # Store secret
   aws secretsmanager create-secret \
     --name api/production/db_password \
     --secret-string "..."
   
   # Retrieve in application
   aws secretsmanager get-secret-value \
     --secret-id api/production/db_password
   ```

3. **Kubernetes External Secrets**

   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: database-credentials
   spec:
     secretStoreRef:
       name: vault-backend
     target:
       name: database-credentials
     data:
       - secretKey: db-password
         remoteRef:
           key: secret/api/production
           property: db_password
   ```

---

## Terraform Secrets

Secrets are managed via variables in `terraform.tfvars`:

```hcl
# terraform.tfvars (NOT in version control)
db_password = "your-secure-password"
secret_key  = "your-secure-secret-key"
```

### Security Features

1. **Sensitive Variable Marking**

   ```hcl
   variable "db_password" {
     description = "Database password"
     type        = string
     sensitive   = true  # Prevents logging
   }
   ```

2. **Immutable Kubernetes Secrets**

   ```hcl
   resource "kubernetes_secret" "database" {
     # ...
     immutable = true  # Prevents accidental modification
     
     lifecycle {
       prevent_destroy = false  # Set to true in production
       ignore_changes  = [metadata[0].annotations]
     }
   }
   ```

3. **State File Protection**

   ```hcl
   # Backend configuration for remote state
   terraform {
     backend "s3" {
       bucket         = "terraform-state"
       key            = "api-demo/terraform.tfstate"
       encrypt        = true
       dynamodb_table = "terraform-locks"
     }
   }
   ```

### Generating Secure Secrets

```bash
# Option 1: OpenSSL
openssl rand -base64 32

# Option 2: Python
python3 -c 'import secrets; print(secrets.token_urlsafe(32))'

# Option 3: pwgen
pwgen -s 32 1

# Option 4: Using /dev/urandom
head -c 32 /dev/urandom | base64
```

### Migration to External Secrets

For production, migrate to external secret management:

```hcl
# Example: Using AWS Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "api/production/db_password"
}

resource "kubernetes_secret" "database" {
  data = {
    db-password = data.aws_secretsmanager_secret_version.db_password.secret_string
  }
}
```

---

## Kubernetes Secrets

1. **Enable Encryption at Rest**

   ```yaml
   # /etc/kubernetes/encryption-config.yaml
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
     - resources:
       - secrets
       providers:
       - aescbc:
           keys:
           - name: key1
             secret: <base64-encoded-secret>
       - identity: {}
   ```

2. **RBAC Restrictions**

   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     name: secret-reader
   rules:
   - apiGroups: [""]
     resources: ["secrets"]
     resourceNames: ["database-credentials"]
     verbs: ["get"]
   ```

3. **Use Immutable Secrets**

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: database-credentials
   type: Opaque
   immutable: true  # Requires replacement to update
   data:
     db-password: <base64-encoded>
   ```

4. **Audit Logging**

   ```yaml
   # Enable audit logging for secret access
   apiVersion: audit.k8s.io/v1
   kind: Policy
   rules:
   - level: RequestResponse
     resources:
     - group: ""
       resources: ["secrets"]
   ```

### Scanning for Exposed Secrets

```bash
# Check secrets aren't in plain YAML files
grep -r "stringData:" kubernetes/

# Verify secrets are base64 encoded
kubectl get secrets -o json | jq '.items[].data'

# Check secret permissions
kubectl auth can-i get secrets --as=system:serviceaccount:default:default
```

---

## Ansible Vault

Sensitive data is encrypted using Ansible Vault:

```bash
# Encrypt file
ansible-vault encrypt group_vars/production/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/production/vault.yml

# View encrypted file
ansible-vault view group_vars/production/vault.yml

# Run playbook with vault
ansible-playbook site.yml --ask-vault-pass
```

### Security Best Practices

1. **Store vault password securely**

   ```bash
   # Use password file (not in git)
   echo "your-vault-password" > ~/.ansible_vault_pass
   chmod 600 ~/.ansible_vault_pass
   
   # Reference in ansible.cfg
   [defaults]
   vault_password_file = ~/.ansible_vault_pass
   ```

2. **Separate secrets by environment**

   ```text
   group_vars/
     staging/
       vault.yml    # Encrypted staging secrets
     production/
       vault.yml    # Encrypted production secrets
   ```

3. **Naming convention for vault variables**

   ```yaml
   # group_vars/production/vault.yml
   vault_db_password: "encrypted-value"
   vault_secret_key: "encrypted-value"
   
   # group_vars/production/vars.yml
   db_password: "{{ vault_db_password }}"
   secret_key: "{{ vault_secret_key }}"
   ```

---

## Docker Secrets

### For Docker Swarm

```bash
# Create secret
echo "my-secret-password" | docker secret create db_password -

# Use in service
docker service create \
  --name api \
  --secret db_password \
  my-api-image

# Access in container (available at /run/secrets/db_password)
```

### For Docker Compose (Staging)

```yaml
# docker-compose.yml
services:
  api:
    environment:
      # Read from .env file (not committed)
      DB_PASSWORD: ${DB_PASSWORD}
```

**Note:** Docker Compose secrets are less secure than Docker Swarm secrets. For production, use Kubernetes or external secret management.

---

## Pre-commit Hooks

### Setup Secret Scanning

Install and configure pre-commit hooks to prevent committing secrets:

```bash
# Install pre-commit
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: check-added-large-files
      - id: check-yaml
      - id: check-json
      - id: detect-private-key
EOF

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

### Create Custom Secret Scanner

```bash
# scripts/secret-scanner.sh
#!/bin/bash

# Patterns to detect
PATTERNS=(
  'password\s*=\s*["\047][^"\047]{8,}'
  'api[_-]?key\s*=\s*["\047][^"\047]{8,}'
  'secret[_-]?key\s*=\s*["\047][^"\047]{8,}'
  'AWS[_-]?ACCESS[_-]?KEY'
  'AKIA[0-9A-Z]{16}'
)

for pattern in "${PATTERNS[@]}"; do
  if git diff --cached | grep -E "$pattern"; then
    echo "❌ Potential secret detected: $pattern"
    exit 1
  fi
done
```

---

## Secret Rotation

### Rotation Schedule

| Secret Type | Frequency | Automation | Priority |
| --- | --- | --- | --- |
| Database Passwords | 90 days | Recommended | High |
| API Keys | 90 days | Recommended | High |
| TLS Certificates | 365 days | Let's Encrypt | High |
| Monitoring Passwords | 90 days | Manual | Medium |
| SSH Keys | 180 days | Manual | Medium |

### Rotation Procedure

1. **Generate new secret**

   ```bash
   NEW_PASSWORD=$(openssl rand -base64 32)
   ```

2. **Update in secret management system**

   ```bash
   # Terraform
   terraform apply -var="db_password=$NEW_PASSWORD"
   
   # Kubernetes
   kubectl create secret generic database-credentials \
     --from-literal=db-password="$NEW_PASSWORD" \
     --dry-run=client -o yaml | kubectl apply -f -
   
   # Ansible Vault
   ansible-vault edit group_vars/production/vault.yml
   ```

3. **Roll out to services**

   ```bash
   # Kubernetes rolling update
   kubectl rollout restart deployment/postgres
   kubectl rollout restart deployment/api
   
   # Verify
   kubectl rollout status deployment/api
   ```

4. **Verify functionality**

   ```bash
   # Test database connection
   kubectl exec -it deployment/api -- \
     python -c "from sqlalchemy import create_engine; \
                engine = create_engine('postgresql://...'); \
                engine.connect()"
   ```

5. **Update backup systems**
   - Update password in backup scripts
   - Update monitoring alerts
   - Update documentation

### Automated Rotation

Example using AWS Secrets Manager:

```python
# scripts/rotate_secrets.py
import boto3
from datetime import datetime, timedelta

def rotate_secret(secret_name):
    client = boto3.client('secretsmanager')
    
    # Generate new password
    new_password = client.get_random_password(
        PasswordLength=32,
        ExcludeCharacters='"\'\\',
    )['RandomPassword']
    
    # Update secret
    client.update_secret(
        SecretId=secret_name,
        SecretString=new_password
    )
    
    # Tag with rotation date
    client.tag_resource(
        SecretId=secret_name,
        Tags=[{
            'Key': 'LastRotated',
            'Value': datetime.now().isoformat()
        }]
    )
    
    return new_password

if __name__ == '__main__':
    rotate_secret('api/production/db_password')
```

---

## Incident Response

### If Secrets Are Compromised

1. **Immediate Actions** (0-1 hour)

   ```bash
   # Rotate all potentially compromised secrets
   ./scripts/emergency-rotation.sh
   
   # Revoke access for compromised credentials
   kubectl delete secret database-credentials
   
   # Check access logs
   kubectl logs -l app=api --since=24h | grep -i auth
   ```

2. **Investigation** (1-4 hours)
   - Check git history: `git log -S "password" --all`
   - Review access logs
   - Identify scope of exposure
   - Document timeline

3. **Remediation** (4-24 hours)
   - Rotate all secrets in compromised environment
   - Update all consuming services
   - Scan for unauthorized access
   - Patch vulnerability

4. **Post-Incident** (1-7 days)
   - Root cause analysis
   - Update security procedures
   - Implement additional controls
   - Team training

### Emergency Rotation Script

```bash
#!/bin/bash
# scripts/emergency-rotation.sh

set -euo pipefail

echo "🚨 EMERGENCY SECRET ROTATION"
echo "=============================="

# Generate new secrets
NEW_DB_PASSWORD=$(openssl rand -base64 32)
NEW_SECRET_KEY=$(openssl rand -base64 32)

# Update Kubernetes secrets
kubectl create secret generic database-credentials \
  --from-literal=db-password="$NEW_DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl replace -f -

kubectl create secret generic api-secrets \
  --from-literal=secret-key="$NEW_SECRET_KEY" \
  --dry-run=client -o yaml | kubectl replace -f -

# Restart deployments
kubectl rollout restart deployment/postgres
kubectl rollout restart deployment/api
kubectl rollout restart deployment/nginx

# Wait for rollout
kubectl rollout status deployment/api --timeout=300s

echo "✅ Emergency rotation complete"
echo "📝 Save new credentials to password manager"
echo "🔐 DB Password: $NEW_DB_PASSWORD"
echo "🔐 Secret Key: $NEW_SECRET_KEY"
```

---

## Tools and Resources

### Secret Scanning Tools

1. **detect-secrets** (Yelp)
   - Real-time scanning
   - Baseline management
   - Plugin architecture

2. **gitleaks**
   - Fast regex scanning
   - Pre-commit integration
   - CI/CD integration

3. **truffleHog**
   - High entropy detection
   - Git history scanning
   - Custom regexes

4. **git-secrets** (AWS)
   - Prevents AWS credentials
   - Custom patterns
   - Pre-commit/commit-msg hooks

### Secret Management Solutions

| Solution | Best For | Pricing | Integration |
| --- | --- | --- | --- |
| HashiCorp Vault | Multi-cloud, enterprise | Open source / Enterprise | Excellent |
| AWS Secrets Manager | AWS environments | Pay per secret | Native AWS |
| Azure Key Vault | Azure environments | Pay per operation | Native Azure |
| Google Secret Manager | GCP environments | Pay per version | Native GCP |
| Kubernetes External Secrets | K8s with external backend | Open source | K8s native |
| SOPS | Git-based workflows | Open source | Good |

### Commands Reference

```bash
# Generate secure password
openssl rand -base64 32

# Check for secrets in git history
git log -S "password" --all --pretty=format:"%h %an %ad %s"

# Find potential secrets in codebase
grep -rEi '(password|secret|key|token).*=.*["\047]' . \
  --exclude-dir={.git,node_modules,vendor}

# Kubernetes secret operations
kubectl create secret generic my-secret --from-literal=key=value
kubectl get secrets my-secret -o jsonpath='{.data.key}' | base64 -d
kubectl delete secret my-secret

# Ansible Vault operations
ansible-vault create secrets.yml
ansible-vault encrypt secrets.yml
ansible-vault decrypt secrets.yml
ansible-vault rekey secrets.yml

# Docker secret operations
docker secret create my-secret ./secret.txt
docker secret ls
docker secret inspect my-secret
docker secret rm my-secret
```

---

## Compliance and Auditing

### Required Compliance

- **PCI DSS**: Credit card data encryption
- **HIPAA**: Healthcare data protection
- **SOC 2**: Security controls
- **GDPR**: Personal data protection

### Audit Checklist

- [ ] No secrets in version control
- [ ] All secrets encrypted at rest
- [ ] TLS for all network traffic
- [ ] RBAC properly configured
- [ ] Secrets rotated regularly
- [ ] Access logs enabled
- [ ] Pre-commit hooks installed
- [ ] Backup encryption enabled
- [ ] Incident response plan documented
- [ ] Team trained on security practices

### Regular Audits

```bash
# Run security audit
./scripts/security-audit.sh

# Check for exposed secrets
./scripts/git-security-audit.sh

# Verify encryption
kubectl get secrets -o json | jq '.items[] | select(.immutable != true)'
```

---

## Summary

### Quick Start Checklist

For new developers:

1. ✅ Install pre-commit hooks
2. ✅ Copy `.env.example` to `.env`
3. ✅ Generate strong secrets
4. ✅ Never commit `.env` or `terraform.tfvars`
5. ✅ Use Ansible Vault for sensitive files
6. ✅ Enable 2FA on all accounts
7. ✅ Store secrets in password manager

### Production Deployment

Before going to production:

1. ✅ Migrate to external secret management
2. ✅ Enable Kubernetes secret encryption
3. ✅ Configure RBAC
4. ✅ Set up secret rotation
5. ✅ Enable audit logging
6. ✅ Test incident response procedures
7. ✅ Document all secrets and locations
8. ✅ **Remove `--kubelet-insecure-tls` from metrics-server** (see below)

---

## ⚠️ Production Security Considerations

### Metrics Server TLS Configuration

**Current Status (Development/Kind):** The metrics-server uses `--kubelet-insecure-tls` because Kind's kubelet certificates lack IP Subject Alternative Names (SANs).

**Security Risk:**

- Disables TLS verification for kubelet connections
- Allows potential MITM attacks on metrics data
- Could enable manipulation of HPA autoscaling decisions

**Production Requirements:**

For production Kubernetes clusters (GKE, EKS, AKS, etc.), update [terraform/monitoring.tf](../terraform/monitoring.tf):

```terraform
args = [
  "--cert-dir=/tmp",
  "--secure-port=4443",
  "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
  "--kubelet-use-node-status-port",
  "--metric-resolution=15s"
  # Remove: "--kubelet-insecure-tls"
]
```

**Why it's safe to remove:**

- Managed Kubernetes services (GKE, EKS, AKS) provision kubelets with proper certificates
- Certificates include IP SANs and are signed by the cluster CA
- Metrics-server automatically validates using the service account CA

**Verification:**

```bash
# After deployment, check metrics-server logs
kubectl logs -n kube-system -l app=metrics-server

# Should see successful scraping without TLS errors
# Should NOT see "failed to verify certificate" errors
```

---

## Additional Resources

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)

---

**Last Updated:** December 12, 2025  
**Maintained By:** DevOps Team  
**Review Schedule:** Quarterly
