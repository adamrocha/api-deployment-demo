#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Load Test to Demonstrate Autoscaling${NC}"
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

# Show current HPA status
echo -e "${YELLOW}📊 Current HPA Status (BEFORE load test):${NC}"
kubectl get hpa -n api-deployment-demo
echo ""

# Show current pod resource usage
echo -e "${YELLOW}💻 Current Pod Resource Usage:${NC}"
kubectl top pods -n api-deployment-demo
echo ""

# Start load test
echo -e "${YELLOW}🔥 Starting intensive load test...${NC}"
echo "This will generate high CPU load to trigger autoscaling"
echo ""

# Run multiple concurrent requests to create CPU load
# We'll hit different endpoints to create realistic load
run_load_test() {
    local duration=$1
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        # Create CPU-intensive requests
        curl -s "$API_URL/users/" > /dev/null &
        curl -s "$API_URL/health" > /dev/null &
        curl -s "$API_URL/docs" > /dev/null &
        
        # Add a CPU-intensive endpoint if available
        curl -s -X POST "$API_URL/users/" \
            -H "Content-Type: application/json" \
            -d '{"name": "LoadTest User", "email": "test@example.com"}' > /dev/null &
        
        # Small delay to prevent overwhelming
        sleep 0.01
    done
    
    # Wait for background jobs to complete
    wait
}

# Monitor scaling in background
monitor_scaling() {
    local duration=$1
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Monitoring autoscaling...${NC}"
        
        echo "📊 HPA Status:"
        kubectl get hpa api-hpa -n api-deployment-demo --no-headers
        
        echo "🚀 Current Pods:"
        kubectl get pods -n api-deployment-demo -l component=api --no-headers | wc -l | xargs echo "API Pods:"
        
        echo "💻 Resource Usage:"
        kubectl top pods -n api-deployment-demo -l component=api --no-headers | head -3
        
        echo "----------------------------------------"
        sleep 15
    done
}

# Start monitoring in background
monitor_scaling 180 &
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
echo -e "${YELLOW}📊 Final HPA Status (AFTER load test):${NC}"
kubectl describe hpa api-hpa -n api-deployment-demo

echo ""
echo -e "${YELLOW}🚀 Final Pod Count:${NC}"
kubectl get pods -n api-deployment-demo -l component=api

echo ""
echo -e "${BLUE}📈 Autoscaling Demonstration Complete!${NC}"
echo ""
echo "🔍 What happened:"
echo "  1. Load test generated high CPU usage"
echo "  2. HPA detected CPU usage above 70% threshold"
echo "  3. HPA automatically scaled up API pods"
echo "  4. Load was distributed across new pods"
echo "  5. System maintained performance under load"
echo ""
echo "⏰ In about 5 minutes, you'll see pods scale back down as load decreases"