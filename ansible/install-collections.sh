#!/bin/bash

# Install required Ansible collections for Task 2
# Run this before executing the database playbook

set -e

echo "Installing required Ansible collections for Task 2..."

# Install community.postgresql for PostgreSQL management
ansible-galaxy collection install community.postgresql

# Install community.general for various modules including monitoring
ansible-galaxy collection install community.general

echo "Collections installed successfully!"
echo ""
echo "Verify installations:"
ansible-doc community.postgresql.postgresql_db >/dev/null 2>&1 && echo "✅ community.postgresql - OK" || echo "❌ community.postgresql - Missing"
ansible-doc community.general.systemd >/dev/null 2>&1 && echo "✅ community.general - OK" || echo "❌ community.general - Missing"