#!/bin/bash

# ============================================================================
# Huawei Cloud API Setup Script
# ============================================================================
# This script helps you configure the Huawei Cloud DeepSeek API for the
# AIOps Alert Processor competition project.
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Huawei Cloud DeepSeek API Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found!${NC}"
    echo "Please run this script from the AiOps project root directory."
    exit 1
fi

# Step 1: API Key Selection
echo -e "${GREEN}Step 1: API Key Configuration${NC}"
echo "You have been provided with two API keys for the competition."
echo ""
echo "API Key 1: aaa94bd0-57d4-4581-8418-c999f0f6fec7_D88DC983C7E963504635650DE1B0025F82B1749F15284E6F78BFAFD40CC0B8F8"
echo "API Key 2: c1d8d97e-6333-4416-b02e-cac54271e94e_EA9F627E708C3D904BB6955D8969197A2B7B339E9ED3AD77AE12CC869F997706"
echo ""
read -p "Enter your choice (1 or 2): " api_choice

if [ "$api_choice" == "1" ]; then
    HUAWEI_API_KEY="aaa94bd0-57d4-4581-8418-c999f0f6fec7_D88DC983C7E963504635650DE1B0025F82B1749F15284E6F78BFAFD40CC0B8F8"
elif [ "$api_choice" == "2" ]; then
    HUAWEI_API_KEY="c1d8d97e-6333-4416-b02e-cac54271e94e_EA9F627E708C3D904BB6955D8969197A2B7B339E9ED3AD77AE12CC869F997706"
else
    echo -e "${RED}Invalid choice. Please run the script again.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ API Key configured${NC}"
echo ""

# Step 2: Model Selection
echo -e "${GREEN}Step 2: Model Selection${NC}"
echo "Choose which model to use:"
echo ""
echo "1) deepseek-r1-distil-qwen-32b_raziqt (32B - More powerful, slower)"
echo "   - Better for complex analysis and detailed reasoning"
echo "   - Response time: 30-60+ seconds"
echo "   - Recommended for: Production incidents"
echo ""
echo "2) distill-llama-8b_46e6iu (8B - Faster, lighter)"
echo "   - Good for simpler tasks and quick analysis"
echo "   - Response time: 10-30 seconds"
echo "   - Recommended for: Testing and high-volume scenarios"
echo ""
read -p "Enter your choice (1 or 2, default: 1): " model_choice

if [ "$model_choice" == "2" ]; then
    HUAWEI_MODEL_NAME="distill-llama-8b_46e6iu"
    echo -e "${GREEN}✓ Selected: Distil-Llama-8B (Faster)${NC}"
else
    HUAWEI_MODEL_NAME="deepseek-r1-distil-qwen-32b_raziqt"
    echo -e "${GREEN}✓ Selected: DeepSeek-R1-Distil-Qwen-32B (More Powerful)${NC}"
fi
echo ""

# Step 3: Configuration Method
echo -e "${GREEN}Step 3: Configuration Method${NC}"
echo "How would you like to configure the API?"
echo ""
echo "1) Create docker-compose.override.yml (Recommended)"
echo "   - Keeps secrets separate from main config"
echo "   - Automatically git-ignored"
echo "   - Easy to manage"
echo ""
echo "2) Create .env file in aiops-processor directory"
echo "   - Traditional approach"
echo "   - Good for local development"
echo ""
read -p "Enter your choice (1 or 2, default: 1): " config_choice

if [ "$config_choice" == "2" ]; then
    # Create .env file
    ENV_FILE="aiops-processor/.env"
    echo -e "${YELLOW}Creating $ENV_FILE...${NC}"
    
    cat > "$ENV_FILE" << EOF
# Huawei Cloud DeepSeek API Configuration
HUAWEI_API_URL=https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions
HUAWEI_API_KEY=$HUAWEI_API_KEY
HUAWEI_MODEL_NAME=$HUAWEI_MODEL_NAME

# Other configurations (optional)
PROMETHEUS_URL=http://prometheus:9090
LOKI_URL=http://loki:3100
TIME_WINDOW_MINUTES=15
LLM_TIMEOUT=180
LLM_TEMPERATURE=0.3
LLM_MAX_TOKENS=2000
EOF
    
    echo -e "${GREEN}✓ Created $ENV_FILE${NC}"
else
    # Create docker-compose.override.yml
    OVERRIDE_FILE="docker-compose.override.yml"
    echo -e "${YELLOW}Creating $OVERRIDE_FILE...${NC}"
    
    cat > "$OVERRIDE_FILE" << EOF
version: '3.8'

services:
  aiops-processor:
    environment:
      - HUAWEI_API_KEY=$HUAWEI_API_KEY
      - HUAWEI_MODEL_NAME=$HUAWEI_MODEL_NAME
      # Optional: Uncomment to override other settings
      # - LLM_TIMEOUT=180
      # - LLM_TEMPERATURE=0.3
      # - TIME_WINDOW_MINUTES=15
EOF
    
    echo -e "${GREEN}✓ Created $OVERRIDE_FILE${NC}"
fi
echo ""

# Step 4: Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Configuration Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "API Endpoint: https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions"
echo "API Key: ${HUAWEI_API_KEY:0:20}...${HUAWEI_API_KEY: -20}"
echo "Model: $HUAWEI_MODEL_NAME"
echo ""

# Step 5: Start services
echo -e "${GREEN}Configuration complete!${NC}"
echo ""
read -p "Would you like to start the services now? (y/n, default: y): " start_choice

if [ "$start_choice" != "n" ] && [ "$start_choice" != "N" ]; then
    echo -e "${YELLOW}Starting services...${NC}"
    docker-compose down 2>/dev/null || true
    docker-compose up -d
    
    echo ""
    echo -e "${GREEN}✓ Services started${NC}"
    echo ""
    echo "Waiting for services to be healthy..."
    sleep 10
    
    # Check health
    echo ""
    echo -e "${YELLOW}Checking health endpoint...${NC}"
    if curl -f -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ AIOps Processor is healthy${NC}"
        echo ""
        echo "Health check response:"
        curl -s http://localhost:8000/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8000/health
    else
        echo -e "${YELLOW}⚠ Service is still starting up...${NC}"
        echo "Run 'docker-compose logs -f aiops-processor' to check logs"
    fi
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Next Steps${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "1. Check logs:"
echo "   docker-compose logs -f aiops-processor"
echo ""
echo "2. Test the API:"
echo "   curl http://localhost:8000/health"
echo ""
echo "3. Send a test alert:"
echo "   ./scripts/test-alert.sh"
echo ""
echo "4. Access Grafana:"
echo "   http://localhost:3000 (admin/admin)"
echo ""
echo "5. Access Prometheus:"
echo "   http://localhost:9090"
echo ""
echo "For more information, see:"
echo "  - HUAWEI_INTEGRATION_GUIDE.md"
echo "  - aiops-processor/env.example"
echo ""
echo -e "${GREEN}Setup complete! 🎉${NC}"
echo ""

