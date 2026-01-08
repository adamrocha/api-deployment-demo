#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Load Test${NC}"
echo "=================================================="
echo ""

# Check if we have access to the API
API_URL="http://localhost:8000"
if ! curl -s "$API_URL/health" > /dev/null; then
    echo -e "${RED}❌ API not accessible at $API_URL${NC}"
    echo "Make sure your API is running and accessible"
    exit 1
fi

echo -e "${GREEN}✅ API is accessible at $API_URL${NC}"
echo ""

# Show current deployment status
echo -e "${YELLOW}📊 Current Deployment Status:${NC}"
kubectl get deployment -n api-deployment-demo -o wide
echo ""

# Show current pods
echo -e "${YELLOW}📦 Current Pods:${NC}"
kubectl get pods -n api-deployment-demo -l app=api-demo,component=api -o wide
echo ""

# Check for HPA (optional - not required)
if kubectl get hpa -n api-deployment-demo 2>/dev/null | grep -q api; then
    echo -e "${YELLOW}📊 HPA Status:${NC}"
    kubectl get hpa -n api-deployment-demo
    echo ""
fi

# Check for metrics (optional - not required)
if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}💻 Current Pod Resource Usage:${NC}"
    kubectl top pods -n api-deployment-demo
    echo ""
fi

# Start load test
echo -e "${YELLOW}🔥 Starting intensive load test...${NC}"
echo "This will generate high load to test API performance"
echo ""

# Run multiple concurrent requests to create CPU load
# We'll hit different endpoints to create realistic load
run_load_test() {
    local duration=$1
    local workers=20  # Number of parallel workers
    
    # Function to run in each worker
    worker() {
        local end_time=$1
        while [ $(date +%s) -lt $end_time ]; do
            curl -s "$API_URL/users/" > /dev/null
            curl -s "$API_URL/health" > /dev/null
            curl -s -X POST "$API_URL/users/" \
                -H "Content-Type: application/json" \
                -d '{"name": "LoadTest", "email": "test@example.com"}' > /dev/null 2>&1 || true
            sleep 0.1
        done
    }
    
    local end_time=$(($(date +%s) + duration))
    
    # Start worker processes
    for i in $(seq 1 $workers); do
        worker $end_time &
    done
    
    # Wait for all workers to complete
    wait
}

# Monitor pods in background
monitor_pods() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Monitoring pods...${NC}"
        
        echo "🚀 Current API Pods:"
        kubectl get pods -n api-deployment-demo -l app=api-demo,component=api --no-headers | wc -l | xargs echo "  Running:"
        
        # Show resource usage if metrics available
        if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
            echo "💻 Resource Usage:"
            kubectl top pods -n api-deployment-demo -l app=api-demo,component=api --no-headers 2>/dev/null | head -3 || true
        fi
        
        echo "----------------------------------------"
        sleep 15
    done
}

# Start monitoring in background
monitor_pods 180 &
MONITOR_PID=$!

# Run load test for 3 minutes
echo -e "${YELLOW}⚡ Running load test for 3 minutes...${NC}"
run_load_test 180

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 Load test completed!${NC}"
echo ""

# Show final status
echo -e "${YELLOW}📊 Final Deployment Status:${NC}"
kubectl get deployment -n api-deployment-demo -o wide

echo ""
echo -e "${YELLOW}📦 Final Pod Status:${NC}"
kubectl get pods -n api-deployment-demo -l app=api-demo,component=api

echo ""
echo -e "${GREEN}✅ Load Test Complete!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  • Load test sent concurrent requests for 3 minutes"
echo "  • API handled requests across $(kubectl get pods -n api-deployment-demo -l app=api-demo,component=api --no-headers 2>/dev/null | wc -l | xargs) pod(s)"
echo "  • Check logs with: kubectl logs -n api-deployment-demo -l app=api-demo,component=api"
echo ""
echo -e "${YELLOW}💡 Note:${NC} This deployment uses static replicas (no autoscaling configured)"
echo "  To enable autoscaling, you would need to:"
echo "    1. Install metrics-server in the cluster"
echo "    2. Configure HorizontalPodAutoscaler (HPA)"
echo "    3. Set resource requests/limits on pods"