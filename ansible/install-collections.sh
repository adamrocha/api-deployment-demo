#!/bin/bash

# Install required Ansible collections for API Deployment Demo
# Run this before executing the playbooks

set -e

echo "🔧 Installing required Ansible collections..."
echo ""

# Install from requirements file if it exists
if [ -f "$(dirname "$0")/requirements.yml" ]; then
    echo "📦 Installing from requirements.yml..."
    ansible-galaxy collection install -r "$(dirname "$0")/requirements.yml"
else
    echo "📦 Installing collections individually..."
    # Install community.docker for Docker Compose management
    ansible-galaxy collection install community.docker
    
    # Install kubernetes.core for Kubernetes management
    ansible-galaxy collection install kubernetes.core
    
    # Install community.postgresql for PostgreSQL management
    ansible-galaxy collection install community.postgresql
    
    # Install community.general for various modules including monitoring
    ansible-galaxy collection install community.general
fi

echo ""
echo "✅ Collections installed successfully!"
echo ""
echo "🔍 Verifying installations..."
ansible-doc community.docker.docker_compose_v2 >/dev/null 2>&1 && echo "✅ community.docker - OK" || echo "❌ community.docker - Missing"
ansible-doc kubernetes.core.k8s >/dev/null 2>&1 && echo "✅ kubernetes.core - OK" || echo "❌ kubernetes.core - Missing"
ansible-doc community.postgresql.postgresql_db >/dev/null 2>&1 && echo "✅ community.postgresql - OK" || echo "❌ community.postgresql - Missing"
ansible-doc community.general.systemd >/dev/null 2>&1 && echo "✅ community.general - OK" || echo "❌ community.general - Missing"
echo ""
echo "🚀 Ready to run Ansible playbooks!"