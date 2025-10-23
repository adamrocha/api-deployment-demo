#!/bin/bash

# API Deployment Demo - Automated Test Script
# This script demonstrates the fully automated deployment without manual intervention

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 API Deployment Demo - Automated Test${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""

# Function to wait for service with timeout
wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-30}
    
    echo -e "${YELLOW}⏳ Waiting for $name to be ready...${NC}"
    for i in $(seq 1 $max_attempts); do
        if curl -s --max-time 3 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name is ready!${NC}"
            return 0
        fi
        if [ $i -eq $max_attempts ]; then
            echo -e "${RED}❌ $name failed to start within $max_attempts attempts${NC}"
            return 1
        fi
        echo "  Attempt $i/$max_attempts..."
        sleep 2
    done
}

# Function to test API endpoints
test_api_endpoints() {
    echo -e "${BLUE}🧪 Testing API endpoints...${NC}"
    
    # Test health endpoint
    echo -n "  Health endpoint: "
    if curl -s --max-time 5 http://localhost/health >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test users endpoint
    echo -n "  Users endpoint: "
    if curl -s --max-time 5 http://localhost/users >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test API docs
    echo -n "  API docs: "
    if curl -s --max-time 5 http://localhost:8000/docs >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    return 0
}

# Function to test monitoring endpoints
test_monitoring_endpoints() {
    echo -e "${BLUE}📊 Testing monitoring endpoints...${NC}"
    
    # Test Prometheus
    echo -n "  Prometheus: "
    if curl -s --max-time 5 http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test Grafana
    echo -n "  Grafana: "
    if curl -s --max-time 5 http://localhost:3000/api/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    return 0
}

echo -e "${YELLOW}1. Cleaning up any existing environment...${NC}"
make clean >/dev/null 2>&1 || true

echo -e "${YELLOW}2. Starting production environment...${NC}"
make production

echo -e "${YELLOW}3. Waiting for core services...${NC}"
wait_for_service "http://localhost/health" "API (via Nginx)" 120
wait_for_service "http://localhost:8000/health" "API (direct)" 60

echo -e "${YELLOW}4. Testing API functionality...${NC}"
if test_api_endpoints; then
    echo -e "${GREEN}✅ All API endpoints working!${NC}"
else
    echo -e "${RED}❌ API test failed${NC}"
    exit 1
fi

echo -e "${YELLOW}5. Starting monitoring stack...${NC}"
make monitoring

echo -e "${YELLOW}6. Waiting for monitoring services...${NC}"
wait_for_service "http://localhost:9090/-/healthy" "Prometheus" 120
wait_for_service "http://localhost:3000/api/health" "Grafana" 120

echo -e "${YELLOW}7. Testing monitoring functionality...${NC}"
if test_monitoring_endpoints; then
    echo -e "${GREEN}✅ All monitoring endpoints working!${NC}"
else
    echo -e "${RED}❌ Monitoring test failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 AUTOMATED DEPLOYMENT TEST PASSED!${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo -e "${BLUE}📊 Access Points (No Manual Setup Required):${NC}"
echo -e "  🌐 Web Frontend: ${YELLOW}http://localhost${NC}"
echo -e "  🔧 API Direct:   ${YELLOW}http://localhost:8000${NC}"
echo -e "  📚 API Docs:     ${YELLOW}http://localhost:8000/docs${NC}"
echo -e "  📊 Prometheus:   ${YELLOW}http://localhost:9090${NC}"
echo -e "  📈 Grafana:      ${YELLOW}http://localhost:3000${NC} (admin/[see .env])"
echo ""
echo -e "${GREEN}✨ All services are automatically accessible - no port-forwarding or manual configuration needed!${NC}"

# Generate some test traffic
echo -e "${YELLOW}8. Generating test traffic...${NC}"
make traffic >/dev/null 2>&1 || true

echo -e "${GREEN}🚀 Deployment test complete! All services are fully functional.${NC}"