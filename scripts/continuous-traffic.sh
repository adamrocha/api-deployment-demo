#!/bin/bash
# Quick script to generate continuous traffic for testing dashboards

echo "🚀 Generating continuous traffic to API endpoints..."
echo "Press Ctrl+C to stop"
echo ""

count=0
while true; do
    # Make parallel requests to different endpoints
    curl -s http://localhost:8000/ > /dev/null &
    curl -s http://localhost:8000/users > /dev/null &
    curl -s http://localhost:8000/products > /dev/null &
    curl -s http://localhost:8000/health > /dev/null &
    
    count=$((count + 4))
    
    if [ $((count % 40)) -eq 0 ]; then
        echo "📊 Generated $count requests..."
    fi
    
    # Small delay between batches
    sleep 0.5
done
