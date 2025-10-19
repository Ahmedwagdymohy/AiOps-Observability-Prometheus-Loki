#!/bin/bash
# Script to verify all services are connected and working

echo "================================================"
echo "AIOps Service Connectivity Verification"
echo "================================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function check_service() {
    local service_name=$1
    local url=$2
    local container=$3
    
    echo -n "Checking $service_name... "
    
    # Check if container is running
    if ! docker ps | grep -q "$container"; then
        echo -e "${RED}✗ Container not running${NC}"
        return 1
    fi
    
    # Check HTTP endpoint
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Running and accessible${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Running but endpoint not responding${NC}"
        return 1
    fi
}

function check_internal_connectivity() {
    echo ""
    echo "================================================"
    echo "Testing Internal Connectivity"
    echo "================================================"
    
    echo ""
    echo -n "AIOps Processor -> Prometheus... "
    if docker exec aiops-processor wget -q -O- http://prometheus:9090/-/healthy > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
    
    echo -n "AIOps Processor -> Loki... "
    if docker exec aiops-processor wget -q -O- http://loki:3100/ready > /dev/null 2>&1; then
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
    
    echo -n "Promtail -> Loki... "
    if docker exec promtail wget -q -O- http://loki:3100/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connected${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
}

# Check external access to services
echo "External Service Access:"
echo ""
check_service "Prometheus" "http://localhost:9090/-/healthy" "prometheus"
check_service "AlertManager" "http://localhost:9093/-/healthy" "alertmanager"
check_service "Grafana" "http://localhost:3000/api/health" "grafana"
check_service "AIOps Processor" "http://localhost:8000/health" "aiops-processor"
check_service "Loki" "http://localhost:3100/ready" "loki"
check_service "Node Exporter" "http://localhost:9100/metrics" "node-exporter"

# Check internal connectivity
check_internal_connectivity

# Show detailed health info
echo ""
echo "================================================"
echo "Detailed Health Information"
echo "================================================"
echo ""

echo "AIOps Processor Health:"
curl -s http://localhost:8000/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to get health info"

echo ""
echo "Alert Queue Status:"
curl -s http://localhost:8000/queue/status 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Failed to get queue status"

echo ""
echo "================================================"
echo "Service Status Summary"
echo "================================================"
docker compose ps

echo ""
echo "================================================"
echo "Quick Actions:"
echo "================================================"
echo "View logs:           docker compose logs -f aiops-processor"
echo "Test alert:          ./scripts/test-and-view-llm.sh"
echo "Restart services:    ./scripts/restart-services.sh"
echo ""

