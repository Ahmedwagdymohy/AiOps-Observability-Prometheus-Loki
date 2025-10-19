#!/bin/bash

# Test Huawei API Key directly
API_KEY="aaa94bd0-57d4-4581-8418-c999f0f6fec7_D88DC983C7E963504635650DE1B0025F82B1749F15284E6F78BFAFD40CC0B8F8"
API_URL="https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions"

echo "Testing Huawei Cloud API..."
echo "API Key: ${API_KEY:0:20}...${API_KEY: -20}"
echo "Endpoint: $API_URL"
echo ""

# Test with curl
curl -v -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "X-Auth-Token: $API_KEY" \
  -d '{
    "model": "deepseek-r1-distil-qwen-32b_raziqt",
    "messages": [
      {"role": "user", "content": "Say hello"}
    ],
    "max_tokens": 50
  }'

echo ""
echo ""
echo "If you see 401, try the second API key..."

