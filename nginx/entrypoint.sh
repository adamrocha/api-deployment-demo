#!/bin/sh

# Set SSL directory for certificate generation
export SSL_DIR="/etc/nginx/ssl"

# Check if SSL certificate files already exist (mounted from Kubernetes or elsewhere)
echo "Checking for SSL certificates in ${SSL_DIR}..."
if [ -f "${SSL_DIR}/tls.crt" ] && [ -f "${SSL_DIR}/tls.key" ]; then
	echo "SSL certificates found in ${SSL_DIR} - skipping generation"
else
	echo "No SSL certificates found. Attempting to generate..."
	# Test if directory is writable
	if touch "${SSL_DIR}/.test" 2>/dev/null; then
		rm -f "${SSL_DIR}/.test"
		echo "Directory is writable, generating certificates..."
		/usr/local/bin/generate-ssl.sh
		chmod 600 "${SSL_DIR}/tls.key" 2>/dev/null || true
		chmod 644 "${SSL_DIR}/tls.crt" 2>/dev/null || true
	else
		echo "Warning: ${SSL_DIR} is read-only (likely mounted from Kubernetes)"
		echo "Nginx will start but HTTPS may not work without mounted certificates"
	fi
fi

echo "Starting nginx..."
# Start nginx in foreground
exec nginx -g 'daemon off;'
