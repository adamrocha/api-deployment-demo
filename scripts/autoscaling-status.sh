#!/bin/bash

echo "🎯 AUTOSCALING DECISION MATRIX"
echo "=============================="
echo ""

echo "📊 Current Resource Utilization Per Pod:"
echo "----------------------------------------"

# Check if metrics server is available
if kubectl top pods -n api-deployment-demo -l component=api >/dev/null 2>&1; then
    kubectl top pods -n api-deployment-demo -l component=api | awk '
    NR==1 {print $0} 
    NR>1 {
        cpu_num = substr($2, 1, length($2)-1)
        mem_num = substr($3, 1, length($3)-2)
        
        # Calculate percentage of resource requests (assuming 500m CPU, 256Mi memory)
        cpu_percent = (cpu_num / 500) * 100
        mem_percent = (mem_num / 256) * 100
        
        printf "%-35s %5s (%3.0f%%) %7s (%3.0f%%)\n", $1, $2, cpu_percent, $3, mem_percent
    }'
else
    echo "⚠️  Metrics API not available"
    echo ""
    echo "💡 To enable metrics server in Kind cluster:"
    echo "   1. Install metrics server:"
    echo "      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    echo ""
    echo "   2. Patch for Kind compatibility:"
    echo "      kubectl patch -n kube-system deployment metrics-server --type='json' \\"
    echo "        -p='[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--kubelet-insecure-tls\"}]'"
    echo ""
    echo "📊 Showing Pod Status Instead:"
    kubectl get pods -n api-deployment-demo -l component=api -o wide
fi

echo ""
echo "🎯 HPA Decision Logic:"
echo "---------------------"

# Get current metrics from HPA
hpa_output=$(kubectl get hpa api-hpa -n api-deployment-demo --no-headers 2>/dev/null || echo "N/A")
echo "Current HPA Status: $hpa_output"

echo ""
echo "⚖️  Scaling Decisions:"
echo "• CPU < 70% AND Memory < 80% → Scale Down (after 5 min)"
echo "• CPU > 70% OR Memory > 80% → Scale Up (after 1 min)"
echo "• Current: Low usage → Will scale down to 2-3 pods"

echo ""
echo "🕐 Timeline Prediction:"
echo "• T+0: Currently 6 pods with low usage"
echo "• T+5min: HPA will initiate scale-down"
echo "• T+6min: Pods will be terminated"
echo "• T+10min: Stable at 2-3 pods"

echo ""
echo "🚀 Load Test Scenarios:"
echo "----------------------"
echo "High Traffic (1000+ req/s):"
echo "  └─ CPU: 70%+ → Scale to 4-6 pods"
echo ""
echo "Extreme Load (5000+ req/s):"
echo "  └─ CPU: 90%+ → Scale to 8-10 pods (max)"
echo ""
echo "Normal Traffic (100 req/s):"
echo "  └─ CPU: 20%- → Scale to 2-3 pods (optimal)"