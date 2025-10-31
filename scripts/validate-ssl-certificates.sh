#!/bin/bash

# Comprehensive SSL Certificate Validation Script
# Generates and validates self-signed certificates for development/staging

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
CSR_FILE="$SSL_DIR/nginx-selfsigned.csr"
DHPARAM_FILE="$SSL_DIR/dhparam.pem"
SSL_CONFIG_FILE="$SSL_DIR/ssl-params.conf"

# Certificate Details
COUNTRY="${SSL_COUNTRY:-US}"
STATE="${SSL_STATE:-California}"
CITY="${SSL_CITY:-Los Angeles}"
ORGANIZATION="${SSL_ORGANIZATION:-API Demo Company}"
ORGANIZATIONAL_UNIT="${SSL_ORGANIZATIONAL_UNIT:-IT Department}"
COMMON_NAME="${SERVER_NAME:-localhost}"
EMAIL="${SSL_EMAIL:-admin@apidemo.local}"
DAYS_VALID="${SSL_DAYS_VALID:-365}"
KEY_SIZE="${SSL_KEY_SIZE:-2048}"

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Function to create SSL directory
create_ssl_directory() {
    log "${BLUE}📁 Creating SSL directory...${NC}"
    mkdir -p "$SSL_DIR"
    chmod 755 "$SSL_DIR"
}

# Function to generate SSL configuration
create_ssl_config() {
    log "${BLUE}📝 Creating SSL configuration...${NC}"
    cat > "$SSL_CONFIG_FILE" << 'EOF'
# SSL Configuration Parameters for Nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/ssl/dhparam.pem;

# Strong cipher suites
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES128-GCM-SHA256;

# Session settings
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# OCSP Stapling (disabled for self-signed)
# ssl_stapling on;
# ssl_stapling_verify on;

# Security headers
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Frame-Options DENY always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
EOF
    chmod 644 "$SSL_CONFIG_FILE"
}

# Function to generate DH parameters
generate_dhparam() {
    if [[ ! -f "$DHPARAM_FILE" ]]; then
        log "${BLUE}🔐 Generating Diffie-Hellman parameters (this may take a while)...${NC}"
        openssl dhparam -out "$DHPARAM_FILE" 2048
        chmod 644 "$DHPARAM_FILE"
        log "${GREEN}✅ DH parameters generated${NC}"
    else
        log "${GREEN}✅ DH parameters already exist${NC}"
    fi
}

# Function to generate certificate signing request
generate_csr() {
    log "${BLUE}📄 Generating certificate signing request...${NC}"
    openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"
}

# Function to generate private key
generate_private_key() {
    log "${BLUE}🔑 Generating private key ($KEY_SIZE bits)...${NC}"
    openssl genrsa -out "$KEY_FILE" "$KEY_SIZE"
    chmod 600 "$KEY_FILE"
    log "${GREEN}✅ Private key generated${NC}"
}

# Function to generate self-signed certificate
generate_certificate() {
    log "${BLUE}🏆 Generating self-signed certificate...${NC}"
    
    # Create certificate with Subject Alternative Names
    openssl x509 -req -in "$CSR_FILE" -signkey "$KEY_FILE" -out "$CERT_FILE" -days "$DAYS_VALID" \
        -extensions v3_req -extfile <(cat << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORGANIZATION
OU = $ORGANIZATIONAL_UNIT
CN = $COMMON_NAME
emailAddress = $EMAIL

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $COMMON_NAME
DNS.2 = localhost
DNS.3 = *.localhost
DNS.4 = api-demo.local
DNS.5 = *.api-demo.local
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)
    
    chmod 644 "$CERT_FILE"
    rm -f "$CSR_FILE"
    log "${GREEN}✅ Certificate generated${NC}"
}

# Function to validate certificate
validate_certificate() {
    log "${BLUE}🔍 Validating certificate...${NC}"
    
    # Check certificate exists
    if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
        log "${RED}❌ Certificate or key file missing${NC}"
        return 1
    fi
    
    # Check certificate validity
    if ! openssl x509 -in "$CERT_FILE" -noout 2>/dev/null; then
        log "${RED}❌ Certificate file is invalid${NC}"
        return 1
    fi
    
    # Check private key validity
    if ! openssl rsa -in "$KEY_FILE" -check -noout 2>/dev/null; then
        log "${RED}❌ Private key file is invalid${NC}"
        return 1
    fi
    
    # Check certificate and key match
    cert_modulus=$(openssl x509 -noout -modulus -in "$CERT_FILE" | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)
    
    if [[ "$cert_modulus" != "$key_modulus" ]]; then
        log "${RED}❌ Certificate and private key don't match${NC}"
        return 1
    fi
    
    # Check certificate expiration
    if openssl x509 -in "$CERT_FILE" -checkend 86400 -noout >/dev/null 2>&1; then
        expiry_date=$(openssl x509 -in "$CERT_FILE" -enddate -noout | cut -d= -f2)
        log "${GREEN}✅ Certificate is valid (expires: $expiry_date)${NC}"
    else
        log "${YELLOW}⚠️  Certificate expires within 24 hours${NC}"
    fi
    
    # Display certificate information
    log "${BLUE}📋 Certificate Information:${NC}"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 5 "Subject:" || true
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 10 "Subject Alternative Name:" || true
    
    return 0
}

