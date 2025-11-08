#!/bin/bash

# Ansible Deployment Demo Script
# Shows how to deploy the API application using Ansible

set -e

# Colors for output
# RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cd /opt/github/api-deployment-demo/ansible

echo -e "${BLUE}🚀 Ansible Deployment Commands${NC}\n"

echo -e "${YELLOW}1. Deploy to Staging Environment:${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=staging\""
echo ""

echo -e "${YELLOW}2. Deploy to Production Environment:${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=production\""
echo ""

echo -e "${YELLOW}3. Deploy with Custom Variables:${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=staging\" -e \"ssl_enabled=true\" -e \"api_workers=4\""
echo ""

echo -e "${YELLOW}4. Deploy Specific Tags (Docker only):${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=staging\" --tags docker"
echo ""

echo -e "${YELLOW}5. Check Mode (Dry Run):${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=staging\" --check --diff"
echo ""

echo -e "${YELLOW}6. Deploy with Verbose Output:${NC}"
echo "   ansible-playbook -i inventory.ini site.yml -e \"target_env=staging\" -vvv"
echo ""

echo -e "${GREEN}📋 Available Playbook Tags:${NC}"
echo "   • system    - System updates and basic setup"
echo "   • docker    - Docker installation and setup"
echo "   • ssl       - SSL certificate generation"
echo "   • api       - API application deployment"  
echo "   • monitoring - Monitoring and logging setup"
echo ""

echo -e "${GREEN}🏗️ Deployment Process:${NC}"
echo "   1. Update system packages"
echo "   2. Install and configure Docker"
echo "   3. Generate SSL certificates (if enabled)"
echo "   4. Deploy application code"
echo "   5. Configure environment variables"
echo "   6. Start services with Docker Compose"
echo "   7. Set up monitoring and logging"
echo "   8. Configure systemd services"
echo ""

echo -e "${GREEN}📊 Environment Variables Available:${NC}"
echo "   • target_env     - Target environment (staging/production)"
echo "   • ssl_enabled    - Enable SSL certificates (true/false)"
echo "   • api_workers    - Number of API worker processes"
echo "   • debug_mode     - Enable debug mode (true/false)"
echo "   • version        - Application version to deploy"
echo ""

echo -e "${BLUE}💡 Example Production Deployment:${NC}"
echo -e "${YELLOW}ansible-playbook -i inventory.ini site.yml \\${NC}"
echo -e "${YELLOW}  -e \"target_env=production\" \\${NC}"
echo -e "${YELLOW}  -e \"ssl_enabled=true\" \\${NC}"
echo -e "${YELLOW}  -e \"api_workers=8\" \\${NC}"
echo -e "${YELLOW}  -e \"version=v1.2.3\" \\${NC}"
echo -e "${YELLOW}  --check --diff${NC}"
echo ""

echo -e "${GREEN}✅ Ansible configuration is ready for deployment!${NC}"