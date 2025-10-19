#!/bin/bash
# Complete End-to-End Alert Testing Script

echo "================================================"
echo "AIOps Complete Alert Flow Testing"
echo "================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function show_menu() {
    echo ""
    echo "Choose a test:"
    echo "1. Test internal connectivity (Python version)"
    echo "2. Send test alert via API (immediate LLM analysis)"
    echo "3. Trigger real CPU alert (wait for Prometheus)"
    echo "4. View recent LLM analysis results"
    echo "5. Complete end-to-end test (all steps)"
    echo "6. Check service health"
    echo "7. Exit"
    echo ""
    read -p "Enter choice [1-7]: " choice
}

function test_connectivity() {
    echo -e "${BLUE}Testing Internal Connectivity...${NC}"
    echo ""
    
    echo -n "AIOps Processor -> Prometheus... "
    if docker exec aiops-processor python3 -c "import httpx; r=httpx.get('http://prometheus:9090/-/healthy', timeout=5); exit(0 if r.status_code==200 else 1)" 2>/dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    echo -n "AIOps Processor -> Loki... "
    if docker exec aiops-processor python3 -c "import httpx; r=httpx.get('http://loki:3100/ready', timeout=5); exit(0 if r.status_code==200 else 1)" 2>/dev/null; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    echo -n "Prometheus -> Node Exporter... "
    if curl -s http://localhost:9090/api/v1/targets | grep -q "node-exporter.*up"; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    echo -n "AlertManager -> AIOps Processor... "
    if docker exec alertmanager wget -q -O- http://aiops-processor:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    echo ""
}

function send_test_alert() {
    echo -e "${BLUE}Sending Test Alert for Immediate Analysis...${NC}"
    echo ""
    
    echo "Creating test alert: HighCPUUsage"
    
    response=$(curl -s -X POST http://localhost:8000/analyze \
      -H "Content-Type: application/json" \
      -d '{
        "status": "firing",
        "labels": {
          "alertname": "TestHighCPUUsage",
          "severity": "warning",
          "instance": "node-exporter:9100",
          "job": "node-exporter"
        },
        "annotations": {
          "summary": "High CPU usage detected on node-exporter",
          "description": "CPU usage is above 80% threshold for more than 5 minutes"
        },
        "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
        "endsAt": "",
        "generatorURL": "http://prometheus:9090/graph",
        "fingerprint": "test-'$(date +%s)'"
      }')
    
    if echo "$response" | grep -q "root_cause"; then
        echo -e "${GREEN}✓ Alert sent and analyzed successfully!${NC}"
        echo ""
        echo -e "${YELLOW}Analysis Result:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
    else
        echo -e "${RED}✗ Alert analysis failed${NC}"
        echo "Response: $response"
    fi
    
    echo ""
}

function trigger_cpu_alert() {
    echo -e "${BLUE}Triggering Real CPU Alert...${NC}"
    echo ""
    
    echo "Step 1: Generating CPU load on node-exporter..."
    docker exec node-exporter sh -c "dd if=/dev/zero of=/dev/null &" 2>/dev/null
    docker exec node-exporter sh -c "dd if=/dev/zero of=/dev/null &" 2>/dev/null
    echo -e "${GREEN}✓ CPU load started${NC}"
    
    echo ""
    echo "Step 2: Waiting for Prometheus to detect high CPU (120 seconds)..."
    for i in {1..12}; do
        echo -n "."
        sleep 10
    done
    echo ""
    
    echo ""
    echo "Step 3: Checking if alert fired in Prometheus..."
    alerts=$(curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname | contains("CPU"))')
    
    if [ ! -z "$alerts" ]; then
        echo -e "${GREEN}✓ CPU alert is firing!${NC}"
        echo "$alerts" | jq '.'
    else
        echo -e "${YELLOW}⚠ Alert not yet firing, may need more time${NC}"
    fi
    
    echo ""
    echo "Step 4: Checking AlertManager..."
    am_alerts=$(curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.labels.alertname | contains("CPU"))')
    
    if [ ! -z "$am_alerts" ]; then
        echo -e "${GREEN}✓ Alert received by AlertManager!${NC}"
    else
        echo -e "${YELLOW}⚠ Alert not yet in AlertManager${NC}"
    fi
    
    echo ""
    echo "Step 5: Checking aiops-processor logs for analysis..."
    docker compose logs aiops-processor --tail 50 | grep -A 10 "root_cause\|Analysis completed"
    
    echo ""
    echo -e "${YELLOW}To stop the CPU load:${NC}"
    echo "  docker exec node-exporter sh -c 'killall dd'"
    echo ""
    
    read -p "Press Enter to stop CPU load now, or Ctrl+C to keep it running..."
    docker exec node-exporter sh -c "killall dd" 2>/dev/null
    echo -e "${GREEN}✓ CPU load stopped${NC}"
}

function view_llm_results() {
    echo -e "${BLUE}Recent LLM Analysis Results:${NC}"
    echo "================================================"
    echo ""
    
    docker compose logs aiops-processor | grep -B 5 -A 30 "root_cause" | tail -100
    
    echo ""
    echo "================================================"
    echo ""
}

function complete_test() {
    echo -e "${BLUE}Running Complete End-to-End Test${NC}"
    echo "================================================"
    echo ""
    
    echo -e "${YELLOW}Phase 1: Connectivity Test${NC}"
    test_connectivity
    
    echo ""
    echo -e "${YELLOW}Phase 2: Quick API Test${NC}"
    send_test_alert
    
    echo ""
    echo -e "${YELLOW}Phase 3: Full Alert Flow Test${NC}"
    echo "This will:"
    echo "  1. Generate CPU load"
    echo "  2. Wait for Prometheus alert (2 min)"
    echo "  3. Check AlertManager"
    echo "  4. View LLM analysis"
    echo ""
    read -p "Continue with full test? [y/N]: " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        trigger_cpu_alert
    else
        echo "Skipped full alert test"
    fi
    
    echo ""
    echo "================================================"
    echo -e "${GREEN}Complete Test Finished!${NC}"
    echo "================================================"
}

function check_health() {
    echo -e "${BLUE}Service Health Check${NC}"
    echo "================================================"
    echo ""
    
    echo "Docker Compose Status:"
    docker compose ps
    
    echo ""
    echo "AIOps Processor Health:"
    curl -s http://localhost:8000/health | jq '.' 2>/dev/null || curl -s http://localhost:8000/health
    
    echo ""
    echo "Alert Queue Status:"
    curl -s http://localhost:8000/queue/status | jq '.' 2>/dev/null || curl -s http://localhost:8000/queue/status
    
    echo ""
    echo "Prometheus Targets:"
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}' 2>/dev/null
    
    echo ""
    echo "Active Alerts:"
    curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, state: .state}' 2>/dev/null
    
    echo ""
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) test_connectivity ;;
        2) send_test_alert ;;
        3) trigger_cpu_alert ;;
        4) view_llm_results ;;
        5) complete_test ;;
        6) check_health ;;
        7) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
done

