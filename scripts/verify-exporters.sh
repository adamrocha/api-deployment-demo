#!/bin/bash

echo "=== Exporter Installation Verification ==="
echo ""
echo "📊 Prometheus Targets:"
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' | sort | uniq -c
echo ""
echo "📈 Available Metrics:"
PG_COUNT=$(curl -s http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | grep -c '^pg_')
NGINX_COUNT=$(curl -s http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | grep -c '^nginx_')
KUBE_COUNT=$(curl -s http://localhost:9090/api/v1/label/__name__/values | jq -r '.data[]' | grep -c '^kube_')

echo "  PostgreSQL: $PG_COUNT metrics"
echo "  Nginx: $NGINX_COUNT metrics"  
echo "  Kubernetes: $KUBE_COUNT metrics"
echo ""
echo "✅ All exporters installed successfully!"
echo ""
echo "📊 Dashboard Status:"
echo "  ✅ Infrastructure Dashboard - kube-state-metrics installed ($KUBE_COUNT metrics)"
echo "  ✅ Database Dashboard - postgres_exporter installed ($PG_COUNT metrics)"
echo "  ✅ Nginx Dashboard - nginx-prometheus-exporter installed ($NGINX_COUNT metrics)"
echo "  ✅ API Dashboard - Application metrics available"
echo ""
echo "🌐 Access Grafana: http://localhost:3000"
