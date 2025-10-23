#!/bin/bash

# Host-based Nginx Health Check Script
# This script performs health checks for the Nginx service from the host machine

set -e

# Configuration
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

# Function to check Docker containers
check_containers() {
    log "🐳 Checking Docker containers..."
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        log "${RED}❌ Docker Compose: Not available${NC}"
        return 1
    fi
    
    # Check if containers are running
    local containers_status
    containers_status=$(docker-compose ps --format json 2>/dev/null)
    
    if [[ -z "$containers_status" ]]; then
        log "${RED}❌ Docker containers: No containers found${NC}"
        return 1
    fi
    
    # Check each service
    local nginx_running=false
    local api_running=false
    local postgres_running=false
    
    while IFS= read -r container; do
        local name service status
        name=$(echo "$container" | jq -r '.Name // empty' 2>/dev/null || echo "")
        service=$(echo "$container" | jq -r '.Service // empty' 2>/dev/null || echo "")
        status=$(echo "$container" | jq -r '.State // empty' 2>/dev/null || echo "")
        
        case "$service" in
            "nginx")
                if [[ "$status" == "running" ]]; then
                    nginx_running=true
                    log "${GREEN}✅ Nginx container: Running${NC}"
                else
                    log "${RED}❌ Nginx container: $status${NC}"
                fi
                ;;
            "api")
                if [[ "$status" == "running" ]]; then
                    api_running=true
                    log "${GREEN}✅ API container: Running${NC}"
                else
                    log "${RED}❌ API container: $status${NC}"
                fi
                ;;
            "postgres")
                if [[ "$status" == "running" ]]; then
                    postgres_running=true
                    log "${GREEN}✅ PostgreSQL container: Running${NC}"
                else
                    log "${RED}❌ PostgreSQL container: $status${NC}"
                fi
                ;;
        esac
    done <<< "$containers_status"
    
    if [[ "$nginx_running" == true && "$api_running" == true && "$postgres_running" == true ]]; then
        return 0
    else
        return 1
    fi
}

# Main health check function
main_health_check() {
    log "🏥 Starting Host-based Health Check..."
    
    local exit_code=0
    
    # Check Docker containers
    if ! check_containers; then
        exit_code=1
    fi
    
    # Check HTTP endpoints from host
    if ! check_endpoint "http://localhost:80/nginx-health" "Nginx HTTP health endpoint (host)"; then
        exit_code=1
    fi
    
    if ! check_endpoint "http://localhost:80/health" "API health endpoint via Nginx (host)"; then
        exit_code=1
    fi
    
    if ! check_endpoint "http://localhost:8000/health" "API direct health endpoint (host)"; then
        exit_code=1
    fi
    
    # Test API functionality
    log "🔍 Testing API functionality..."
    if ! check_endpoint "http://localhost:80/users/" "API users endpoint via Nginx" "200"; then
        exit_code=1
    fi
    
    if ! check_endpoint "http://localhost:8000/users/" "API users endpoint direct" "200"; then
        exit_code=1
    fi
    
    # Summary
    if [[ $exit_code -eq 0 ]]; then
        log "${GREEN}🎉 All health checks passed!${NC}"
    else
        log "${RED}💥 Some health checks failed!${NC}"
    fi
    
    return $exit_code
}

# If script is run directly, execute main health check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_health_check
    exit $?
fi