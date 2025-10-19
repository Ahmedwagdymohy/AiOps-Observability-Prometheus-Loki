# AIOps Alert Analysis & Resolution System

An intelligent, AI-powered observability system that automatically analyzes Prometheus alerts, correlates them with metrics and logs, and provides root cause analysis with actionable remediation steps using LLM technology.

## 🎯 Features

- **Automated Alert Analysis**: Receives alerts from AlertManager via webhook
- **Intelligent Context Gathering**: Automatically queries relevant Prometheus metrics and Loki logs
- **AI-Powered Root Cause Analysis**: Uses DeepSeek LLM to analyze alert context and provide insights
- **Actionable Recommendations**: Generates prioritized remediation steps
- **Flexible Notifications**: Supports Slack webhooks and generic webhook integrations
- **Comprehensive Observability Stack**: Includes Prometheus, Loki, Grafana, and AlertManager

## 🏗️ Architecture

```
┌─────────────┐
│  Prometheus │──┐
└─────────────┘  │
                 │
┌─────────────┐  │    ┌──────────────┐
│    Loki     │──┼───▶│ AIOps        │
└─────────────┘  │    │ Processor    │
                 │    └──────┬───────┘
┌─────────────┐  │           │
│ AlertManager│──┘           │
└─────────────┘              │
                             ▼
                    ┌────────────────┐
                    │  DeepSeek API  │
                    └────────┬───────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  Notifications │
                    │ (Slack/Webhook)│
                    └────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- DeepSeek API key (get one from [DeepSeek](https://platform.deepseek.com/))

### Setup

1. **Clone the repository** (if not already done):
   ```bash
   cd /Users/ahmedwagdy/Desktop/AiOps
   ```

2. **Set your DeepSeek API key**:
   ```bash
   # Edit docker-compose.yml and replace the DEEPSEEK_API_KEY value
   # Or export it as an environment variable:
   export DEEPSEEK_API_KEY="your_api_key_here"
   ```

3. **Start the services**:
   ```bash
   docker-compose up -d
   ```

4. **Verify all services are running**:
   ```bash
   docker-compose ps
   ```

### Access the Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **AlertManager**: http://localhost:9093
- **AIOps Processor**: http://localhost:8000
- **Loki**: http://localhost:3100

## 📊 Service Details

### Prometheus
- Collects metrics from node-exporter and other services
- Evaluates alert rules every 30 seconds
- Sends alerts to AlertManager

### AlertManager
- Receives alerts from Prometheus
- Routes alerts to AIOps Processor webhook
- Handles alert grouping and deduplication

### Loki + Promtail
- Collects logs from all Docker containers
- Provides log aggregation and querying
- Automatically adds service labels

### AIOps Processor
- **Webhook Endpoint**: `/webhook/alerts` - Receives alerts from AlertManager
- **Manual Analysis**: `/analyze` - Manually trigger analysis for a single alert
- **Health Check**: `/health` - Service health status
- **Queue Status**: `/queue/status` - View alert processing queue

### Grafana
- Pre-configured with Prometheus and Loki datasources
- Build custom dashboards for visualization

## 🔧 Configuration

### AIOps Processor Configuration

The AIOps processor is configured via environment variables in `docker-compose.yml`:

```yaml
environment:
  # Data Sources
  - PROMETHEUS_URL=http://prometheus:9090
  - LOKI_URL=http://loki:3100
  
  # DeepSeek LLM
  - DEEPSEEK_API_KEY=your_api_key_here
  - DEEPSEEK_MODEL=deepseek-chat
  
  # Analysis Settings
  - TIME_WINDOW_MINUTES=15  # Time window for metrics/logs
  - MAX_LOG_LINES=500       # Maximum log lines to fetch
  
  # Notifications (optional)
  - SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

### Alert Rules

Alert rules are defined in `prometheus/alert_rules.yml`. The system includes pre-configured alerts for:

- **CPU Usage**: Warning at 80%, Critical at 95%
- **Memory Usage**: Warning at 80%, Critical at 95%
- **Disk Usage**: Warning at 80%
- **Instance Down**: Critical when service is unreachable

To add custom alerts:

```yaml
- alert: CustomAlert
  expr: your_prometheus_query > threshold
  for: 2m
  labels:
    severity: warning
    component: your_component
  annotations:
    summary: "Alert summary"
    description: "Detailed description"
```

### Notification Configuration

#### Slack Integration

1. Create a Slack incoming webhook at https://api.slack.com/messaging/webhooks
2. Add the webhook URL to docker-compose.yml:
   ```yaml
   - SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```
3. Restart the aiops-processor:
   ```bash
   docker-compose restart aiops-processor
   ```

#### Generic Webhook

For other notification systems:
```yaml
- GENERIC_WEBHOOK_URL=https://your-webhook-endpoint.com/notify
```

## 🧪 Testing the System

### 1. Trigger a Test Alert

Generate CPU load to trigger an alert:

```bash
# SSH into the node-exporter container
docker exec -it node-exporter sh

# Generate CPU load (in the container)
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &
```

### 2. Monitor the Processing

Watch the AIOps processor logs:
```bash
docker-compose logs -f aiops-processor
```

### 3. Check Alert Status

View alerts in:
- **AlertManager UI**: http://localhost:9093
- **Prometheus Alerts**: http://localhost:9090/alerts

### 4. Stop the Load Test

```bash
docker exec -it node-exporter sh -c "killall dd"
```

