#!/bin/bash

# AIOps Setup Script
# This script helps set up the AIOps system with proper configuration

set -e

echo "🚀 AIOps Alert Analysis System - Setup Script"
echo "=============================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Prompt for DeepSeek API key if not set
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "📋 DeepSeek API Key Configuration"
    echo "You need a DeepSeek API key to use the AI analysis features."
    echo "Get one at: https://platform.deepseek.com/"
    echo ""
    read -p "Enter your DeepSeek API key (or press Enter to skip): " api_key
    
    if [ -n "$api_key" ]; then
        export DEEPSEEK_API_KEY="$api_key"
        echo "✅ API key set for this session"
        echo ""
        echo "💡 To make this permanent, add to your ~/.bashrc or ~/.zshrc:"
        echo "   export DEEPSEEK_API_KEY=\"$api_key\""
        echo ""
    else
        echo "⚠️  Warning: No API key provided. You'll need to set it later."
        echo ""
    fi
fi

# Optional: Slack webhook configuration
echo "📢 Notification Configuration (Optional)"
read -p "Enter Slack webhook URL (or press Enter to skip): " slack_url

if [ -n "$slack_url" ]; then
    export SLACK_WEBHOOK_URL="$slack_url"
    echo "✅ Slack webhook configured"
    echo ""
fi

# Create .env file if it doesn't exist
if [ ! -f "aiops-processor/.env" ]; then
    echo "📝 Creating .env file from template..."
    cp aiops-processor/env.template aiops-processor/.env
    
    if [ -n "$DEEPSEEK_API_KEY" ]; then
        # Update the .env file with the actual API key
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|DEEPSEEK_API_KEY=.*|DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY|" aiops-processor/.env
        else
            # Linux
            sed -i "s|DEEPSEEK_API_KEY=.*|DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY|" aiops-processor/.env
        fi
    fi
    
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL|" aiops-processor/.env
        else
            sed -i "s|SLACK_WEBHOOK_URL=.*|SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL|" aiops-processor/.env
        fi
    fi
    
    echo "✅ .env file created"
    echo ""
fi

# Pull Docker images
echo "📦 Pulling Docker images..."
docker-compose pull

# Build custom images
echo "🔨 Building AIOps processor..."
docker-compose build

echo ""
echo "✅ Setup complete!"
echo ""
echo "🎯 Next Steps:"
echo "1. Start the services:"
echo "   docker-compose up -d"
echo ""
echo "2. Verify all services are running:"
echo "   docker-compose ps"
echo ""
echo "3. Access the services:"
echo "   - Prometheus:       http://localhost:9090"
echo "   - Grafana:          http://localhost:3000 (admin/admin)"
echo "   - AlertManager:     http://localhost:9093"
echo "   - AIOps Processor:  http://localhost:8000"
echo ""
echo "4. Monitor the logs:"
echo "   docker-compose logs -f aiops-processor"
echo ""
echo "5. Test the system by triggering an alert (see README.md)"
echo ""
echo "📖 For more information, see README.md"
echo ""


