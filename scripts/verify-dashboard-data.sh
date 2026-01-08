#!/bin/bash
# Dashboard Data Verification Script

echo "🔍 Verifying Dashboard Data Pipeline"
echo "====================================="
echo ""

# Check Prometheus targets
echo "1. Checking Prometheus targets..."
TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"')
echo "$TARGETS"
echo ""

# Check if API metrics exist
echo "2. Checking if http_requests_total metrics exist..."
METRIC_COUNT=$(curl -s 'http://localhost:9090/api/v1/query?query=http_requests_total' | jq '.data.result | length')
echo "Found $METRIC_COUNT metric series"
echo ""

# Show latest values
echo "3. Latest metric values:"
curl -s http://localhost:8000/metrics | grep "^http_requests_total{" | head -3
echo ""

# Check Grafana datasource
echo "4. Checking Grafana datasource..."
DS_NAME=$(curl -s -u admin:admin http://localhost:3000/api/datasources/1 2>/dev/null | jq -r '.name')
DS_URL=$(curl -s -u admin:admin http://localhost:3000/api/datasources/1 2>/dev/null | jq -r '.url')
echo "Datasource: $DS_NAME at $DS_URL"
echo ""

# Test query through Grafana
echo "5. Testing query through Grafana..."
RESULT=$(curl -s -u admin:admin http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up 2>/dev/null | jq '.data.result | length')
echo "Query returned $RESULT results"
echo ""

# Check dashboards
echo "6. Available dashboards:"
curl -s -u admin:admin http://localhost:3000/api/search?type=dash-db 2>/dev/null | jq -r '.[] | "  - \(.title)"'
echo ""

echo "====================================="
echo "✅ Verification complete!"
echo ""
echo "📊 To see live data:"
echo "   1. Open: http://localhost:3000"
echo "   2. Navigate: Dashboards → Browse → API Demo"
echo "   3. Generate traffic: ./scripts/continuous-traffic.sh"
echo ""
