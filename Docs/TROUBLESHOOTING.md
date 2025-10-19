# Troubleshooting Guide

Common issues and their solutions for the AIOps Alert Analysis System.

## Quick Diagnostics

Run these commands first to check system health:

```bash
# Check all services
docker-compose ps

# Check AIOps processor health
curl http://localhost:8000/health

# View recent logs
docker-compose logs --tail=50 aiops-processor

# Check queue status
curl http://localhost:8000/queue/status
```

## Common Issues

### 1. Services Won't Start

**Symptom**: `docker-compose up` fails or services exit immediately

**Diagnosis**:
```bash
docker-compose logs [service-name]
```

**Common Causes**:

#### Port Already in Use
```
Error: bind: address already in use
```

**Solution**:
```bash
# Find what's using the port
lsof -i :8000  # or :9090, :3000, etc.

# Kill the process or change port in docker-compose.yml
```

#### Missing Configuration Files
```
Error: open /etc/prometheus/prometheus.yml: no such file or directory
```

**Solution**:
Ensure all config files exist:
```bash
ls -la prometheus/prometheus.yml
ls -la alertmanager/alertmanager.yml
ls -la loki/loki-config.yml
```

#### Insufficient Resources
```
Error: insufficient memory
```

**Solution**:
```bash
# Increase Docker resources in Docker Desktop settings
# Minimum: 4GB RAM, 2 CPUs

# Or reduce services by commenting out unused ones
```

### 2. AIOps Processor Won't Start

**Symptom**: aiops-processor container exits or restarts continuously

**Diagnosis**:
```bash
docker-compose logs aiops-processor
```

**Common Causes**:

#### Missing Python Dependencies
```
ModuleNotFoundError: No module named 'fastapi'
```

**Solution**:
```bash
# Rebuild the container
docker-compose build --no-cache aiops-processor
docker-compose up -d aiops-processor
```

#### Invalid API Key
```
Error: Invalid DeepSeek API key
```

**Solution**:
```bash
# Check environment variable
docker-compose exec aiops-processor env | grep DEEPSEEK

# Update in docker-compose.yml and restart
docker-compose restart aiops-processor
```

#### Cannot Connect to Prometheus/Loki
```
Error querying Prometheus: Connection refused
```

**Solution**:
```bash
# Verify services are running
docker-compose ps prometheus loki

# Check they're on the same network
docker network inspect aiops_aiops-network

# Wait for services to be ready (they may take 30-60s to start)
sleep 30
docker-compose restart aiops-processor
```

### 3. No Alerts Being Received

**Symptom**: AIOps processor shows no activity despite alerts firing

**Diagnosis Steps**:

#### Step 1: Verify Alerts are Firing
```bash
# Check Prometheus alerts page
open http://localhost:9090/alerts

# Or via API
curl http://localhost:9090/api/v1/alerts | jq
```

**Expected**: You should see firing alerts listed

#### Step 2: Check AlertManager
```bash
# Check AlertManager UI
open http://localhost:9093

# Check AlertManager logs
docker-compose logs alertmanager | grep -i webhook
```

**Expected**: You should see webhook attempts to aiops-processor

#### Step 3: Verify Webhook Configuration
```bash
# Check AlertManager config
docker exec -it alertmanager cat /etc/alertmanager/alertmanager.yml
```

**Expected**: Should contain:
```yaml
webhook_configs:
  - url: 'http://aiops-processor:8000/webhook/alerts'
```

#### Step 4: Test Connectivity
```bash
# From AlertManager to AIOps
docker exec -it alertmanager wget -O- http://aiops-processor:8000/health
```

**Expected**: Should return health check JSON

**Solution if Not Working**:
```bash
# Restart AlertManager
docker-compose restart alertmanager

# Check they're on the same network
docker network inspect aiops_aiops-network | grep -E 'alertmanager|aiops-processor'
```

### 4. LLM Analysis Fails

**Symptom**: Alerts received but analysis fails

