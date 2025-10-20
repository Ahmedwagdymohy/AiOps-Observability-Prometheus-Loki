# Kubernetes Deployment for AIOps System

This directory contains everything needed to deploy the AIOps system to a Kubernetes cluster.

## 🚀 Quick Start (5 Minutes)

```bash
cd kubernetes
chmod +x quick-start.sh deploy.sh
./quick-start.sh
```

The script will:
1. Build and push the Docker image
2. Deploy all components to Kubernetes
3. Set up demo applications that generate real metrics and logs
4. Configure AlertManager to send alerts to AIOps Processor

## 📁 Directory Structure

```
kubernetes/
├── namespace.yaml                 # Namespaces: monitoring, demo-apps
├── prometheus/
│   ├── configmap.yaml            # Prometheus config + alert rules
│   └── deployment.yaml           # Prometheus deployment + RBAC
├── alertmanager/
│   ├── configmap.yaml            # AlertManager config (webhook to AIOps)
│   └── deployment.yaml           # AlertManager deployment
├── loki/
│   └── deployment.yaml           # Loki log aggregation
├── promtail/
│   └── daemonset.yaml            # Promtail log collector (runs on all nodes)
├── grafana/
│   └── deployment.yaml           # Grafana with datasources
├── aiops-processor/
│   ├── configmap.yaml            # AIOps configuration
│   ├── secret.yaml               # Huawei API key (EDIT THIS!)
│   └── deployment.yaml           # AIOps deployment
├── demo-apps/
│   ├── demo-app.yaml             # Demo Flask app with metrics/logs
│   └── load-generator.yaml       # Traffic generator
├── Dockerfile                     # Dockerfile for AIOps Processor
├── deploy.sh                      # Manual deployment script
├── quick-start.sh                 # Automated quick start
└── README.md                      # This file
```

## 📋 Prerequisites

- Kubernetes cluster (local or cloud):
  - **Local**: Minikube, Kind, Docker Desktop, K3s
  - **Cloud**: GKE, EKS, AKS
- `kubectl` configured to access your cluster
- Docker installed for building images
- Container registry access (Docker Hub, GCR, ECR, etc.)

## ⚙️ Configuration

### 1. Set Your API Key

Edit `aiops-processor/secret.yaml`:
```yaml
stringData:
  HUAWEI_API_KEY: "YOUR_WORKING_API_KEY_HERE"
```

### 2. Build and Push Docker Image

```bash
# Build
cd ..
docker build -t YOUR_REGISTRY/aiops-processor:latest -f kubernetes/Dockerfile .

# Push
docker push YOUR_REGISTRY/aiops-processor:latest
```

### 3. Update Deployment

Edit `aiops-processor/deployment.yaml`:
```yaml
image: YOUR_REGISTRY/aiops-processor:latest
```

## 🎯 What Gets Deployed

### Monitoring Stack (namespace: monitoring)
- **Prometheus**: Scrapes metrics from apps
- **AlertManager**: Routes alerts to AIOps Processor
- **Loki**: Stores application logs
- **Promtail**: Collects logs from all pods (DaemonSet)
- **Grafana**: Visualization and dashboards
- **AIOps Processor**: AI-powered incident analysis

### Demo Applications (namespace: demo-apps)
- **demo-web-app**: Flask app with:
  - `/` - Home endpoint
  - `/api/data` - API with 10% error rate
  - `/stress` - High CPU/memory endpoint
  - `/metrics` - Prometheus metrics
  - `/health` - Health check
- **load-generator**: Creates realistic traffic

## 🔍 Verify Deployment

```bash
# Check pods
kubectl get pods -n monitoring
kubectl get pods -n demo-apps

# All pods should be Running

# Check services
kubectl get svc -n monitoring
kubectl get svc -n demo-apps

# Check AIOps logs
kubectl logs -f deployment/aiops-processor -n monitoring
```

