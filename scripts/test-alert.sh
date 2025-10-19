#!/bin/bash

# Test Alert Script
# Manually send a test alert to the AIOps processor

echo "🧪 Testing AIOps Alert Processor"
echo "================================"
echo ""

AIOPS_URL="${AIOPS_URL:-http://localhost:8000}"

# Check if AIOps processor is running
echo "Checking AIOps processor health..."
if ! curl -sf "$AIOPS_URL/health" > /dev/null; then
    echo "❌ Error: AIOps processor is not reachable at $AIOPS_URL"
    echo "   Make sure the service is running: docker-compose ps"
    exit 1
fi

echo "✅ AIOps processor is healthy"
echo ""

# Test alert payload
TEST_ALERT=$(cat <<EOF
{
  "status": "firing",
  "labels": {
    "alertname": "HighCPUUsage",
    "severity": "warning",
    "instance": "node-exporter:9100",
    "component": "cpu",
    "job": "node-exporter",
    "service": "node-exporter",
    "environment": "production"
  },
  "annotations": {
    "summary": "High CPU usage detected on node-exporter:9100",
    "description": "CPU usage is above 80% (current value: 85.5%)",
    "runbook_url": "https://runbooks.example.com/high-cpu"
  },
  "startsAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "endsAt": "",
  "generatorURL": "http://prometheus:9090/graph?g0.expr=node_cpu_usage",
  "fingerprint": "test123456"
}
EOF
)

echo "📤 Sending test alert to $AIOPS_URL/analyze"
echo ""

# Send the test alert
RESPONSE=$(curl -s -X POST "$AIOPS_URL/analyze" \
  -H "Content-Type: application/json" \
  -d "$TEST_ALERT")

# Check if the request was successful
if [ $? -eq 0 ]; then
    echo "✅ Test alert sent successfully!"
    echo ""
    echo "📊 Response:"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo "💡 Check the logs for detailed analysis:"
    echo "   docker-compose logs -f aiops-processor"
else
    echo "❌ Failed to send test alert"
    exit 1
fi

echo ""
echo "🎉 Test complete!"