**Diagnosis**:
```bash
docker-compose logs aiops-processor | grep -i "error\|failed"
```

**Common Causes**:

#### API Key Issues
```
Error analyzing alert with LLM: 401 Unauthorized
```

**Solution**:
```bash
# Verify API key is correct
echo $DEEPSEEK_API_KEY

# Update docker-compose.yml
# Restart service
docker-compose restart aiops-processor
```

#### Network/Firewall Issues
```
Error: Failed to connect to api.deepseek.com
```

**Solution**:
```bash
# Test connectivity from container
docker exec -it aiops-processor curl -I https://api.deepseek.com

# Check firewall/proxy settings
# If behind proxy, add HTTP_PROXY environment variable
```

#### Rate Limiting
```
Error: 429 Too Many Requests
```

**Solution**:
```bash
# Check your API usage at DeepSeek dashboard
# Reduce alert volume or increase rate limit in code
# Add longer retry delays
```

#### Timeout Issues
```
Error: Request timeout after 120s
```

**Solution**:
```yaml
# In docker-compose.yml, increase timeout
environment:
  - LLM_TIMEOUT=300  # Increase to 5 minutes
```

### 5. No Metrics/Logs Being Collected

**Symptom**: Analysis shows "No metrics data available" or "No log data available"

**Diagnosis**:

#### Check Prometheus Data
```bash
# Query Prometheus directly
curl 'http://localhost:9090/api/v1/query?query=up'
```

**Solution if Empty**:
```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Restart Prometheus
docker-compose restart prometheus

# Check scrape configs
docker exec -it prometheus cat /etc/prometheus/prometheus.yml
```

#### Check Loki Data
```bash
# Query Loki directly
curl 'http://localhost:3100/loki/api/v1/labels'
```

**Solution if Empty**:
```bash
# Check Promtail is running
docker-compose ps promtail

# Check Promtail logs
docker-compose logs promtail

# Verify log file paths exist
docker exec -it promtail ls -la /var/log
```

### 6. Notifications Not Being Sent

**Symptom**: Analysis completes but no Slack/webhook notifications

**Diagnosis**:
```bash
docker-compose logs aiops-processor | grep -i "notification\|slack"
```

**Common Causes**:

#### No Webhook URL Configured
```
No notification channels configured
```

**Solution**:
```yaml
# Add to docker-compose.yml
environment:
  - SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

#### Invalid Webhook URL
```
Failed to send Slack notification: 404 Not Found
```

**Solution**:
```bash
# Test webhook URL manually
curl -X POST -H 'Content-Type: application/json' \
  -d '{"text":"Test"}' \
  YOUR_SLACK_WEBHOOK_URL

# If that fails, regenerate webhook in Slack
```

#### Network Issues
```
Failed to send notification: Connection refused
```

**Solution**:
```bash
# Test network connectivity
docker exec -it aiops-processor curl -I https://hooks.slack.com

# Check proxy settings if needed
```

### 7. High Memory Usage

**Symptom**: aiops-processor uses excessive memory

**Solutions**:

```yaml
# Reduce data collection limits in docker-compose.yml
environment:
  - MAX_LOG_LINES=200        # Reduce from 500
  - MAX_METRICS_POINTS=50    # Reduce from 100
  - TIME_WINDOW_MINUTES=10   # Reduce from 15

# Add memory limits
deploy:
  resources:
    limits:
      memory: 512M
```

### 8. Slow Analysis

**Symptom**: Alerts take very long to analyze

**Diagnosis**:
```bash
# Check queue backlog
curl http://localhost:8000/queue/status

# Monitor processing time in logs
docker-compose logs -f aiops-processor
```

**Solutions**:

```yaml
# Increase timeout
environment:
  - LLM_TIMEOUT=180

# Reduce data collection
environment:
  - TIME_WINDOW_MINUTES=10
  - MAX_LOG_LINES=200