## 📋 API Examples

### Webhook Endpoint (AlertManager)

AlertManager automatically sends webhooks in this format:

```json
POST /webhook/alerts
{
  "receiver": "aiops-webhook",
  "status": "firing",
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "HighCPUUsage",
      "severity": "warning",
      "instance": "node-exporter:9100"
    },
    "annotations": {
      "summary": "High CPU usage detected",
      "description": "CPU usage is above 80%"
    },
    "startsAt": "2025-10-16T10:30:00Z"
  }]
}
```

### Manual Analysis API

Trigger analysis manually:

```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "labels": {
      "alertname": "HighCPUUsage",
      "severity": "warning",
      "instance": "node-exporter:9100",
      "component": "cpu"
    },
    "annotations": {
      "summary": "High CPU usage",
      "description": "CPU usage above threshold"
    },
    "startsAt": "2025-10-16T10:30:00Z",
    "endsAt": "",
    "generatorURL": "http://prometheus:9090/graph",
    "fingerprint": "abc123"
  }'
```

## 🔍 How It Works

1. **Alert Fires**: Prometheus detects a threshold breach and sends alert to AlertManager
2. **Webhook Trigger**: AlertManager forwards the alert to AIOps Processor webhook
3. **Context Gathering**:
   - Queries Prometheus for relevant metrics (15 min window before/after alert)
   - Queries Loki for relevant logs (error, warning patterns)
4. **AI Analysis**: Sends alert context, metrics, and logs to DeepSeek LLM
5. **Analysis Response**: LLM provides:
   - Root cause analysis
   - Supporting evidence from metrics/logs
   - Prioritized remediation steps
   - Severity assessment
6. **Notification**: Sends formatted analysis to configured notification channels

## 📁 Project Structure

```
AiOps/
├── aiops-processor/          # AI-powered alert processor
│   ├── app.py                # FastAPI application
│   ├── config.py             # Configuration management
│   ├── clients/              # External service clients
│   │   ├── prometheus.py     # Prometheus query client
│   │   ├── loki.py          # Loki log query client
│   │   └── deepseek.py      # DeepSeek LLM client
│   ├── services/             # Business logic
│   │   ├── analyzer.py      # Alert analysis orchestration
│   │   └── notifier.py      # Notification service
│   ├── models/               # Data models
│   │   └── schemas.py       # Pydantic schemas
│   ├── requirements.txt      # Python dependencies
│   └── Dockerfile           # Container configuration
├── prometheus/               # Prometheus configuration
│   ├── prometheus.yml       # Main config
│   └── alert_rules.yml      # Alert definitions
├── alertmanager/            # AlertManager configuration
│   └── alertmanager.yml    # Routing and receivers
├── loki/                    # Loki configuration
│   ├── loki-config.yml     # Loki server config
│   └── promtail-config.yml # Log collection config
├── grafana/                 # Grafana configuration
│   └── datasources.yml     # Datasource definitions
└── docker-compose.yml       # Service orchestration
```

## 🛠️ Customization

### Adding Custom Metrics Queries

Edit `aiops-processor/clients/prometheus.py` in the `_build_queries_from_labels()` method to add custom PromQL queries based on your alert labels.

### Adding Custom Log Queries

Edit `aiops-processor/clients/loki.py` in the `_build_queries_from_labels()` method to add custom LogQL queries.

### Customizing LLM Prompts

Edit `aiops-processor/clients/deepseek.py` in the `_build_analysis_prompt()` method to customize how alerts are presented to the LLM.

### Adjusting Analysis Time Window

Change the `TIME_WINDOW_MINUTES` environment variable to adjust how much historical data is analyzed (default: 15 minutes).

## 🐛 Troubleshooting

### AIOps Processor Won't Start

Check logs:
```bash
docker-compose logs aiops-processor
```

Common issues:
- Missing DeepSeek API key
- Unable to connect to Prometheus/Loki (wait for services to be ready)

### No Alerts Being Processed

1. Verify AlertManager can reach the processor:
   ```bash
   docker exec -it alertmanager wget -O- http://aiops-processor:8000/health
   ```

2. Check AlertManager configuration:
   ```bash
   docker exec -it alertmanager cat /etc/alertmanager/alertmanager.yml
   ```

3. Verify alerts are firing in Prometheus:
   http://localhost:9090/alerts

### LLM Analysis Fails

- Verify API key is correct
- Check network connectivity to DeepSeek API
- Review logs for rate limiting or quota issues

## 📈 Monitoring the AIOps System

View processor metrics:
```bash
curl http://localhost:8000/health
curl http://localhost:8000/queue/status
```

Monitor logs in real-time:
```bash
docker-compose logs -f aiops-processor
```

## 🔐 Security Considerations

- **API Keys**: Store DeepSeek API key securely (use Docker secrets in production)
- **Network**: The system runs on a private Docker network
- **Authentication**: Add authentication to the webhook endpoint in production
- **Secrets**: Never commit `.env` files or API keys to version control

## 🤝 Contributing

This is a flexible framework designed to work with any Prometheus setup. Customize it for your specific needs:

- Add new alert rules
- Customize LLM prompts
- Add additional data sources
- Integrate with your notification systems

## 📝 License

This project is provided as-is for use in AIOps implementations.

## 🔗 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [DeepSeek API Documentation](https://platform.deepseek.com/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

**Note**: Remember to remove API keys from the `secrets` file and use environment variables or Docker secrets for production deployments.