## 🌐 Access Services

Forward ports to access locally:

```bash
# Grafana (dashboards)
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Open: http://localhost:3000 (admin/admin)

# Prometheus (metrics)
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090

# AlertManager (alerts)
kubectl port-forward svc/alertmanager 9093:9093 -n monitoring
# Open: http://localhost:9093

# AIOps API
kubectl port-forward svc/aiops-processor 8000:8000 -n monitoring
# Open: http://localhost:8000/health

# Demo App
kubectl port-forward svc/demo-web-app 5000:80 -n demo-apps
# Open: http://localhost:5000
```

## 🧪 Test the System

### 1. Generate Normal Traffic
```bash
# Load generator runs automatically
# Or manually:
curl http://localhost:5000/
curl http://localhost:5000/api/data
```

### 2. Trigger High CPU Alert
```bash
curl http://localhost:5000/stress
```

This will:
1. Generate high CPU usage in the demo app
2. Prometheus detects it and fires an alert
3. AlertManager sends alert to AIOps Processor
4. AIOps analyzes with AI and provides remediation

### 3. View AI Analysis

```bash
# Watch AIOps logs
kubectl logs -f deployment/aiops-processor -n monitoring

# Or check via API
curl http://localhost:8000/queue/status
```

### 4. View in Grafana

1. Open Grafana: http://localhost:3000
2. Go to Explore
3. Select Prometheus datasource
4. Query: `rate(http_requests_total[5m])`
5. Switch to Loki datasource
6. Query: `{namespace="demo-apps"}`

## 📊 Prometheus Queries

Try these in Prometheus (http://localhost:9090):

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m])

# CPU usage
rate(process_cpu_seconds_total[5m])

# Active requests
http_requests_active
```

## 📝 Loki Queries

Try these in Grafana Explore with Loki:

```logql
# All demo app logs
{namespace="demo-apps"}

# Only errors
{namespace="demo-apps"} |= "ERROR"

# Only warnings
{namespace="demo-apps"} |= "WARNING"

# Specific pod
{namespace="demo-apps", pod=~"demo-web-app-.*"}
```

## 🔧 Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod POD_NAME -n monitoring
kubectl logs POD_NAME -n monitoring
```

### No Metrics
```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Visit: http://localhost:9090/targets
```

### No Logs
```bash
# Check Promtail
kubectl logs -l app=promtail -n monitoring

# Check Loki
kubectl logs deployment/loki -n monitoring
```

### No Alerts
```bash
# Check AlertManager config
kubectl get cm alertmanager-config -n monitoring -o yaml

# Check AlertManager logs
kubectl logs deployment/alertmanager -n monitoring
```

## 🧹 Cleanup

Remove everything:
```bash
kubectl delete namespace monitoring
kubectl delete namespace demo-apps
```

## 📚 Documentation

- **[KUBERNETES_DEPLOYMENT.md](../KUBERNETES_DEPLOYMENT.md)**: Comprehensive deployment guide
- **[Main README](../README.md)**: Project overview
- **Deployment scripts**: `deploy.sh`, `quick-start.sh`

## 🎯 Next Steps

1. **Add Your Apps**: Deploy your actual applications
2. **Custom Alerts**: Add alert rules for your apps in `prometheus/configmap.yaml`
3. **Custom Dashboards**: Create Grafana dashboards
4. **Production Setup**: Add persistent storage, ingress, TLS
5. **Scale**: Increase replicas for high availability

## 💡 Tips

- Start with the demo app to understand the flow
- Check AIOps logs to see AI analysis in action
- Use Grafana to correlate metrics and logs
- Adjust alert thresholds in `prometheus/configmap.yaml`
- Modify LLM parameters in `aiops-processor/configmap.yaml`

---

**Questions?** Check the main [KUBERNETES_DEPLOYMENT.md](../KUBERNETES_DEPLOYMENT.md) for detailed documentation.

