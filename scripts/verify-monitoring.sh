#!/bin/bash
# Monitoring Verification Script
# Verifies that monitoring stack and dashboards are deployed correctly

set -e

echo "🔍 Monitoring Stack Verification"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check monitoring namespace
echo "1. Checking monitoring namespace..."
if kubectl get namespace monitoring &>/dev/null; then
    echo -e "${GREEN}✓${NC} Monitoring namespace exists"
else
    echo -e "${RED}✗${NC} Monitoring namespace not found"
    exit 1
fi

# Check Prometheus pod
echo ""
echo "2. Checking Prometheus deployment..."
PROM_READY=$(kubectl get pods -n monitoring -l app=prometheus -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$PROM_READY" == "True" ]; then
    echo -e "${GREEN}✓${NC} Prometheus pod is ready"
else
    echo -e "${RED}✗${NC} Prometheus pod is not ready"
fi

# Check Grafana pod
echo ""
echo "3. Checking Grafana deployment..."
GRAFANA_READY=$(kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$GRAFANA_READY" == "True" ]; then
    echo -e "${GREEN}✓${NC} Grafana pod is ready"
else
    echo -e "${RED}✗${NC} Grafana pod is not ready"
fi

# Check ConfigMaps
echo ""
echo "4. Checking dashboard ConfigMaps..."
CONFIGMAPS=$(kubectl get configmaps -n monitoring -o name | grep grafana | wc -l)
if [ "$CONFIGMAPS" -ge 6 ]; then
    echo -e "${GREEN}✓${NC} All $CONFIGMAPS Grafana ConfigMaps present"
    kubectl get configmaps -n monitoring | grep grafana | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠${NC} Expected 6 ConfigMaps, found $CONFIGMAPS"
fi

# Check Grafana accessibility
echo ""
echo "5. Checking Grafana accessibility..."
if curl -s -f http://localhost:3000/api/health &>/dev/null; then
    echo -e "${GREEN}✓${NC} Grafana is accessible at http://localhost:3000"
else
    echo -e "${RED}✗${NC} Grafana is not accessible"
fi

# Check Prometheus accessibility
echo ""
echo "6. Checking Prometheus accessibility..."
if curl -s -f http://localhost:9090/-/healthy &>/dev/null; then
    echo -e "${GREEN}✓${NC} Prometheus is accessible at http://localhost:9090"
else
    echo -e "${RED}✗${NC} Prometheus is not accessible"
fi

# Check dashboards loaded
echo ""
echo "7. Checking loaded dashboards..."
DASHBOARDS=$(curl -s -u admin:admin "http://localhost:3000/api/search?type=dash-db" 2>/dev/null | jq -r '.[].title' 2>/dev/null || echo "")
if [ -n "$DASHBOARDS" ]; then
    DASHBOARD_COUNT=$(echo "$DASHBOARDS" | wc -l)
    echo -e "${GREEN}✓${NC} $DASHBOARD_COUNT dashboards loaded:"
    echo "$DASHBOARDS" | sed 's/^/  - /'
else
    echo -e "${RED}✗${NC} No dashboards found"
fi

# Check Prometheus data source
echo ""
echo "8. Checking Prometheus data source..."
DATASOURCE=$(curl -s -u admin:admin "http://localhost:3000/api/datasources/name/Prometheus" 2>/dev/null | jq -r '.name' 2>/dev/null || echo "")
if [ "$DATASOURCE" == "Prometheus" ]; then
    echo -e "${GREEN}✓${NC} Prometheus data source configured"
else
    echo -e "${RED}✗${NC} Prometheus data source not found"
fi

# Summary
echo ""
echo "================================"
echo "📊 Summary"
echo "================================"
echo ""
echo "Access URLs:"
echo "  • Grafana:    http://localhost:3000"
echo "  • Prometheus: http://localhost:9090"
echo ""
echo "Dashboard Location:"
echo "  Navigate to: Dashboards → Browse → API Demo"
echo ""
