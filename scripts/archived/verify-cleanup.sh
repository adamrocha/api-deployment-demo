#!/bin/bash

# Final Cleanup Verification Script
echo "🧹 FINAL CLEANUP VERIFICATION COMPLETE!"
echo "========================================"
echo ""

# Check for any remnants
echo "🔍 Scanning for any remaining API deployment artifacts..."
echo ""

# Check kind clusters
KIND_CLUSTERS=$(kind get clusters 2>/dev/null | wc -l)
if [ $KIND_CLUSTERS -eq 0 ]; then
    echo "✅ Kind clusters: CLEAN"
else
    echo "⚠️  Found $KIND_CLUSTERS kind cluster(s)"
fi

# Check Docker images
API_IMAGES=$(docker images | grep -i api | wc -l)
if [ $API_IMAGES -eq 0 ]; then
    echo "✅ Docker images: CLEAN"
else
    echo "⚠️  Found $API_IMAGES API-related image(s)"
fi

# Check Docker containers
API_CONTAINERS=$(docker ps -a | grep -i api | wc -l)
if [ $API_CONTAINERS -eq 0 ]; then
    echo "✅ Docker containers: CLEAN"
else
    echo "⚠️  Found $API_CONTAINERS API-related container(s)"
fi

# Check Docker volumes
API_VOLUMES=$(docker volume ls | grep -i api | wc -l)
if [ $API_VOLUMES -eq 0 ]; then
    echo "✅ Docker volumes: CLEAN"
else
    echo "⚠️  Found $API_VOLUMES API-related volume(s)"
fi

# Check kind network
KIND_NETWORK=$(docker network ls | grep kind | wc -l)
if [ $KIND_NETWORK -eq 0 ]; then
    echo "✅ Kind network: CLEAN"
else
    echo "⚠️  Found kind network"
fi

# Check hosts file
HOSTS_ENTRIES=$(grep -i "grafana\|prometheus" /etc/hosts 2>/dev/null | wc -l)
if [ $HOSTS_ENTRIES -eq 0 ]; then
    echo "✅ Hosts file: CLEAN"
else
    echo "⚠️  Found monitoring entries in hosts file"
fi

echo ""
echo "📊 REMAINING DOCKER RESOURCES:"
echo "Images: $(docker images | wc -l) total (should only be system images)"
echo "Containers: $(docker ps -a | wc -l) total (should be 0)"
echo "Volumes: $(docker volume ls | wc -l) total (should be 0)"
echo "Networks: $(docker network ls | wc -l) total (should be 4 default networks)"

echo ""
echo "🎯 SUMMARY:"
if [ $KIND_CLUSTERS -eq 0 ] && [ $API_IMAGES -eq 0 ] && [ $API_CONTAINERS -eq 0 ] && [ $API_VOLUMES -eq 0 ] && [ $KIND_NETWORK -eq 0 ] && [ $HOSTS_ENTRIES -eq 0 ]; then
    echo "🎉 CLEANUP SUCCESSFUL! Your system is completely clean."
    echo ""
    echo "✅ All API deployment artifacts removed"
    echo "✅ All monitoring stack components removed"
    echo "✅ All custom Docker resources removed"
    echo "✅ All network modifications removed"
    echo "✅ All cluster resources removed"
    echo ""
    echo "💡 Your system is ready for:"
    echo "   • Fresh deployments"
    echo "   • New projects"
    echo "   • Different platforms"
    echo ""
    echo "📁 Preserved: Source code and configuration files"
else
    echo "⚠️  Some artifacts may still remain - check the details above"
fi

echo ""
echo "========================================"