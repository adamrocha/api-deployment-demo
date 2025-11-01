#!/bin/bash

# Script to enable HTTPS with self-signed certificates in existing deployments

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# SSL Configuration
SSL_DIR="/opt/github/api-deployment-demo/nginx/ssl"
CERT_FILE="$SSL_DIR/nginx-selfsigned.crt"
KEY_FILE="$SSL_DIR/nginx-selfsigned.key"

# Function to log messages
log() {
    echo -e "$(date '+%H:%M:%S') $1"
}

# Function to enable HTTPS in Docker Compose
enable_https_docker_compose() {
    log "${BLUE}🐳 Enabling HTTPS in Docker Compose${NC}"
    echo "==================================="
    
    # Check if SSL certificates exist
    if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
        log "${RED}❌ SSL certificates not found. Run ./scripts/validate-ssl-certificates.sh first${NC}"
        return 1
    fi
    
    # Update docker-compose.yml to include HTTPS port
    local compose_file="docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        log "${BLUE}📝 Updating Docker Compose configuration...${NC}"
        
        # Check if HTTPS port is already configured
        if grep -q "443:443" "$compose_file"; then
            log "${GREEN}✅ HTTPS port already configured in Docker Compose${NC}"
        else
            log "${YELLOW}⚠️  HTTPS port not found in Docker Compose${NC}"
            log "${BLUE}💡 Add the following to your nginx service ports:${NC}"
            echo "    - \"443:443\""
        fi
        
        # Check if SSL volume is mounted
        if grep -q "/etc/nginx/ssl" "$compose_file"; then
            log "${GREEN}✅ SSL volume already mounted${NC}"
        else
            log "${YELLOW}⚠️  SSL volume not mounted${NC}"
            log "${BLUE}💡 Add the following to your nginx service volumes:${NC}"
            echo "    - ./nginx/ssl:/etc/nginx/ssl:ro"
        fi
    else
        log "${YELLOW}⚠️  docker-compose.yml not found${NC}"
    fi
    
    # Test HTTPS with Docker Compose
    log "${BLUE}🧪 Testing HTTPS with Docker Compose...${NC}"
    if docker compose ps | grep -q "nginx.*Up"; then
        log "${GREEN}✅ Nginx container is running${NC}"
        
        # Test HTTPS endpoint
        if curl -k -s --max-time 5 "https://localhost/health" >/dev/null 2>&1; then
            log "${GREEN}✅ HTTPS endpoint accessible${NC}"
        else
            log "${YELLOW}⚠️  HTTPS endpoint not accessible${NC}"
            log "${BLUE}💡 Make sure SSL is enabled in nginx configuration${NC}"
        fi
    else
        log "${YELLOW}⚠️  Nginx container not running${NC}"
    fi
    
    echo ""
}

# Function to create Kubernetes TLS secret
create_kubernetes_tls_secret() {
    log "${BLUE}🎛️ Creating Kubernetes TLS Secret${NC}"
    echo "================================="
    
    # Check if SSL certificates exist
    if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
        log "${RED}❌ SSL certificates not found. Run ./scripts/validate-ssl-certificates.sh first${NC}"
        return 1
    fi
    
    local namespace="api-deployment-demo"
    local secret_name="nginx-tls-secret"
    
    # Create TLS secret
    log "${BLUE}🔐 Creating TLS secret in Kubernetes...${NC}"
    kubectl create secret tls "$secret_name" \
        --cert="$CERT_FILE" \
        --key="$KEY_FILE" \
        -n "$namespace" \
        --dry-run=client -o yaml > kubernetes/tls-secret.yaml
    
    log "${GREEN}✅ TLS secret YAML created: kubernetes/tls-secret.yaml${NC}"
    
    # Apply the secret if cluster is available
    if kubectl cluster-info >/dev/null 2>&1; then
        log "${BLUE}🚀 Applying TLS secret to cluster...${NC}"
        kubectl apply -f kubernetes/tls-secret.yaml
        log "${GREEN}✅ TLS secret applied to cluster${NC}"
        
        # Verify secret
        if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
            log "${GREEN}✅ TLS secret verified in cluster${NC}"
        else
            log "${RED}❌ TLS secret not found in cluster${NC}"
        fi
    else
        log "${YELLOW}⚠️  Kubernetes cluster not available${NC}"
    fi
    
    echo ""
}

