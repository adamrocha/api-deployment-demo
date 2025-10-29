#!/bin/bash

# =======================================================================
# Staging to Production Promotion Script
# =======================================================================
# This script demonstrates how to promote code from staging to production
# Usage: ./scripts/promote-to-production.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Staging to Production Promotion${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Step 1: Validate staging environment
echo -e "${YELLOW}📋 Step 1: Validating staging environment...${NC}"
if ! curl -s http://localhost:30800/health > /dev/null 2>&1; then
    echo -e "${RED}❌ Staging environment is not running${NC}"
    echo -e "${YELLOW}💡 Start staging first: make staging${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Staging environment is healthy${NC}"

# Step 2: Run staging tests
echo -e "${YELLOW}📋 Step 2: Running staging integration tests...${NC}"

# Test API endpoints
echo "  Testing API health..."
HEALTH_RESPONSE=$(curl -s http://localhost:30800/health)
if echo "$HEALTH_RESPONSE" | grep -q '"status":"healthy"'; then
    echo -e "${GREEN}  ✅ API health check passed${NC}"
else
    echo -e "${RED}  ❌ API health check failed${NC}"
    exit 1
fi

# Test database connectivity
echo "  Testing database connectivity..."
if curl -s http://localhost:30800/users/ > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Database connectivity test passed${NC}"
else
    echo -e "${RED}  ❌ Database connectivity test failed${NC}"
    exit 1
fi

# Test frontend
echo "  Testing frontend..."
if curl -s http://localhost:30080 > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Frontend test passed${NC}"
else
    echo -e "${RED}  ❌ Frontend test failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All staging tests passed${NC}"

# Step 3: Build production images
echo -e "${YELLOW}📋 Step 3: Building production Docker images...${NC}"
docker build -t api-deployment-demo-api:production ./api
docker build -t api-deployment-demo-nginx:production ./nginx
echo -e "${GREEN}✅ Production images built${NC}"

# Step 4: Deploy to production
echo -e "${YELLOW}📋 Step 4: Deploying to production...${NC}"

# Check if production is already running
if kubectl get namespace api-deployment-demo > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Production environment exists. Updating...${NC}"
    
    # Rolling update
    kubectl set image deployment/api-deployment api=api-deployment-demo-api:production -n api-deployment-demo
    kubectl set image deployment/nginx-deployment nginx=api-deployment-demo-nginx:production -n api-deployment-demo
    
    # Wait for rollout
    kubectl rollout status deployment/api-deployment -n api-deployment-demo
    kubectl rollout status deployment/nginx-deployment -n api-deployment-demo
    
else
    echo -e "${YELLOW}🏗️  Creating new production environment...${NC}"
    
    # Create production environment
    make production ENV=production
fi

echo -e "${GREEN}✅ Production deployment completed${NC}"

# Step 5: Production smoke tests
echo -e "${YELLOW}📋 Step 5: Running production smoke tests...${NC}"

# Wait for services to be ready
sleep 30

# Test production health
if curl -s http://localhost/health > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Production health check passed${NC}"
else
    echo -e "${RED}  ❌ Production health check failed${NC}"
    echo -e "${YELLOW}💡 Check logs: kubectl logs -n api-deployment-demo deployment/api-deployment${NC}"
    exit 1
fi

# Test production API
if curl -s http://localhost:8000/users/ > /dev/null 2>&1; then
    echo -e "${GREEN}  ✅ Production API test passed${NC}"
else
    echo -e "${RED}  ❌ Production API test failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All production smoke tests passed${NC}"

# Step 6: Summary
echo ""
echo -e "${BLUE}🎉 Promotion Complete!${NC}"
echo -e "${BLUE}===================${NC}"
echo ""
echo -e "${GREEN}✅ Code successfully promoted from staging to production${NC}"
echo ""
echo -e "${YELLOW}🌐 Production Access Points:${NC}"
echo -e "  Web Frontend: http://localhost"
echo -e "  API Direct:   http://localhost:8000"
echo -e "  API Docs:     http://localhost:8000/docs"
echo -e "  Health Check: http://localhost/health"
echo ""
echo -e "${YELLOW}📊 Monitoring:${NC}"
echo -e "  Status: make production-status"
echo -e "  Logs:   kubectl logs -n api-deployment-demo deployment/api-deployment"
echo ""
echo -e "${YELLOW}🔄 Rollback (if needed):${NC}"
echo -e "  kubectl rollout undo deployment/api-deployment -n api-deployment-demo"
echo -e "  kubectl rollout undo deployment/nginx-deployment -n api-deployment-demo"
echo ""