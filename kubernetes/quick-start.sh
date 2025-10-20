#!/bin/bash
# Quick start script - Get everything running in minutes

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "=========================================="
echo "  AIOps Kubernetes Quick Start"
echo "=========================================="
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found! Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}docker not found! Please install Docker first.${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster!${NC}"
    echo "Please configure kubectl to connect to your cluster."
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Get configuration
echo -e "${YELLOW}Configuration:${NC}"
echo ""
read -p "Enter your Docker registry (e.g., dockerhub-username or gcr.io/project): " REGISTRY

if [ -z "$REGISTRY" ]; then
    echo -e "${RED}Registry is required!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Building and pushing Docker image...${NC}"
cd ..
docker build -t ${REGISTRY}/aiops-processor:latest -f kubernetes/Dockerfile .
docker push ${REGISTRY}/aiops-processor:latest
echo -e "${GREEN}✓ Image pushed${NC}"
echo ""

cd kubernetes

# Update deployment with correct image
sed -i.bak "s|your-registry/aiops-processor:latest|${REGISTRY}/aiops-processor:latest|g" aiops-processor/deployment.yaml
echo -e "${GREEN}✓ Updated deployment with your image${NC}"
echo ""

# Deploy everything
echo -e "${YELLOW}Deploying to Kubernetes...${NC}"
./deploy.sh

echo ""
echo -e "${GREEN}"
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "Run these commands in separate terminals:"
echo ""
echo -e "${YELLOW}# Grafana (dashboards and logs)${NC}"
echo "kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "Access: http://localhost:3000 (admin/admin)"
echo ""
echo -e "${YELLOW}# Prometheus (metrics)${NC}"
echo "kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
echo "Access: http://localhost:9090"
echo ""
echo -e "${YELLOW}# AIOps Processor (AI analysis)${NC}"
echo "kubectl port-forward svc/aiops-processor 8000:8000 -n monitoring"
echo "Access: http://localhost:8000/health"
echo ""
echo -e "${YELLOW}# Demo App (generate traffic)${NC}"
echo "kubectl port-forward svc/demo-web-app 5000:80 -n demo-apps"
echo "Access: http://localhost:5000"
echo ""
echo -e "${GREEN}Watch the logs:${NC}"
echo "kubectl logs -f deployment/aiops-processor -n monitoring"
echo ""
echo -e "${GREEN}Trigger an alert manually:${NC}"
echo "curl http://localhost:5000/stress"
echo ""

