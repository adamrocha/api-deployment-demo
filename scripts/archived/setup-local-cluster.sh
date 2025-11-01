#!/bin/bash

# =============================================================================
# Local Kubernetes Cluster Setup for Testing
# =============================================================================
# This script sets up a local Kubernetes cluster using kind (Kubernetes in Docker)

set -e

echo "🚀 Local Kubernetes Cluster Setup"
echo "================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo "Please start Docker Desktop or Docker daemon"
    exit 1
fi

echo -e "${GREEN}✅ Docker is running${NC}"

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${YELLOW}📦 Installing kind (Kubernetes in Docker)...${NC}"
    
    # Install kind for different platforms
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install kind
        else
            echo "Installing kind via direct download..."
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    else
        echo -e "${RED}❌ Unsupported OS. Please install kind manually: https://kind.sigs.k8s.io/docs/user/quick-start/${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ kind is already installed${NC}"
fi

# Create kind cluster configuration
cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: api-demo-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
- role: worker
- role: worker
EOF

echo -e "${BLUE}🔧 Creating kind cluster...${NC}"

# Delete existing cluster if it exists
if kind get clusters | grep -q "api-demo-cluster"; then
    echo "🗑️ Deleting existing cluster..."
    kind delete cluster --name api-demo-cluster
fi

# Create new cluster
kind create cluster --config kind-config.yaml

echo -e "${GREEN}✅ Kind cluster created${NC}"

# Update kubectl context
kubectl cluster-info --context kind-api-demo-cluster

echo ""
echo -e "${BLUE}📋 Cluster Information${NC}"
echo "----------------------"
kubectl get nodes
echo ""

# Install ingress controller for kind
echo -e "${BLUE}🌐 Installing nginx-ingress for kind...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo -e "${GREEN}✅ Nginx ingress controller ready${NC}"

echo ""
echo -e "${GREEN}🎉 Local Kubernetes cluster is ready for testing!${NC}"
echo ""
echo "📝 Next steps:"
echo "1. Run the production deployment test:"
echo "   ./scripts/test-production-deployment.sh"
echo ""
echo "2. Access services via localhost:"
echo "   http://localhost:8080 (port 8080 -> kind port 80)"
echo "   https://localhost:8443 (port 8443 -> kind port 443)"
echo ""
echo "3. Add to /etc/hosts for domain testing:"
echo "   echo '127.0.0.1 api-demo.staging.local' | sudo tee -a /etc/hosts"
echo ""
echo "4. Clean up when done:"
echo "   kind delete cluster --name api-demo-cluster"