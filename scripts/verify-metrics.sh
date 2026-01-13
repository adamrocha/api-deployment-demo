#!/bin/bash

# Script to verify metrics server is working and HPA can get metrics
# Run this to troubleshoot HPA "failed to get metrics" errors

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Verifying Metrics Server and HPA Status${NC}"
echo ""

# Check if metrics server pod is running
echo -e "${YELLOW}1. Checking Metrics Server Pod Status:${NC}"
if kubectl get pods -n kube-system -l app=metrics-server 2>/dev/null | grep -q Running; then
    echo -e "${GREEN}✓ Metrics Server pod is running${NC}"
    kubectl get pods -n kube-system -l app=metrics-server
else
    echo -e "${RED}✗ Metrics Server pod is not running${NC}"
    kubectl get pods -n kube-system -l app=metrics-server 2>/dev/null || echo "No metrics server found"
fi
echo ""

# Check metrics server service
echo -e "${YELLOW}2. Checking Metrics Server Service:${NC}"
if kubectl get svc -n kube-system metrics-server 2>/dev/null | grep -q metrics-server; then
    echo -e "${GREEN}✓ Metrics Server service exists${NC}"
    kubectl get svc -n kube-system metrics-server
else
    echo -e "${RED}✗ Metrics Server service not found${NC}"
fi
echo ""

# Check APIService for metrics
echo -e "${YELLOW}3. Checking Metrics API Service Registration:${NC}"
if kubectl get apiservice v1beta1.metrics.k8s.io 2>/dev/null | grep -q True; then
    echo -e "${GREEN}✓ Metrics API is registered and available${NC}"
    kubectl get apiservice v1beta1.metrics.k8s.io
else
    echo -e "${RED}✗ Metrics API is not available${NC}"
    kubectl get apiservice v1beta1.metrics.k8s.io 2>/dev/null || echo "API service not found"
fi
echo ""

# Try to get node metrics
echo -e "${YELLOW}4. Testing Node Metrics:${NC}"
if kubectl top nodes 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ Node metrics are available${NC}"
    kubectl top nodes
else
    echo -e "${RED}✗ Cannot retrieve node metrics${NC}"
    echo "Error output:"
    kubectl top nodes 2>&1 || true
fi
echo ""

# Try to get pod metrics in api-deployment-demo namespace
echo -e "${YELLOW}5. Testing Pod Metrics (api-deployment-demo):${NC}"
if kubectl top pods -n api-deployment-demo 2>/dev/null | grep -q .; then
    echo -e "${GREEN}✓ Pod metrics are available${NC}"
    kubectl top pods -n api-deployment-demo
else
    echo -e "${RED}✗ Cannot retrieve pod metrics${NC}"
    echo "This is normal if pods just started - wait 30-60 seconds for metrics collection"
    kubectl top pods -n api-deployment-demo 2>&1 || true
fi
echo ""

# Check HPA status
echo -e "${YELLOW}6. Checking HPA Status:${NC}"
if kubectl get hpa -n api-deployment-demo 2>/dev/null | grep -q .; then
    kubectl get hpa -n api-deployment-demo
    echo ""
    
    # Get detailed HPA information
    echo -e "${YELLOW}7. HPA Detailed Status:${NC}"
    kubectl describe hpa -n api-deployment-demo 2>/dev/null | tail -30
else
    echo -e "${RED}✗ No HPA found in api-deployment-demo namespace${NC}"
fi
echo ""

# Check if API pods have resource requests defined
echo -e "${YELLOW}8. Verifying API Pod Resource Requests:${NC}"
if kubectl get pods -n api-deployment-demo -l app=api-demo,component=api -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}' 2>/dev/null | grep -q .; then
    CPU_REQUEST=$(kubectl get pods -n api-deployment-demo -l app=api-demo,component=api -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    echo -e "${GREEN}✓ API pods have CPU requests defined: ${CPU_REQUEST}${NC}"
else
    echo -e "${RED}✗ API pods missing CPU requests (required for HPA percentage-based scaling)${NC}"
fi
echo ""

# Summary and recommendations
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}📋 Summary:${NC}"
echo ""

# Check if everything is healthy
METRICS_WORKING=true

if ! kubectl get pods -n kube-system -l app=metrics-server 2>/dev/null | grep -q Running; then
    METRICS_WORKING=false
    echo -e "${RED}• Metrics Server is not running - deploy it first${NC}"
fi

if ! kubectl get apiservice v1beta1.metrics.k8s.io 2>/dev/null | grep -q True; then
    METRICS_WORKING=false
    echo -e "${RED}• Metrics API is not available - check APIService registration${NC}"
fi

if ! kubectl top nodes 2>/dev/null | grep -q .; then
    METRICS_WORKING=false
    echo -e "${YELLOW}• Node metrics not available - metrics server may still be starting${NC}"
fi

if $METRICS_WORKING; then
    echo -e "${GREEN}✓ Metrics system is working correctly${NC}"
    echo -e "${GREEN}✓ HPA should be able to read CPU metrics${NC}"
    echo ""
    echo -e "${CYAN}If you still see warnings:${NC}"
    echo "  • Wait 30-60 seconds for initial metrics collection"
    echo "  • Warnings are normal during pod startup"
    echo "  • HPA will automatically recover once metrics are available"
else
    echo ""
    echo -e "${CYAN}Troubleshooting steps:${NC}"
    echo "  1. Check metrics server logs:"
    echo "     kubectl logs -n kube-system -l app=metrics-server"
    echo ""
    echo "  2. Verify metrics server has correct permissions:"
    echo "     kubectl get clusterrole system:metrics-server"
    echo ""
    echo "  3. Re-apply infrastructure to fix metrics server:"
    echo "     terraform -chdir=terraform apply -auto-approve"
fi

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
