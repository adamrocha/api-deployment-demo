#!/bin/bash

# Comprehensive cleanup script for API Deployment Demo
echo "🧹 Starting comprehensive cleanup of API Deployment Demo..."

# Function to delete namespace and wait
cleanup_namespace() {
    local namespace=$1
    echo "🗂️  Cleaning up namespace: $namespace"
    
    if kubectl get namespace $namespace >/dev/null 2>&1; then
        echo "   Deleting all resources in $namespace..."
        kubectl delete all --all -n $namespace --ignore-not-found=true
        
        echo "   Deleting ConfigMaps and Secrets..."
        kubectl delete configmaps --all -n $namespace --ignore-not-found=true
        kubectl delete secrets --all -n $namespace --ignore-not-found=true
        
        echo "   Deleting PVCs..."
        kubectl delete pvc --all -n $namespace --ignore-not-found=true
        
        echo "   Deleting Ingress resources..."
        kubectl delete ingress --all -n $namespace --ignore-not-found=true
        
        echo "   Deleting namespace $namespace..."
        kubectl delete namespace $namespace --ignore-not-found=true
        
        # Wait for namespace to be fully deleted
        echo "   Waiting for namespace $namespace to be deleted..."
        while kubectl get namespace $namespace >/dev/null 2>&1; do
            echo "     Still waiting for $namespace to be deleted..."
            sleep 5
        done
        echo "   ✅ Namespace $namespace deleted"
    else
        echo "   ⚠️  Namespace $namespace doesn't exist"
    fi
}

# Stop any background processes
echo "🛑 Stopping background processes..."
pkill -f "kubectl.*port-forward" 2>/dev/null || true
pkill -f "generate-traffic" 2>/dev/null || true

# Clean up our custom namespaces
cleanup_namespace "api-deployment-demo"
cleanup_namespace "monitoring"

# Clean up any remaining custom resources
echo "🔧 Cleaning up cluster-wide resources..."
kubectl delete clusterrole prometheus --ignore-not-found=true
kubectl delete clusterrolebinding prometheus --ignore-not-found=true

# Clean up ingress classes and controllers (keep the default ones)
echo "🌐 Cleaning up custom ingress resources..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true

# Show remaining resources
echo "📊 Remaining resources (should only show system resources):"
kubectl get all --all-namespaces | grep -v "kube-system\|ingress-nginx\|local-path-storage\|default"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "🏠 System namespaces preserved:"
echo "   - kube-system (Kubernetes core)"
echo "   - ingress-nginx (Ingress controller)"  
echo "   - local-path-storage (Storage provisioner)"
echo "   - default (Default namespace)"
echo ""
echo "🗑️  Removed namespaces:"
echo "   - api-deployment-demo (Your API application)"
echo "   - monitoring (Grafana & Prometheus)"
echo ""
echo "💡 To completely remove everything including the cluster:"
echo "   kind delete cluster --name api-demo-cluster"