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
    for ((i=1; i<=max_attempts; i++)); do
        if curl -s --max-time 3 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name is ready!${NC}"
            return 0
        fi
        if [ "$i" -eq "$max_attempts" ]; then
            echo -e "${RED}❌ $name failed to start within $max_attempts attempts${NC}"
            return 1
        fi
        echo "  Attempt $i/$max_attempts..."
        sleep 2
    done
}

# Function to test API endpoints (both HTTP and HTTPS)
test_api_endpoints() {
    echo -e "${BLUE}🧪 Testing API endpoints...${NC}"
    
    # Test HTTP health endpoint
    echo -n "  Health endpoint (HTTP): "
    if curl -s --max-time 5 http://localhost/health >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test HTTPS health endpoint
    echo -n "  Health endpoint (HTTPS): "
    if curl -s --max-time 5 -k https://localhost/health >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test HTTP users endpoint
    echo -n "  Users endpoint (HTTP): "
    if curl -s --max-time 5 http://localhost/users >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test HTTPS users endpoint
    echo -n "  Users endpoint (HTTPS): "
    if curl -s --max-time 5 -k https://localhost/users >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test API docs HTTP (direct API service)
    echo -n "  API docs (HTTP direct): "
    if curl -s --max-time 5 http://localhost:8000/docs >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test API docs HTTPS via nginx reverse proxy
    echo -n "  API docs (HTTPS via nginx): "
    if curl -s --max-time 5 -k https://localhost/docs >/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    return 0
}

# Function to test SSL certificate validity in Kubernetes
test_ssl_certificates() {
    echo -e "${BLUE}🔒 Testing SSL certificate setup...${NC}"
    
    # Check if SSL secret exists in Kubernetes
    echo -n "  SSL secret in Kubernetes: "
    if kubectl get secret nginx-ssl-certs -n api-deployment-demo >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ MISSING${NC}"
        return 1
    fi
    
    # Extract certificate from Kubernetes secret for validation
    echo -n "  Certificate extraction: "
    if kubectl get secret nginx-ssl-certs -n api-deployment-demo -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/server.crt 2>/dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
    
    # Test certificate validity
    echo -n "  Certificate validity: "
    if openssl x509 -in /tmp/server.crt -noout -checkend 86400 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK (valid for >24h)${NC}"
    else
        echo -e "${RED}❌ EXPIRED/INVALID${NC}"
        return 1
    fi
    
    # Test certificate SAN entries
    echo -n "  Certificate SAN entries: "
    if openssl x509 -in /tmp/server.crt -noout -text | grep -q "DNS:localhost"; then
        echo -e "${GREEN}✅ OK (includes localhost)${NC}"
    else
        echo -e "${RED}❌ MISSING localhost SAN${NC}"
        return 1
    fi
    
    # Clean up temporary file
    rm -f /tmp/server.crt
    
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
wait_for_service "http://localhost/health" "API (via Nginx HTTP)" 120
wait_for_service "http://localhost:8000/health" "API (direct HTTP)" 60

echo -e "${YELLOW}3.1. Testing SSL certificate setup in Kubernetes...${NC}"
# Check if SSL secret exists in Kubernetes
if kubectl get secret nginx-ssl-certs -n api-deployment-demo >/dev/null 2>&1; then
    echo -e "${GREEN}✅ SSL certificate secret found in Kubernetes${NC}"
    
    # Test HTTPS endpoints
    echo -e "${YELLOW}3.2. Waiting for HTTPS services...${NC}"
    sleep 10  # Give nginx time to load SSL certs from secret
    if curl -s --max-time 5 -k https://localhost/health >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTPS endpoint is responding${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS endpoint not ready yet, continuing...${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ SSL certificate secret not found in Kubernetes, HTTPS tests may fail${NC}"
fi

echo -e "${YELLOW}4. Testing SSL certificate setup...${NC}"
if test_ssl_certificates; then
    echo -e "${GREEN}✅ SSL certificates are valid and properly configured!${NC}"
else
    echo -e "${RED}❌ SSL certificate test failed${NC}"
    exit 1
fi

echo -e "${YELLOW}5. Testing API functionality (HTTP & HTTPS)...${NC}"
if test_api_endpoints; then
    echo -e "${GREEN}✅ All API endpoints working (both HTTP and HTTPS)!${NC}"
else
    echo -e "${RED}❌ API test failed${NC}"
    exit 1
fi

echo -e "${YELLOW}6. Starting monitoring stack...${NC}"
make monitoring

echo -e "${YELLOW}7. Waiting for monitoring services...${NC}"
wait_for_service "http://localhost:9090/-/healthy" "Prometheus" 120
wait_for_service "http://localhost:3000/api/health" "Grafana" 120

echo -e "${YELLOW}8. Testing monitoring functionality...${NC}"
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
echo -e "  🌐 Web Frontend: ${YELLOW}http://localhost${NC} | ${YELLOW}https://localhost${NC} 🔒"
echo -e "  🔧 API Direct:   ${YELLOW}http://localhost:8000${NC} | ${YELLOW}https://localhost:8000${NC} 🔒"
echo -e "  📚 API Docs:     ${YELLOW}http://localhost:8000/docs${NC} | ${YELLOW}https://localhost:8000/docs${NC} 🔒"
echo -e "  📊 Prometheus:   ${YELLOW}http://localhost:9090${NC}"
echo -e "  📈 Grafana:      ${YELLOW}http://localhost:3000${NC} (admin/[see .env])"
echo ""
echo -e "${GREEN}✨ All services are automatically accessible - no port-forwarding or manual configuration needed!${NC}"
echo -e "${GREEN}🔒 HTTPS endpoints use self-signed certificates (browser security warnings are expected)${NC}"

# Generate some test traffic
echo -e "${YELLOW}9. Generating test traffic...${NC}"
make traffic >/dev/null 2>&1 || true

echo ""
echo -e "${GREEN}🚀 Deployment test complete! All services are fully functional.${NC}"