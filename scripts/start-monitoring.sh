#!/bin/bash

# Persistent monitoring access script
# This script maintains port forwarding connections and restarts them if they fail

GRAFANA_PORT=3001
PROMETHEUS_PORT=9090

# Function to start port forwarding
start_grafana() {
    echo "Starting Grafana port forwarding on port $GRAFANA_PORT..."
    kubectl port-forward -n monitoring service/grafana $GRAFANA_PORT:3000 &
    GRAFANA_PID=$!
    echo "Grafana PID: $GRAFANA_PID"
}

start_prometheus() {
    echo "Starting Prometheus port forwarding on port $PROMETHEUS_PORT..."
    kubectl port-forward -n monitoring service/prometheus $PROMETHEUS_PORT:9090 &
    PROMETHEUS_PID=$!
    echo "Prometheus PID: $PROMETHEUS_PID"
}

# Function to check if port forwarding is working
check_service() {
    local port=$1
    local service=$2
    if ! curl -s http://localhost:$port/ --max-time 2 > /dev/null; then
        echo "$service not responding on port $port, restarting..."
        return 1
    fi
    return 0
}

# Cleanup function
cleanup() {
    echo "Stopping port forwarding..."
    if [ ! -z "$GRAFANA_PID" ]; then
        kill $GRAFANA_PID 2>/dev/null
    fi
    if [ ! -z "$PROMETHEUS_PID" ]; then
        kill $PROMETHEUS_PID 2>/dev/null
    fi
    # Kill any remaining kubectl port-forward processes
    pkill -f "kubectl.*port-forward.*monitoring" 2>/dev/null
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

echo "🚀 Starting persistent monitoring access..."
echo "Grafana will be available at: http://localhost:$GRAFANA_PORT"
echo "Prometheus will be available at: http://localhost:$PROMETHEUS_PORT"
echo "Press Ctrl+C to stop"

# Start initial port forwarding
start_grafana
start_prometheus

# Monitor and restart if needed
while true; do
    sleep 10
    
    # Check Grafana
    if ! check_service $GRAFANA_PORT "Grafana"; then
        if [ ! -z "$GRAFANA_PID" ]; then
            kill $GRAFANA_PID 2>/dev/null
        fi
        start_grafana
    fi
    
    # Check Prometheus
    if ! check_service $PROMETHEUS_PORT "Prometheus"; then
        if [ ! -z "$PROMETHEUS_PID" ]; then
            kill $PROMETHEUS_PID 2>/dev/null
        fi
        start_prometheus
    fi
done