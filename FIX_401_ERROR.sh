#!/bin/bash

echo "=========================================="
echo "Huawei Cloud API 401 Error Troubleshooting"
echo "=========================================="
echo ""

# The issue might be:
# 1. URL typo - should be "ap-southeast-1" not "ap-southeast1"
# 2. Wrong API key format
# 3. Need to try the second API key

echo "Testing both API keys with both URL formats..."
echo ""

API_KEY1="aaa94bd0-57d4-4581-8418-c999f0f6fec7_D88DC983C7E963504635650DE1B0025F82B1749F15284E6F78BFAFD40CC0B8F8"
API_KEY2="c1d8d97e-6333-4416-b02e-cac54271e94e_EA9F627E708C3D904BB6955D8969197A2B7B339E9ED3AD77AE12CC869F997706"

# Test different URL formats from the PDF
URL1="https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions"
URL2="https://pangu.ap-southeast1.myhuaweicloud.com/api/v2/chat/completions"

test_api() {
    local key=$1
    local url=$2
    local key_name=$3
    local url_name=$4
    
    echo "Testing $key_name with $url_name..."
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$url" \
      -H "Content-Type: application/json" \
      -H "X-Auth-Token: $key" \
      -d '{
        "model": "deepseek-r1-distil-qwen-32b_raziqt",
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 10
      }')
    
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    
    if [ "$http_code" = "200" ]; then
        echo "✅ SUCCESS! This combination works!"
        echo "Use this in your docker-compose.override.yml:"
        echo ""
        echo "version: '3.8'"
        echo "services:"
        echo "  aiops-processor:"
        echo "    environment:"
        echo "      - HUAWEI_API_KEY=$key"
        echo "      - HUAWEI_API_URL=$url"
        echo ""
        return 0
    else
        echo "❌ Failed with HTTP code: $http_code"
        echo "Response: $(echo "$response" | grep -v "HTTP_CODE:")"
    fi
    echo ""
    return 1
}

# Test all combinations
echo "=========================================="
echo "Test 1: API Key 1 + URL format 1"
echo "=========================================="
test_api "$API_KEY1" "$URL1" "API_KEY_1" "URL_WITH_DASH" && exit 0

echo "=========================================="
echo "Test 2: API Key 1 + URL format 2"
echo "=========================================="
test_api "$API_KEY1" "$URL2" "API_KEY_1" "URL_WITHOUT_DASH" && exit 0

echo "=========================================="
echo "Test 3: API Key 2 + URL format 1"
echo "=========================================="
test_api "$API_KEY2" "$URL1" "API_KEY_2" "URL_WITH_DASH" && exit 0

echo "=========================================="
echo "Test 4: API Key 2 + URL format 2"
echo "=========================================="
test_api "$API_KEY2" "$URL2" "API_KEY_2" "URL_WITHOUT_DASH" && exit 0

echo ""
echo "=========================================="
echo "All tests failed!"
echo "=========================================="
echo ""
echo "Possible issues:"
echo "1. API keys might not be activated yet"
echo "2. Need to request activation via email: developers.na@huawei.com"
echo "3. Keys might be region-restricted"
echo "4. Service might not be available yet"
echo ""
echo "Please contact the competition organizers."

