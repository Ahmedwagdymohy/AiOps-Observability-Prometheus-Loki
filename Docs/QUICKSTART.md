# AIOps Quick Start Guide

Get your AIOps system up and running in 5 minutes!

## Prerequisites

- Docker & Docker Compose installed
- DeepSeek API key ([Get one here](https://platform.deepseek.com/))

## Setup (One-Time)

### Option 1: Using Setup Script (Recommended)

```bash
cd /Users/ahmedwagdy/Desktop/AiOps
./setup.sh
```

The script will:
- Verify Docker installation
- Prompt for your DeepSeek API key
- Optionally configure Slack notifications
- Pull and build all Docker images

### Option 2: Manual Setup

1. **Set your API key**:
   ```bash
   export DEEPSEEK_API_KEY="your_api_key_here"
   ```

2. **Update docker-compose.yml**:
   Replace `your_api_key_here` with your actual DeepSeek API key in the `aiops-processor` service environment variables.

## Start the System

```bash
docker-compose up -d
```

Wait ~30 seconds for all services to initialize.

## Verify Installation

```bash
# Check all services are running
docker-compose ps

# Test the AIOps processor
curl http://localhost:8000/health
```

Expected services:
- ✅ prometheus
- ✅ alertmanager
- ✅ grafana
- ✅ ollama
- ✅ aiops-processor
- ✅ loki
- ✅ promtail
- ✅ node-exporter

## Test the System

### Option 1: Use Test Script

```bash
./test-alert.sh
```

### Option 2: Manual Test - Trigger Real Alert

Generate CPU load to trigger an alert:

```bash
# Start CPU stress
docker exec -it node-exporter sh -c "dd if=/dev/zero of=/dev/null & dd if=/dev/zero of=/dev/null &"

# Wait 2-3 minutes for alert to fire

# Watch the magic happen
docker-compose logs -f aiops-processor

# Stop the stress test
docker exec -it node-exporter sh -c "killall dd"
```

## View Results

### AIOps Processor Logs
```bash
docker-compose logs -f aiops-processor
```

Look for:
1. `Received webhook from AlertManager`
2. `Fetching Prometheus metrics...`
3. `Fetching Loki logs...`
4. `Analyzing with LLM...`
5. `Successfully analyzed and notified`

### Web UIs

- **Prometheus Alerts**: http://localhost:9090/alerts
- **AlertManager**: http://localhost:9093
- **Grafana**: http://localhost:3000 (admin/admin)
- **AIOps API**: http://localhost:8000

## Understanding the Flow

```
1. Alert Fires (Prometheus) 
   ↓
2. Routed to AlertManager
   ↓
3. Webhook to AIOps Processor
   ↓
4. Gather Context:
   - Query Prometheus metrics (15 min window)
   - Query Loki logs (error/warning patterns)
   ↓
5. AI Analysis (DeepSeek)
   - Root cause identification
   - Evidence from metrics/logs
   - Remediation steps
   ↓
6. Send Notification (Slack/Webhook)
```

## Common Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Restart a service
docker-compose restart aiops-processor

# Check queue status
curl http://localhost:8000/queue/status

# Health check
curl http://localhost:8000/health

# Rebuild after code changes
docker-compose build aiops-processor
docker-compose restart aiops-processor
```

## Configuration

### Update API Key

Edit `docker-compose.yml`:
```yaml
environment:
  - DEEPSEEK_API_KEY=your_new_key_here
```

Then restart:
```bash
docker-compose restart aiops-processor
```

### Add Slack Notifications

1. Create Slack webhook: https://api.slack.com/messaging/webhooks
2. Edit `docker-compose.yml`:
   ```yaml
   environment:
     - SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```
3. Restart:
   ```bash
   docker-compose restart aiops-processor
   ```

### Adjust Analysis Time Window

Edit `docker-compose.yml`:
```yaml
environment:
  - TIME_WINDOW_MINUTES=30  # Default is 15
```

## Troubleshooting

### Services won't start
```bash
# Check logs
docker-compose logs

# Check specific service
docker-compose logs aiops-processor
```

### No alerts being analyzed

1. **Check AlertManager can reach AIOps**:
   ```bash
   docker exec -it alertmanager wget -O- http://aiops-processor:8000/health
   ```

2. **Verify alerts are firing**:
   Visit http://localhost:9090/alerts

3. **Check AlertManager config**:
   ```bash
   docker exec -it alertmanager cat /etc/alertmanager/alertmanager.yml
   ```

### API key issues

```bash
# Verify the key is set
docker exec -it aiops-processor env | grep DEEPSEEK

# Check logs for API errors
docker-compose logs aiops-processor | grep -i error
```

## Next Steps

1. ✅ System is working
2. 📖 Read full [README.md](README.md) for advanced features
3. 🔧 Customize alert rules in `prometheus/alert_rules.yml`
4. 📊 Build Grafana dashboards
5. 🚀 Integrate with your infrastructure

## Need Help?

- Check [README.md](README.md) for detailed documentation
- Review logs: `docker-compose logs -f`
- Verify configuration files in each service directory

---

**Pro Tip**: Keep the logs open in a separate terminal while testing:
```bash
docker-compose logs -f aiops-processor
```

This lets you see the entire analysis process in real-time!