# Function to update nginx configuration for HTTPS
update_nginx_https_config() {
    log "${BLUE}🌐 Updating Nginx HTTPS Configuration${NC}"
    echo "===================================="
    
    local nginx_conf="nginx/nginx.conf"
    
    if [[ -f "$nginx_conf" ]]; then
        # Check if HTTPS server block exists
        if grep -q "listen 443 ssl" "$nginx_conf"; then
            log "${GREEN}✅ HTTPS server block already exists${NC}"
        else
            log "${BLUE}📝 Adding HTTPS server block to nginx.conf...${NC}"
            
            # Create HTTPS server block
            cat >> "$nginx_conf" << 'EOF'

# HTTPS Server Block
server {
    listen 443 ssl http2;
    server_name localhost api-demo.local;

    # SSL Configuration
    include /etc/nginx/ssl/ssl-params.conf;
    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;

    # Proxy settings
    location / {
        proxy_pass http://api:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name localhost api-demo.local;
    return 301 https://$server_name$request_uri;
}
EOF
            log "${GREEN}✅ HTTPS server block added${NC}"
        fi
    else
        log "${YELLOW}⚠️  nginx.conf not found${NC}"
    fi
    
    echo ""
}

# Function to test HTTPS functionality
test_https_functionality() {
    log "${BLUE}🧪 Testing HTTPS Functionality${NC}"
    echo "============================="
    
    local test_urls=(
        "https://localhost/health"
        "https://localhost:8443/health"
        "https://127.0.0.1/health"
    )
    
    for url in "${test_urls[@]}"; do
        log "${BLUE}Testing: $url${NC}"
        
        # Test with curl (ignore certificate validation)
        if curl -k -s --max-time 5 "$url" >/dev/null 2>&1; then
            log "${GREEN}✅ $url - Accessible${NC}"
        else
            log "${YELLOW}⚠️  $url - Not accessible${NC}"
        fi
        
        # Test SSL handshake
        local host_port
        host_port=$(echo "$url" | sed 's|https://||' | sed 's|/.*||')
        if [[ "$host_port" != *":"* ]]; then
            host_port="$host_port:443"
        fi
        
        if echo | openssl s_client -connect "$host_port" -servername localhost </dev/null >/dev/null 2>&1; then
            log "${GREEN}✅ SSL handshake successful for $host_port${NC}"
        else
            log "${YELLOW}⚠️  SSL handshake failed for $host_port${NC}"
        fi
    done
    
    echo ""
}

# Function to display HTTPS usage guide
display_https_usage_guide() {
    log "${BLUE}📚 HTTPS Usage Guide${NC}"
    echo "===================="
    
    cat << 'EOF'
🌐 Browser Testing:
1. Navigate to https://localhost
2. Accept the security warning (self-signed certificate)
3. Or add certificate to browser's trusted store

🔧 Command Line Testing:
1. curl -k https://localhost/health          # Ignore certificate validation
2. curl --cacert nginx/ssl/nginx-selfsigned.crt https://localhost/health  # Use certificate as CA
3. openssl s_client -connect localhost:443   # Test SSL handshake

🐳 Docker Compose HTTPS:
1. Ensure nginx service has port 443:443 mapped
2. Mount SSL volume: ./nginx/ssl:/etc/nginx/ssl:ro
3. Update nginx.conf with HTTPS server block
4. Restart: docker compose down && docker compose up

🎛️ Kubernetes HTTPS:
1. Apply TLS secret: kubectl apply -f kubernetes/tls-secret.yaml
2. Update ingress to use TLS
3. Configure nginx deployment to use certificates
4. Test with: kubectl port-forward svc/nginx 443:443

🔐 Security Best Practices:
1. Use these certificates only for development/staging
2. Replace with CA-signed certificates for production
3. Monitor certificate expiration dates
4. Implement automatic certificate rotation

⚠️  Remember: Self-signed certificates will show security warnings in browsers.
This is normal and expected for development environments.
EOF
    
    echo ""
}

# Function to create ingress with TLS
create_tls_ingress() {
    log "${BLUE}🌐 Creating TLS Ingress Configuration${NC}"
    echo "==================================="
    
    cat > kubernetes/https-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-demo-https-ingress
  namespace: api-deployment-demo
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - localhost
    - api-demo.local
    secretName: nginx-tls-secret
  rules:
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
  - host: api-demo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
EOF
    
    log "${GREEN}✅ HTTPS Ingress configuration created: kubernetes/https-ingress.yaml${NC}"
    echo ""
}

# Main function
main() {
    log "${BLUE}🚀 Enabling HTTPS with Self-Signed Certificates${NC}"
    echo "==============================================="
    echo ""
    
    # Check if certificates exist
    if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
        log "${YELLOW}⚠️  SSL certificates not found${NC}"
        log "${BLUE}🔧 Generating SSL certificates first...${NC}"
        ./scripts/validate-ssl-certificates.sh
    fi
    
    # Enable HTTPS in different environments
    enable_https_docker_compose
    create_kubernetes_tls_secret
    create_tls_ingress
    update_nginx_https_config
    test_https_functionality
    display_https_usage_guide
    
    log "${GREEN}🎉 HTTPS configuration completed!${NC}"
    echo ""
    log "${BLUE}📝 Summary of changes:${NC}"
    echo "- SSL certificates validated and ready"
    echo "- Kubernetes TLS secret created"
    echo "- HTTPS ingress configuration generated"
    echo "- Nginx HTTPS configuration updated"
    echo "- Usage examples and guides provided"
    echo ""
    log "${YELLOW}💡 Next steps:${NC}"
    echo "1. Restart your services to apply HTTPS configuration"
    echo "2. Test HTTPS endpoints with: curl -k https://localhost/health"
    echo "3. Configure clients to trust the self-signed certificate"
    echo "4. Plan certificate replacement for production use"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi