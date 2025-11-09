#!/bin/bash
# =======================================================================
# Environment Variable Loader for Docker Compose
# =======================================================================
# This script reads the unified .env file and exports environment-specific
# variables based on the ENVIRONMENT value (staging or production).
#
# It converts prefixed variables (STG_*, PROD_*) to unprefixed
# variables that docker-compose can use.
#
# Usage: eval $(./scripts/load-env-vars.sh)
# =======================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE" >&2
    exit 1
fi

# Load the ENVIRONMENT variable from .env
ENVIRONMENT=$(grep "^ENVIRONMENT=" "$ENV_FILE" | head -1 | cut -d'=' -f2 | tr -d ' ' | tr -d '"' | tr -d "'")

if [ -z "$ENVIRONMENT" ]; then
    echo "Error: ENVIRONMENT not set in .env file" >&2
    exit 1
fi

# Determine the prefix based on environment
case "$ENVIRONMENT" in
    staging)
        PREFIX="STG_"
        ;;
    production)
        PREFIX="PROD_"
        ;;
    *)
        echo "Error: Invalid ENVIRONMENT value: $ENVIRONMENT (must be staging or production)" >&2
        exit 1
        ;;
esac

# Read .env file and export variables with the correct prefix
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    
    # Check if the key starts with our prefix
    if [[ "$key" == ${PREFIX}* ]]; then
        # Remove the prefix to get the clean variable name
        clean_key="${key#${PREFIX}}"
        
        # Remove inline comments (anything after #)
        value="${value%%#*}"
        
        # Trim trailing whitespace
        value="${value%"${value##*[![:space:]]}"}"
        
        # Remove quotes from value if present
        value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        
        # Export the variable without prefix
        export "${clean_key}=${value}"
        echo "export ${clean_key}='${value}'"
    fi
done < "$ENV_FILE"

# Also export ENVIRONMENT itself
export "ENVIRONMENT=$ENVIRONMENT"
echo "export ENVIRONMENT='$ENVIRONMENT'"