# Use parallel processing (code modification)
```

### 9. Permission Errors

**Symptom**: Permission denied errors in logs

**For Volume Mounts**:
```bash
# Check ownership
docker-compose exec aiops-processor ls -la /app

# Fix permissions
sudo chown -R 1000:1000 aiops-processor/
```

**For Log Files**:
```bash
# Ensure Promtail has read access
sudo chmod -R 755 /var/log
```

### 10. Can't Access Web UIs

**Symptom**: Cannot open Prometheus/Grafana/AlertManager in browser

**Solutions**:

```bash
# Check services are running
docker-compose ps

# Check port bindings
docker-compose port prometheus 9090
docker-compose port grafana 3000

# Check firewall
sudo ufw status  # On Linux

# Try localhost vs 127.0.0.1
open http://127.0.0.1:9090
```

## Debugging Techniques

### Enable Debug Logging

Edit `aiops-processor/app.py`:
```python
logging.basicConfig(level=logging.DEBUG)  # Change from INFO
```

Rebuild and restart:
```bash
docker-compose build aiops-processor
docker-compose restart aiops-processor
```

### Inspect Alert Payloads

```bash
# Watch webhook in real-time
docker-compose logs -f aiops-processor | grep "Received webhook"

# Save sample alert for testing
curl http://localhost:8000/queue/status
```

### Test Individual Components

```python
# Create test script: test_prometheus.py
from clients.prometheus import PrometheusClient
import asyncio

async def test():
    client = PrometheusClient("http://localhost:9090")
    result = await client.query_range(
        "up",
        datetime.now() - timedelta(minutes=15),
        datetime.now()
    )
    print(result)

asyncio.run(test())
```

### Verify LLM Prompts

Add to `clients/deepseek.py`:
```python
# Before calling API
with open('/tmp/last_prompt.txt', 'w') as f:
    f.write(prompt)

# Then check the file
docker exec -it aiops-processor cat /tmp/last_prompt.txt
```

## Getting More Help

### Collect Debug Information

```bash
# Create debug bundle
cat > collect_debug.sh << 'EOF'
#!/bin/bash
mkdir -p debug_info
docker-compose ps > debug_info/services.txt
docker-compose logs > debug_info/all_logs.txt
curl http://localhost:8000/health > debug_info/health.json 2>&1
curl http://localhost:9090/api/v1/targets > debug_info/prometheus_targets.json 2>&1
docker network inspect aiops_aiops-network > debug_info/network.json
tar -czf debug_info.tar.gz debug_info/
echo "Debug info saved to debug_info.tar.gz"
EOF

chmod +x collect_debug.sh
./collect_debug.sh
```

### Check System Resources

```bash
# Docker stats
docker stats --no-stream

# Disk usage
docker system df

# Clean up if needed
docker system prune -a
```

### Reset Everything

If all else fails, complete reset:

```bash
# Stop and remove everything
docker-compose down -v

# Remove all data
rm -rf prometheus_data alertmanager_data grafana_data ollama_data loki_data

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d

# Wait for initialization
sleep 60

# Test
curl http://localhost:8000/health
```

## Still Having Issues?

1. Check the logs first: `docker-compose logs -f`
2. Verify all configuration files are present and valid
3. Ensure Docker has enough resources (4GB RAM minimum)
4. Test individual components separately
5. Review the DEVELOPMENT.md guide for customization help

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `Connection refused` | Service not ready | Wait 30s, check service is running |
| `401 Unauthorized` | Invalid API key | Check DEEPSEEK_API_KEY |
| `404 Not Found` | Wrong URL/endpoint | Verify URL configuration |
| `429 Too Many Requests` | Rate limited | Wait or increase retry delay |
| `500 Internal Server Error` | Application error | Check application logs |
| `Module not found` | Missing dependency | Rebuild container |
| `No such file or directory` | Missing config | Check all config files exist |
| `Address already in use` | Port conflict | Change port or kill other process |

---

Remember: Most issues can be resolved by checking logs and verifying configuration. When in doubt, restart the affected service!


