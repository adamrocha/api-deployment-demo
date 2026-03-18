#!/bin/bash

# Traffic Generator for Dashboard Demo
echo "🚦 Starting traffic generation for dashboard demo..."

# Function to generate random traffic
generate_traffic() {
	local duration=${1:-60}
	local endpoint_count=0

	echo "📈 Generating traffic for $duration seconds..."

	end_time=$((SECONDS + duration))
	while [ $SECONDS -lt $end_time ]; do
		# Random endpoint selection
		ENDPOINT_NUM=$((RANDOM % 3))
		case $ENDPOINT_NUM in
		0) ENDPOINT="/" ;;
		1) ENDPOINT="/users" ;;
		2) ENDPOINT="/products" ;;
		esac

		# Execute request
		kubectl exec deployment/api-deployment -n api-deployment-demo -- \
			curl -s http://localhost:8000"$ENDPOINT" >/dev/null 2>&1

		endpoint_count=$((endpoint_count + 1))

		# Random delay between 0.1 and 2 seconds
		DELAY=$(echo "scale=1; ($RANDOM % 20) / 10" | bc -l 2>/dev/null || echo "1")
		sleep "${DELAY:-1}"

		# Progress indicator every 10 requests
		if [ $((endpoint_count % 10)) -eq 0 ]; then
			echo "📊 Generated $endpoint_count requests..."
		fi
	done

	echo "✅ Traffic generation complete: $endpoint_count total requests"
}

# Function to create some database activity
create_db_activity() {
	echo "👥 Creating database activity..."

	# Create a few test users with consistent names
	for i in {1..3}; do
		kubectl exec deployment/api-deployment -n api-deployment-demo -- \
			curl -s -X POST http://localhost:8000/users \
			-H "Content-Type: application/json" \
			-d "{\"name\":\"TestUser${i}\",\"email\":\"testuser${i}@example.com\"}" >/dev/null 2>&1
		sleep 1
	done

	echo "✅ Database activity generated"
}

# Main execution
echo "🎯 Dashboard Traffic Generator"
echo "This will generate realistic traffic patterns for your Grafana dashboard"
echo ""

# Create initial database activity
create_db_activity

# Generate traffic patterns
echo "🔄 Starting continuous traffic generation..."
echo "Press Ctrl+C to stop"

trap 'echo "🛑 Stopping traffic generation..."; exit 0' INT

# Continuous traffic generation
while true; do
	# Generate burst traffic
	echo "💥 Generating burst traffic (30 seconds)..."
	generate_traffic 30

	# Quiet period
	echo "😴 Quiet period (10 seconds)..."
	sleep 10

	# Steady traffic
	echo "📈 Steady traffic (60 seconds)..."
	generate_traffic 60

	# Brief pause
	echo "⏸️  Brief pause (5 seconds)..."
	sleep 5
done