# Function to test HTTPS connectivity
test_https_connectivity() {
    log "${BLUE}🌐 Testing HTTPS connectivity...${NC}"
    
    # Test local HTTPS connection (skip verification for self-signed)
    if curl -k -s --max-time 10 "https://localhost/health" > /dev/null 2>&1; then
        log "${GREEN}✅ HTTPS connection successful${NC}"
    else
        log "${YELLOW}⚠️  HTTPS connection failed (service may not be running)${NC}"
    fi
    
    # Test certificate with OpenSSL
    if echo | openssl s_client -connect localhost:443 -servername localhost 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
        log "${GREEN}✅ SSL handshake successful${NC}"
    else
        log "${YELLOW}⚠️  SSL handshake failed (service may not be running)${NC}"
    fi
}

# Function to create nginx SSL configuration snippet
create_nginx_ssl_snippet() {
    local nginx_ssl_conf="/opt/github/api-deployment-demo/nginx/ssl-include.conf"
    
    log "${BLUE}📝 Creating Nginx SSL configuration snippet...${NC}"
    
    cat > "$nginx_ssl_conf" << 'EOF'
# SSL Certificate Configuration
ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

# Include SSL parameters
include /etc/nginx/ssl/ssl-params.conf;

# Additional SSL settings
ssl_buffer_size 8k;
ssl_early_data on;

# HTTPS redirect for HTTP requests
if ($scheme != "https") {
    return 301 https://$host$request_uri;
}
EOF
    
    log "${GREEN}✅ Nginx SSL configuration created: $nginx_ssl_conf${NC}"
}

# Function to display certificate chain
display_certificate_chain() {
    log "${BLUE}🔗 Certificate Chain Information:${NC}"
    echo ""
    
    echo "Certificate Subject:"
    openssl x509 -in "$CERT_FILE" -subject -noout | sed 's/^subject=/  /'
    
    echo ""
    echo "Certificate Issuer:"
    openssl x509 -in "$CERT_FILE" -issuer -noout | sed 's/^issuer=/  /'
    
    echo ""
    echo "Certificate Validity:"
    openssl x509 -in "$CERT_FILE" -dates -noout | sed 's/^/  /'
    
    echo ""
    echo "Certificate Fingerprint (SHA256):"
    openssl x509 -in "$CERT_FILE" -fingerprint -sha256 -noout | sed 's/^/  /'
    
    echo ""
    echo "Key Usage:"
    openssl x509 -in "$CERT_FILE" -text -noout | grep -A 5 "Key Usage:" | sed 's/^/  /' || echo "  Not specified"
    
    echo ""
}

# Function to generate certificate summary report
generate_summary_report() {
    local report_file="/opt/github/api-deployment-demo/ssl-certificate-report.txt"
    
    log "${BLUE}📊 Generating certificate summary report...${NC}"
    
    cat > "$report_file" << EOF
SSL Certificate Validation Report
=================================
Generated: $(date)

Certificate Files:
- Certificate: $CERT_FILE
- Private Key: $KEY_FILE
- DH Parameters: $DHPARAM_FILE
- SSL Config: $SSL_CONFIG_FILE

Certificate Details:
$(openssl x509 -in "$CERT_FILE" -text -noout | head -20)

Validation Status:
- Certificate Format: Valid
- Private Key Format: Valid
- Certificate-Key Pair: Matched
- Expiration: $(openssl x509 -in "$CERT_FILE" -enddate -noout | cut -d= -f2)

Security Configuration:
- Key Size: $KEY_SIZE bits
- Validity Period: $DAYS_VALID days
- Cipher Suites: Modern TLS 1.2/1.3
- Security Headers: Enabled

Usage Instructions:
1. Use -k flag with curl for self-signed certificates: curl -k https://localhost
2. Add certificate to trusted store for browsers
3. Replace with CA-signed certificate for production

EOF
    
    log "${GREEN}✅ Certificate report generated: $report_file${NC}"
}

# Main execution function
main() {
    log "${BLUE}🚀 Starting SSL Certificate Generation and Validation${NC}"
    echo "============================================================"
    echo ""
    
    # Create directory structure
    create_ssl_directory
    
    # Check if certificates already exist and are valid
    if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
        log "${YELLOW}📋 Existing certificates found, checking validity...${NC}"
        
        if openssl x509 -in "$CERT_FILE" -checkend 2592000 -noout >/dev/null 2>&1; then
            log "${GREEN}✅ Existing certificates are valid (>30 days remaining)${NC}"
            
            if validate_certificate; then
                display_certificate_chain
                test_https_connectivity
                generate_summary_report
                log "${GREEN}🎉 Certificate validation completed successfully!${NC}"
                return 0
            fi
        else
            log "${YELLOW}⚠️  Existing certificates are expired or expiring soon${NC}"
        fi
    fi
    
    # Generate new certificates
    log "${BLUE}🔨 Generating new SSL certificates...${NC}"
    
    generate_private_key
    generate_csr
    generate_certificate
    generate_dhparam
    create_ssl_config
    create_nginx_ssl_snippet
    
    # Validate generated certificates
    if validate_certificate; then
        display_certificate_chain
        test_https_connectivity
        generate_summary_report
        
        echo ""
        log "${GREEN}🎉 SSL Certificate generation and validation completed successfully!${NC}"
        echo ""
        log "${BLUE}📝 Next Steps:${NC}"
        echo "1. Restart your Nginx service to use the new certificates"
        echo "2. Test HTTPS connectivity: curl -k https://localhost"
        echo "3. For browsers, add certificate to trusted store or use -k flag"
        echo "4. Replace with CA-signed certificates for production use"
        echo ""
        log "${YELLOW}⚠️  Note: These are self-signed certificates for development use only${NC}"
    else
        log "${RED}❌ Certificate validation failed${NC}"
        return 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi