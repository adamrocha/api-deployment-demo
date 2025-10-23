#!/bin/bash

# Quick Start Guide for API Deployment Demo
# This script demonstrates the Makefile commands

set -e

echo "🚀 API Deployment Demo - Quick Start Guide"
echo "=========================================="
echo ""

# Function to prompt user
prompt_user() {
    read -p "$1 (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Show available commands
echo "📋 Available Makefile commands:"
make help
echo ""

# Ask what environment to start
echo "🤔 Which environment would you like to start?"
echo ""
echo "1. Staging (Docker Compose) - Quick and simple"
echo "2. Production (Kubernetes) - Full production setup"
echo "3. Production + Monitoring - Complete observability stack"
echo "4. Development - Staging with extra tools"
echo "5. Just show me the commands"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "🐳 Starting staging environment..."
        echo "Command: make staging"
        echo ""
        if prompt_user "Do you want to build fresh images first?"; then
            make staging-build
        else
            make staging
        fi
        echo ""
        echo "✅ Staging environment is ready!"
        echo ""
        echo "📋 Useful commands:"
        echo "  make staging-status  # Check status"
        echo "  make staging-logs    # View logs"
        echo "  make traffic         # Generate test traffic"
        echo "  make staging-stop    # Stop environment"
        ;;
    2)
        echo ""
        echo "🎯 Starting production environment..."
        echo "Command: make production"
        echo ""
        make production
        echo ""
        echo "✅ Production environment is ready!"
        echo ""
        echo "📋 Useful commands:"
        echo "  make production-status  # Check status"
        echo "  make production-logs    # View logs"
        echo "  make traffic            # Generate test traffic"
        echo "  make production-stop    # Stop environment"
        ;;
    3)
        echo ""
        echo "📊 Starting production + monitoring..."
        echo "Commands: make production && make monitoring"
        echo ""
        make production
        make monitoring
        echo ""
        if prompt_user "Do you want to add monitoring hosts to /etc/hosts?"; then
            make setup-hosts
        fi
        echo ""
        echo "✅ Full production environment with monitoring is ready!"
        echo ""
        echo "📋 Access points:"
        echo "  API:        http://localhost:8080"
        echo "  Grafana:    http://grafana.local:8080 (admin/[see .env])"
        echo "  Prometheus: http://prometheus.local:8080"
        echo ""
        echo "📋 Useful commands:"
        echo "  make status              # Check all status"
        echo "  make monitoring-status   # Check monitoring"
        echo "  make traffic            # Generate test traffic"
        echo "  make clean              # Clean everything"
        ;;
    4)
        echo ""
        echo "🛠️ Starting development environment..."
        echo "Command: make dev"
        echo ""
        make dev
        echo ""
        echo "✅ Development environment is ready!"
        echo ""
        echo "📋 Useful commands:"
        echo "  make status  # Check status"
        echo "  make logs    # View logs"
        echo "  make traffic # Generate test traffic"
        ;;
    5)
        echo ""
        echo "📚 Common command patterns:"
        echo ""
        echo "🚀 Quick starts:"
        echo "  make quick-staging     # Build and start staging"
        echo "  make quick-production  # Full production with monitoring"
        echo "  make quick-dev         # Full development setup"
        echo ""
        echo "🔧 Environment management:"
        echo "  make staging           # Start staging (Docker Compose)"
        echo "  make production        # Start production (Kubernetes)"
        echo "  make monitoring        # Add monitoring to production"
        echo ""
        echo "📊 Monitoring & debugging:"
        echo "  make status            # Check active environment"
        echo "  make logs              # View logs for active environment"
        echo "  make traffic           # Generate test traffic"
        echo ""
        echo "🧹 Cleanup:"
        echo "  make clean             # Clean everything"
        echo "  make clean-staging     # Clean only staging"
        echo "  make clean-production  # Clean only production"
        echo ""
        echo "🛠️ Development:"
        echo "  make docker-images     # Build all images"
        echo "  make validate          # Validate all configs"
        echo "  make help              # Show all commands"
        echo ""
        exit 0
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "🎉 Environment is ready! Here are some things you can try:"
echo ""
echo "🔍 Check status:"
echo "  make status"
echo ""
echo "📊 Generate some test traffic:"
echo "  make traffic"
echo ""
echo "📝 View logs:"
echo "  make logs"
echo ""
echo "🧹 When you're done, clean up:"
echo "  make clean"
echo ""
echo "💡 For all available commands, run:"
echo "  make help"