#!/bin/bash

# Grafana Dashboard Verification Script
echo "🔍 Verifying Grafana Dashboard Configuration..."

# Check if all ConfigMaps exist
echo "📋 Checking ConfigMaps..."
kubectl get configmap -n monitoring grafana-dashboards grafana-datasources grafana-dashboard-providers 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ All ConfigMaps present"
else
    echo "❌ Missing ConfigMaps - run setup first"
    exit 1
fi

# Check if Grafana pod is running
echo "🏃 Checking Grafana pod status..."
POD_STATUS=$(kubectl get pods -n monitoring -l app=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
if [ "$POD_STATUS" = "Running" ]; then
    echo "✅ Grafana pod is running"
else
    echo "❌ Grafana pod not running: $POD_STATUS"
    exit 1
fi

# Test Grafana health
echo "🏥 Testing Grafana health..."
kubectl port-forward -n monitoring service/grafana 3002:3000 &
PF_PID=$!
sleep 3

HEALTH_CHECK=$(curl -s http://localhost:3002/api/health --max-time 5 2>/dev/null)
if echo "$HEALTH_CHECK" | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana health check failed"
fi

# Cleanup
kill $PF_PID 2>/dev/null

# Check if dashboard exists
echo "📊 Checking dashboard configuration..."
kubectl exec -n monitoring deployment/grafana -- ls -la /var/lib/grafana/dashboards/ 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Dashboard files mounted"
else
    echo "❌ Dashboard files not found"
fi

echo ""
echo "🎯 Access your dashboard at:"
echo "   Ingress:      http://grafana.local:8080"
echo "   Port-forward: kubectl port-forward -n monitoring service/grafana 3001:3000"
echo ""
echo "🔑 Login credentials:"
echo "   Username: admin"
echo "   Password: [see .env GRAFANA_ADMIN_PASSWORD]"
echo ""
echo "📈 Dashboard: 'API Deployment Demo - Metrics Dashboard'"