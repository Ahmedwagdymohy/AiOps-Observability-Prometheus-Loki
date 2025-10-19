#!/bin/bash

# ============================================================================
# Huawei Cloud API Test Script
# ============================================================================
# This script tests the Huawei Cloud DeepSeek API integration
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Huawei Cloud API Integration Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if services are running
echo -e "${YELLOW}Checking if services are running...${NC}"
if ! docker ps | grep -q aiops-processor; then
    echo -e "${RED}Error: aiops-processor container is not running${NC}"
    echo "Please start the services first: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ Services are running${NC}"
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "Response:"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "Response: $HEALTH_RESPONSE"
    exit 1
fi
echo ""

# Test 2: Queue Status
echo -e "${YELLOW}Test 2: Queue Status${NC}"
QUEUE_RESPONSE=$(curl -s http://localhost:8000/queue/status)
echo -e "${GREEN}✓ Queue status retrieved${NC}"
echo "Response:"
echo "$QUEUE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$QUEUE_RESPONSE"
echo ""

# Test 3: Send Test Alert
echo -e "${YELLOW}Test 3: Sending Test Alert${NC}"
echo "This will send a test alert for analysis. The analysis may take 30-60 seconds..."
echo ""

TEST_ALERT_PAYLOAD='{
  "status": "firing",
  "labels": {
    "alertname": "HighCPUUsage",
    "severity": "warning",
    "instance": "localhost:9100",
    "job": "node-exporter",
    "component": "cpu"
  },
  "annotations": {
    "summary": "CPU usage is critically high",
    "description": "CPU usage on localhost:9100 has exceeded 80% for the last 5 minutes. This may impact application performance."
  },
  "startsAt": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'",
  "generatorURL": "http://prometheus:9090/graph?g0.expr=node_cpu_usage",
  "fingerprint": "test123"
}'

echo "Sending alert payload..."
ANALYZE_RESPONSE=$(curl -s -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d "$TEST_ALERT_PAYLOAD")

# Check if response contains expected fields
if echo "$ANALYZE_RESPONSE" | grep -q "root_cause"; then
    echo -e "${GREEN}✓ Alert analysis completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Analysis Results:${NC}"
    echo "===================="
    echo "$ANALYZE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ANALYZE_RESPONSE"
else
    echo -e "${RED}✗ Alert analysis failed or incomplete${NC}"
    echo "Response: $ANALYZE_RESPONSE"
    
    # Check logs for more details
    echo ""
    echo -e "${YELLOW}Checking recent logs...${NC}"
    docker-compose logs --tail=50 aiops-processor | tail -20
    exit 1
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}✓ All tests passed!${NC}"
echo ""
echo "The Huawei Cloud DeepSeek API integration is working correctly."
echo ""
echo "Next steps:"
echo "  - Configure AlertManager to send alerts to http://localhost:8000/webhook/alerts"
echo "  - Monitor logs: docker-compose logs -f aiops-processor"
echo "  - Adjust model parameters in .env or docker-compose.override.yml"
echo ""

# Extract and display key metrics if available
if echo "$ANALYZE_RESPONSE" | grep -q "confidence"; then
    CONFIDENCE=$(echo "$ANALYZE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('confidence', 'N/A'))" 2>/dev/null || echo "N/A")
    echo "Analysis Confidence: $CONFIDENCE"
fi

echo ""
echo -e "${GREEN}Test complete! 🎉${NC}"

