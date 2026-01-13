#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Load Test - HPA Autoscaling Demo${NC}"
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

# Show initial deployment status
echo -e "${YELLOW}📊 Initial Deployment Status:${NC}"
kubectl get deployment -n api-deployment-demo -o wide
echo ""

# Show initial pods
echo -e "${YELLOW}📦 Initial Pods:${NC}"
kubectl get pods -n api-deployment-demo -l app=api-demo,component=api -o wide
echo ""

# Check for HPA
if kubectl get hpa -n api-deployment-demo 2>/dev/null | grep -q api; then
    echo -e "${GREEN}✅ HPA is configured!${NC}"
    kubectl get hpa -n api-deployment-demo
    echo ""
else
    echo -e "${YELLOW}⚠️  No HPA found - pods will not autoscale${NC}"
    echo ""
fi

# Check for metrics
if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}💻 Initial Pod Resource Usage:${NC}"
    kubectl top pods -n api-deployment-demo
    echo ""
else
    echo -e "${YELLOW}⚠️  Metrics not available - install metrics-server for detailed stats${NC}"
    echo ""
fi

# Start load test
echo -e "${CYAN}🔥 Starting intensive CPU load test to trigger autoscaling...${NC}"
echo -e "${CYAN}Target: >50% CPU using /stress endpoint (75,000 prime calculation)${NC}"
echo -e "${CYAN}Workers: 75 concurrent, hammering CPU for 5 minutes${NC}"
echo ""

# Run multiple concurrent requests to create CPU load
run_load_test() {
    local duration=$1
    local workers=75
    local max_background_jobs=200
    
    # Function to run in each worker
    worker() {
        local end_time=$1
        while [ "$(date +%s)" -lt "$end_time" ]; do
            # Use CPU-intensive /stress endpoint to trigger autoscaling
            curl -s "$API_URL/stress" > /dev/null &
            
            # Optional small delay to avoid ultra-rapid process spawning
            sleep 0.01
            
            # Controlled background job limit to prevent fork bomb
            while :; do
                local job_count
                job_count=$(jobs -r | wc -l)
                if [ "$job_count" -lt "$max_background_jobs" ]; then
                    break
                fi
                # Wait for at least one background job to finish before spawning more
                wait -n 2>/dev/null || true
                sleep 0.05
            done
        done
        # Clean up all background jobs for this worker
        wait
    }
    
    local end_time=$(($(date +%s) + duration))
    
    # Start worker processes
    echo -e "${BLUE}⚡ Launching $workers concurrent workers hitting /stress endpoint...${NC}"
    for _ in $(seq 1 $workers); do
        worker $end_time &
    done
    
    # Wait for all workers to complete
    wait
}

# Monitor pods in background
monitor_pods() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    local iteration=0
    
    while [ "$(date +%s)" -lt "$end_time" ]; do
        iteration=$((iteration + 1))
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  HPA Autoscaling Demo - Live Monitoring  [Iteration: $(printf '%3d' "$iteration")]  ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Show HPA status if available
        if kubectl get hpa -n api-deployment-demo 2>/dev/null | grep -q api; then
            echo -e "${GREEN}📈 HPA Status (triggers at 50% CPU):${NC}"
            kubectl get hpa -n api-deployment-demo
            echo ""
        fi
        
        # Current pod count
        POD_COUNT=$(kubectl get pods -n api-deployment-demo -l app=api-demo,component=api --no-headers 2>/dev/null | grep -c Running || echo 0)
        echo -e "${BLUE}🚀 Current API Pods: ${GREEN}$POD_COUNT running${NC}"
        echo ""
        
        # Show resource usage if metrics available
        if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
            echo -e "${YELLOW}💻 Pod Resource Usage:${NC}"
            kubectl top pods -n api-deployment-demo -l app=api-demo,component=api 2>/dev/null || true
            echo ""
        fi
        
        # Show pod details
        echo -e "${YELLOW}📦 Pod Details:${NC}"
        kubectl get pods -n api-deployment-demo -l app=api-demo,component=api -o wide --no-headers 2>/dev/null | head -10 || true
        
        echo ""
        echo -e "${CYAN}⏱️  Time remaining: $((end_time - $(date +%s))) seconds${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        sleep 10
    done
}

# Start monitoring in background
monitor_pods 300 &
MONITOR_PID=$!

# Run load test for 5 minutes to allow time for autoscaling
echo -e "${YELLOW}⚡ Running load test for 5 minutes to trigger autoscaling...${NC}"
echo -e "${CYAN}Expect to see CPU rise above 50% and pods scale from 2 to ~5-10${NC}"
echo ""
run_load_test 300

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
clear

echo ""
echo -e "${GREEN}🎉 Load test completed!${NC}"
echo ""

# Show final status
echo -e "${YELLOW}📊 Final Deployment Status:${NC}"
kubectl get deployment -n api-deployment-demo -o wide

echo ""
echo -e "${YELLOW}📈 Final HPA Status:${NC}"
if kubectl get hpa -n api-deployment-demo 2>/dev/null | grep -q api; then
    kubectl get hpa -n api-deployment-demo
else
    echo -e "${RED}No HPA configured${NC}"
fi

echo ""
echo -e "${YELLOW}📦 Final Pod Status:${NC}"
kubectl get pods -n api-deployment-demo -l app=api-demo,component=api

echo ""
if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}💻 Final Resource Usage:${NC}"
    kubectl top pods -n api-deployment-demo -l app=api-demo,component=api
    echo ""
fi

echo ""
echo -e "${GREEN}✅ Load Test Complete!${NC}"
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  • Load test ran for 5 minutes with 75 concurrent workers targeting CPU-intensive /stress endpoint"

# Get pod count with error handling
POD_COUNT=$(kubectl get pods -n api-deployment-demo -l app=api-demo,component=api --no-headers 2>/dev/null | grep -c Running || echo 0)
if [[ -n "$POD_COUNT" && "$POD_COUNT" =~ ^[0-9]+$ && "$POD_COUNT" -gt 0 ]]; then
    echo "  • Scaled to $POD_COUNT pod(s) during load test"
    if [ "$POD_COUNT" -gt 2 ]; then
        echo -e "  • ${GREEN}✅ HPA successfully triggered autoscaling!${NC}"
    else
        echo -e "  • ${YELLOW}⚠️  HPA did not scale up (load may not have been sufficient)${NC}"
    fi
else
    echo "  • API pod count: unavailable (check cluster connectivity)"
fi

echo ""
echo -e "${CYAN}💡 Tips:${NC}"
echo "  • Watch pods scale down: kubectl get pods -n api-deployment-demo -w"
echo "  • Check HPA events: kubectl describe hpa -n api-deployment-demo"
echo "  • View API logs: kubectl logs -n api-deployment-demo -l app=api-demo,component=api"
echo "  • Monitor metrics: kubectl top pods -n api-deployment-demo"
echo ""
echo -e "${YELLOW}Note: Pods will gradually scale down after ~5 minutes of low load${NC}"