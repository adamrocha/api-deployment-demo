#!/bin/bash

# Self-signed SSL Certificate Generation Script for Nginx
# This script generates self-signed certificates for development/staging use

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="${SSL_DIR:-$SCRIPT_DIR/ssl}"
CERT_FILE="$SSL_DIR/nginx-selfsigned.crt"
KEY_FILE="$SSL_DIR/nginx-selfsigned.key"
CSR_FILE="$SSL_DIR/nginx-selfsigned.csr"
DHPARAM_FILE="$SSL_DIR/dhparam.pem"
SSL_CONFIG_FILE="$SSL_DIR/ssl-params.conf"

# Configuration
COUNTRY="${SSL_COUNTRY:-US}"
STATE="${SSL_STATE:-California}"
CITY="${SSL_CITY:-Los Angeles}"
ORGANIZATION="${SSL_ORGANIZATION:-API Demo Company}"
ORGANIZATIONAL_UNIT="${SSL_ORGANIZATIONAL_UNIT:-IT Department}"
COMMON_NAME="${SERVER_NAME:-localhost}"
EMAIL="${SSL_EMAIL:-admin@example.com}"

# Certificate validity (days)
DAYS_VALID="${SSL_DAYS_VALID:-365}"

# RSA key size
KEY_SIZE="${SSL_KEY_SIZE:-2048}"

echo "=== SSL Certificate Generation ==="
echo "Server Name: $COMMON_NAME"
echo "Validity: $DAYS_VALID days"
echo "Key Size: $KEY_SIZE bits"
echo "=================================="

# Create SSL directory if it doesn't exist
mkdir -p "$SSL_DIR"

# Check if certificates already exist and are valid
if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
    echo "SSL certificates already exist. Checking validity..."
    
    # Check if certificate is still valid for at least 30 days
    if openssl x509 -in "$CERT_FILE" -checkend 2592000 -noout >/dev/null 2>&1; then
        echo "Existing certificates are still valid. Skipping generation."
        
        # Ensure SSL config exists
        if [[ ! -f "$SSL_CONFIG_FILE" ]]; then
            echo "Creating SSL configuration file..."
            create_ssl_config
        fi
        
        exit 0
    else
        echo "Existing certificates are expired or expiring soon. Regenerating..."
    fi
fi

# Function to create SSL configuration
create_ssl_config() {
    cat > "$SSL_CONFIG_FILE" << EOF
# SSL Configuration Parameters
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam $DHPARAM_FILE;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# HSTS (optional)
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

# OCSP Stapling (commented out for self-signed certificates)
# ssl_stapling on;
# ssl_stapling_verify on;
EOF
}

echo "Generating self-signed certificate with private key..."

# Create temporary config file
TMP_CONFIG=$(mktemp)
cat > "$TMP_CONFIG" << EOF
[req]
default_bits = $KEY_SIZE
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORGANIZATION
OU = $ORGANIZATIONAL_UNIT
CN = $COMMON_NAME
emailAddress = $EMAIL

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
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

openssl req -x509 -nodes -days "$DAYS_VALID" -newkey rsa:"$KEY_SIZE" \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -config "$TMP_CONFIG" \
    -extensions v3_req

# Clean up temp config
rm -f "$TMP_CONFIG"

echo "Setting private key permissions..."
chmod 600 "$KEY_FILE"

echo "Generating Diffie-Hellman parameters (this may take a while)..."
if [[ ! -f "$DHPARAM_FILE" ]]; then
    openssl dhparam -out "$DHPARAM_FILE" 2048
fi

echo "Creating SSL configuration..."
create_ssl_config

echo "Setting certificate permissions..."
chmod 644 "$CERT_FILE" "$DHPARAM_FILE" "$SSL_CONFIG_FILE"
chmod 600 "$KEY_FILE"

# Clean up CSR file
rm -f "$CSR_FILE"

echo "=== SSL Certificate Generation Complete ==="
echo "Certificate: $CERT_FILE"
echo "Private Key: $KEY_FILE"
echo "DH Params: $DHPARAM_FILE"
echo "SSL Config: $SSL_CONFIG_FILE"
echo ""
echo "Certificate Information:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A 3 "Subject:"
openssl x509 -in "$CERT_FILE" -text -noout | grep -A 1 "Not Before\|Not After"
echo "============================================="

# Verify certificate
echo "Verifying certificate..."
if openssl verify -CAfile "$CERT_FILE" "$CERT_FILE" >/dev/null 2>&1; then
    echo "✅ Certificate verification successful (self-signed)"
else
    echo "⚠️  Certificate is self-signed (this is expected for development/staging)"
fi

echo "SSL certificate generation completed successfully!"