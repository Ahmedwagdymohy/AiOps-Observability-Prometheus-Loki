#!/bin/bash
# Deployment script for Kubernetes

set -e

echo "=========================================="
echo "  AIOps Kubernetes Deployment"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Create namespaces
echo -e "${YELLOW}Step 1: Creating namespaces...${NC}"
kubectl apply -f namespace.yaml
echo -e "${GREEN}✓ Namespaces created${NC}"
echo ""

# Step 2: Deploy Prometheus
echo -e "${YELLOW}Step 2: Deploying Prometheus...${NC}"
kubectl apply -f prometheus/configmap.yaml
kubectl apply -f prometheus/deployment.yaml
echo -e "${GREEN}✓ Prometheus deployed${NC}"
echo ""

# Step 3: Deploy AlertManager
echo -e "${YELLOW}Step 3: Deploying AlertManager...${NC}"
kubectl apply -f alertmanager/configmap.yaml
kubectl apply -f alertmanager/deployment.yaml
echo -e "${GREEN}✓ AlertManager deployed${NC}"
echo ""

# Step 4: Deploy Loki
echo -e "${YELLOW}Step 4: Deploying Loki...${NC}"
kubectl apply -f loki/deployment.yaml
echo -e "${GREEN}✓ Loki deployed${NC}"
echo ""

# Step 5: Deploy Promtail
echo -e "${YELLOW}Step 5: Deploying Promtail (log collector)...${NC}"
kubectl apply -f promtail/daemonset.yaml
echo -e "${GREEN}✓ Promtail deployed${NC}"
echo ""

# Step 6: Deploy Grafana
echo -e "${YELLOW}Step 6: Deploying Grafana...${NC}"
kubectl apply -f grafana/deployment.yaml
echo -e "${GREEN}✓ Grafana deployed${NC}"
echo ""

# Step 7: Deploy AIOps Processor
echo -e "${YELLOW}Step 7: Deploying AIOps Processor...${NC}"
echo "NOTE: Make sure you've built and pushed the Docker image!"
echo "      docker build -t YOUR_REGISTRY/aiops-processor:latest -f Dockerfile .."
echo "      docker push YOUR_REGISTRY/aiops-processor:latest"
echo ""
read -p "Have you built and pushed the image? (y/n): " image_ready

if [ "$image_ready" = "y" ]; then
    kubectl apply -f aiops-processor/secret.yaml
    kubectl apply -f aiops-processor/configmap.yaml
    kubectl apply -f aiops-processor/deployment.yaml
    echo -e "${GREEN}✓ AIOps Processor deployed${NC}"
else
    echo "Skipping AIOps Processor deployment"
fi
echo ""

# Step 8: Deploy Demo Applications
echo -e "${YELLOW}Step 8: Deploying demo applications...${NC}"
kubectl apply -f demo-apps/demo-app.yaml
kubectl apply -f demo-apps/load-generator.yaml
echo -e "${GREEN}✓ Demo apps deployed${NC}"
echo ""

# Wait for pods to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=demo-web-app -n demo-apps --timeout=300s

echo ""
echo -e "${GREEN}=========================================="
echo "  Deployment Complete!"
echo "==========================================${NC}"
echo ""
echo "Access the services:"
echo ""
echo "1. Grafana:"
echo "   kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "   URL: http://localhost:3000 (admin/admin)"
echo ""
echo "2. Prometheus:"
echo "   kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
echo "   URL: http://localhost:9090"
echo ""
echo "3. AlertManager:"
echo "   kubectl port-forward svc/alertmanager 9093:9093 -n monitoring"
echo "   URL: http://localhost:9093"
echo ""
echo "4. AIOps Processor:"
echo "   kubectl port-forward svc/aiops-processor 8000:8000 -n monitoring"
echo "   URL: http://localhost:8000/health"
echo ""
echo "5. Demo App:"
echo "   kubectl port-forward svc/demo-web-app 5000:80 -n demo-apps"
echo "   URL: http://localhost:5000"
echo ""
echo "Check status:"
echo "   kubectl get pods -n monitoring"
echo "   kubectl get pods -n demo-apps"
echo ""
echo "View logs:"
echo "   kubectl logs -f deployment/aiops-processor -n monitoring"
echo "   kubectl logs -f deployment/demo-web-app -n demo-apps"
echo ""

