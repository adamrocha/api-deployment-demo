#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Controlled Load Test for Autoscaling Demo${NC}"
echo "=============================================="
echo ""

API_URL="http://localhost:8000"

# Check API accessibility
if ! curl -s "$API_URL/health" > /dev/null; then
    echo -e "${RED}❌ API not accessible${NC}"
    exit 1
fi

echo -e "${GREEN}✅ API is accessible${NC}"
echo ""

# Show current status
echo -e "${YELLOW}📊 BEFORE Load Test:${NC}"
kubectl get hpa api-hpa -n api-deployment-demo
kubectl top pods -n api-deployment-demo -l component=api
echo ""

# Create moderate load using a single curl loop
echo -e "${YELLOW}🔥 Starting controlled load test...${NC}"
echo "Generating steady requests to increase CPU usage"
echo ""

# Run for 2 minutes with controlled load
for i in {1..120}; do
    # Make 5 requests per second
    for _j in {1..5}; do
        curl -s "$API_URL/health" > /dev/null &
        curl -s "$API_URL/users/" > /dev/null &
    done
    
    # Check HPA status every 15 seconds
    if [ $((i % 15)) -eq 0 ]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] Progress: ${i}/120 seconds${NC}"
        echo "📊 HPA Status:"
        kubectl get hpa api-hpa -n api-deployment-demo --no-headers
        echo "🚀 Pod Count: $(kubectl get pods -n api-deployment-demo -l component=api --no-headers | wc -l)"
        echo "💻 CPU Usage:"
        kubectl top pods -n api-deployment-demo -l component=api --no-headers | awk '{print $1 ": " $2}'
        echo "----------------------------------------"
    fi
    
    sleep 1
    
    # Clean up background jobs periodically
    if [ $((i % 10)) -eq 0 ]; then
        wait 2>/dev/null || true
    fi
done

# Wait for any remaining background jobs
wait 2>/dev/null || true

echo ""
echo -e "${GREEN}🎉 Load test completed!${NC}"
echo ""

# Show final status
echo -e "${YELLOW}📊 AFTER Load Test:${NC}"
kubectl describe hpa api-hpa -n api-deployment-demo | grep -A 10 "Metrics:"
kubectl get pods -n api-deployment-demo -l component=api

echo ""
echo -e "${BLUE}📈 Autoscaling Summary:${NC}"
echo "• If CPU usage exceeded 70%, HPA should have scaled up"
echo "• New pods take 30-60 seconds to become ready"
echo "• Scaling decisions are made every 15 seconds"
echo "• Scale-down happens after 5 minutes of low usage"