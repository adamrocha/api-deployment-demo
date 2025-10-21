#!/bin/bash

# Nginx Health Check Script
# This script performs comprehensive health checks for the Nginx service

set -e

# Configuration
API_BACKEND="${API_UPSTREAM:-api:8000}"
TIMEOUT=10
RETRIES=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

# Function to check HTTP endpoint
check_endpoint() {
    local url="$1"
    local description="$2"
    local expected_code="${3:-200}"
    
    local attempt=1
    while [[ $attempt -le $RETRIES ]]; do
        if response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null); then
            if [[ "$response" == "$expected_code" ]]; then
                log "${GREEN}✅ $description: OK (HTTP $response)${NC}"
                return 0
            else
                log "${YELLOW}⚠️  $description: Unexpected response (HTTP $response)${NC}"
            fi
        else
            log "${RED}❌ $description: Connection failed (attempt $attempt/$RETRIES)${NC}"
        fi
        
        if [[ $attempt -lt $RETRIES ]]; then
            sleep 2
        fi
        ((attempt++))
    done
    
    log "${RED}❌ $description: Failed after $RETRIES attempts${NC}"
    return 1
}

# Function to check if Nginx is running
check_nginx_process() {
    if pgrep nginx >/dev/null 2>&1; then
        log "${GREEN}✅ Nginx process: Running${NC}"
        return 0
    else
        log "${RED}❌ Nginx process: Not running${NC}"
        return 1
    fi
}

# Function to check Nginx configuration
check_nginx_config() {
    if nginx -t >/dev/null 2>&1; then
        log "${GREEN}✅ Nginx configuration: Valid${NC}"
        return 0
    else
        log "${RED}❌ Nginx configuration: Invalid${NC}"
        nginx -t 2>&1 | head -5
        return 1
    fi
}

# Function to check SSL certificates (if SSL is enabled)
check_ssl_certificates() {
    local ssl_cert="/etc/nginx/ssl/nginx-selfsigned.crt"
    local ssl_key="/etc/nginx/ssl/nginx-selfsigned.key"
    
    if [[ "${SSL_ENABLED:-false}" == "true" ]]; then
        if [[ -f "$ssl_cert" && -f "$ssl_key" ]]; then
            # Check if certificate is still valid
            if openssl x509 -in "$ssl_cert" -checkend 86400 -noout >/dev/null 2>&1; then
                local expiry_date
                expiry_date=$(openssl x509 -in "$ssl_cert" -enddate -noout | cut -d= -f2)
                log "${GREEN}✅ SSL Certificate: Valid (expires: $expiry_date)${NC}"
                return 0
            else
                log "${YELLOW}⚠️  SSL Certificate: Expires within 24 hours${NC}"
                return 1
            fi
        else
            log "${RED}❌ SSL Certificate: Missing certificate or key files${NC}"
            return 1
        fi
    else
        log "${YELLOW}ℹ️  SSL: Disabled${NC}"
        return 0
    fi
}

# Function to check upstream API connectivity
check_api_upstream() {
    if [[ -n "$API_BACKEND" ]]; then
        local api_host
        local api_port
        api_host=$(echo "$API_BACKEND" | cut -d: -f1)
        api_port=$(echo "$API_BACKEND" | cut -d: -f2)
        
        if nc -z "$api_host" "$api_port" 2>/dev/null; then
            log "${GREEN}✅ API Upstream: Reachable ($API_BACKEND)${NC}"
            return 0
        else
            log "${RED}❌ API Upstream: Unreachable ($API_BACKEND)${NC}"
            return 1
        fi
    else
        log "${YELLOW}ℹ️  API Upstream: Not configured${NC}"
        return 0
    fi
}

# Main health check function
main_health_check() {
    log "🏥 Starting Nginx Health Check..."
    
    local exit_code=0
    
    # Check Nginx process
    if ! check_nginx_process; then
        exit_code=1
    fi
    
    # Check Nginx configuration
    if ! check_nginx_config; then
        exit_code=1
    fi
    
    # Check SSL certificates
    if ! check_ssl_certificates; then
        exit_code=1
    fi
    
    # Check API upstream connectivity
    if ! check_api_upstream; then
        exit_code=1
    fi
    
    # Check HTTP endpoints
    if ! check_endpoint "http://localhost/nginx-health" "Nginx HTTP health endpoint"; then
        exit_code=1
    fi
    
    if ! check_endpoint "http://localhost/health" "API health endpoint (via Nginx)"; then
        exit_code=1
    fi
    
    # Check HTTPS endpoints (if SSL is enabled)
    if [[ "${SSL_ENABLED:-false}" == "true" ]]; then
        if ! check_endpoint "https://localhost/nginx-health" "Nginx HTTPS health endpoint"; then
            exit_code=1
        fi
    fi
    
    # Summary
    if [[ $exit_code -eq 0 ]]; then
        log "${GREEN}🎉 All health checks passed!${NC}"
    else
        log "${RED}💥 Some health checks failed!${NC}"
    fi
    
    return $exit_code
}

# If script is run directly (not sourced), execute main health check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_health_check
    exit $?
fi