# Development Guide

This guide explains how to customize and extend the AIOps system for your specific needs.

## Architecture Overview

The system follows a microservices architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                   AIOps Processor                       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐    ┌────────────────┐    ┌────────────┐   │
│  │  FastAPI │───▶│ Alert Analyzer │───▶│ Notifier   │   │
│  │ Webhook  │    └────────┬───────┘    └────────────┘   │
│  └──────────┘             │                             │
│                           │                             │
│              ┌────────────┴──────────────┐              │
│              ▼                            ▼             │
│    ┌──────────────────┐        ┌──────────────────┐     │
│    │ Prometheus Client│        │   Loki Client    │     │
│    └────────┬─────────┘        └────────┬─────────┘     │
│             │                            │              │
│             └──────────┬─────────────────┘              │
│                        ▼                                │
│              ┌──────────────────┐                       │
│              │  DeepSeek Client │                       │
│              └──────────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
aiops-processor/
├── app.py                      # Main FastAPI application & webhook endpoint
├── config.py                   # Configuration management via env vars
├── clients/                    # External service integrations
│   ├── prometheus.py          # Prometheus metrics queries
│   ├── loki.py                # Loki log queries
│   └── deepseek.py            # LLM API integration
├── services/                   # Business logic
│   ├── analyzer.py            # Orchestrates the analysis process
│   └── notifier.py            # Sends notifications
└── models/                     # Data models
    └── schemas.py             # Pydantic models for type safety
```

## Key Components

### 1. FastAPI Application (`app.py`)

**Responsibilities:**
- Receive webhook notifications from AlertManager
- Queue alerts for processing
- Provide health check and status endpoints
- Handle background processing

**Key Endpoints:**
- `POST /webhook/alerts` - AlertManager webhook receiver
- `POST /analyze` - Manual alert analysis trigger
- `GET /health` - Health check
- `GET /queue/status` - View processing queue

**Customization Points:**
- Add authentication middleware
- Add custom endpoints for manual queries
- Modify queue processing strategy
- Add metrics export

### 2. Alert Analyzer (`services/analyzer.py`)

**Responsibilities:**
- Parse alert information
- Coordinate data gathering from Prometheus and Loki
- Send context to LLM for analysis
- Build structured analysis results

**Customization Points:**
```python
# Modify time window calculation
def _parse_alert_time(self, starts_at: str) -> datetime:
    # Add custom timezone handling
    # Add business hours consideration
    pass

# Add pre-processing filters
async def analyze_alert(self, alert: Alert) -> Optional[AnalysisResult]:
    # Filter out certain alerts
    if alert.labels.get("alertname") in IGNORE_LIST:
        return None
    # Proceed with analysis
```

### 3. Prometheus Client (`clients/prometheus.py`)

**Responsibilities:**
- Build PromQL queries based on alert labels
- Query Prometheus for time-series data
- Handle query timeouts and errors

**Customization Points:**

```python
def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
    queries = {}
    
    # Add custom metric queries for your services
    if labels.get("service") == "my-api":
        queries["api_request_rate"] = f'rate(http_requests_total{{service="my-api"}}[5m])'
        queries["api_error_rate"] = f'rate(http_requests_total{{service="my-api",status=~"5.."}}[5m])'
    
    # Add business metrics
    if "transaction" in labels.get("alertname", "").lower():
        queries["transaction_volume"] = 'sum(transaction_count) by (type)'
    
    return queries
```

### 4. Loki Client (`clients/loki.py`)

**Responsibilities:**
- Build LogQL queries based on alert context
- Query Loki for relevant logs
- Parse and structure log results

**Customization Points:**

```python
def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
    queries = {}
    
    # Add custom log queries for your services
    if labels.get("service") == "payment-service":
        queries["payment_errors"] = '{service="payment-service"} |~ "payment.*failed"'
        queries["payment_transactions"] = '{service="payment-service"} | json | status="completed"'
    
    # Add security-related logs
    if labels.get("component") == "auth":
        queries["auth_failures"] = '{service=~".*auth.*"} |~ "failed.*login"'
    
    return queries
```

### 5. DeepSeek Client (`clients/deepseek.py`)

**Responsibilities:**
- Format alert context, metrics, and logs for LLM
- Call DeepSeek API with retry logic
- Parse and validate LLM responses

**Customization Points:**

```python
def _build_analysis_prompt(self, alert_context, metrics_data, logs_data) -> str:
    # Customize the system prompt
    system_context = """
    You are an expert SRE for {YOUR_COMPANY}.
    You have deep knowledge of our microservices architecture.
    Our stack includes: Kubernetes, PostgreSQL, Redis, Node.js
    
    Priority areas:
    1. Customer-facing services (severity: critical)
    2. Payment processing (severity: critical)
    3. Internal tools (severity: low)
    """
    
    # Add company-specific context
    runbook_context = self._get_runbook_context(alert_context)
    
    # Modify output format
    prompt += """
    Additional Requirements:
    - Include JIRA ticket suggestions
    - Reference our runbook: {runbook_url}
    - Suggest rollback if recent deployment
    """
    
    return prompt
```

### 6. Notifier (`services/notifier.py`)

**Responsibilities:**
- Format analysis results for different channels
- Send notifications via Slack, webhooks, etc.
- Handle notification failures

**Customization Points:**

```python
# Add new notification channels
async def _send_pagerduty_alert(self, payload: NotificationPayload) -> bool:
    """Send critical alerts to PagerDuty"""
    if payload.severity == "critical":
        # PagerDuty API integration
        pass

async def _send_email_notification(self, payload: NotificationPayload) -> bool:
    """Send email notifications"""
    # SMTP integration
    pass

# Customize Slack message format
def _build_slack_message(self, payload: NotificationPayload) -> dict:
    # Add custom fields
    # Change colors/formatting
    # Add action buttons
    pass
```

## Common Customizations

### Adding Support for New Alert Types

1. **Update Prometheus queries** (`clients/prometheus.py`):
```python
def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
    # Add new condition
    if labels.get("component") == "your_component":
        queries["custom_metric"] = 'your_promql_query'
    return queries
```

2. **Update Loki queries** (`clients/loki.py`):
```python
def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
    if labels.get("component") == "your_component":
        queries["custom_logs"] = '{your_label="value"} |~ "pattern"'
    return queries
```

3. **Update LLM prompt** (`clients/deepseek.py`):
```python
# Add specific instructions for this alert type
if alert_context.get("component") == "your_component":
    prompt += "Special considerations for this component..."
```

### Adding Pre-Analysis Filters

```python
# In services/analyzer.py
async def analyze_alert(self, alert: Alert) -> Optional[AnalysisResult]:
    # Skip test environments
    if alert.labels.get("environment") == "test":
        logger.info("Skipping test environment alert")
        return None
    
    # Skip low-priority alerts during business hours
    if self._is_business_hours() and alert.labels.get("severity") == "info":
        return None
    
    # Proceed with analysis
    ...
```

### Adding Post-Analysis Actions

```python
# In services/analyzer.py
async def analyze_alert(self, alert: Alert) -> Optional[AnalysisResult]:
    result = await self.llm.analyze_alert(...)
    
    # Auto-create JIRA ticket for critical alerts
    if alert.labels.get("severity") == "critical":
        await self._create_jira_ticket(result)
    
    # Auto-scale if capacity issue
    if "capacity" in result.root_cause.lower():
        await self._trigger_autoscaling(alert.labels)
    
    return result
```

### Changing LLM Provider

To use a different LLM (OpenAI, Anthropic, local Ollama):

1. **Update config.py**:
```python
class Settings(BaseSettings):
    llm_provider: str = os.getenv("LLM_PROVIDER", "deepseek")  # or "openai", "ollama"
    openai_api_key: str = os.getenv("OPENAI_API_KEY", "")
    # ...
```

2. **Create new client** (`clients/openai.py`):
```python
class OpenAIClient:
    async def analyze_alert(self, alert_context, metrics_data, logs_data):
        # OpenAI API integration
        pass
```

3. **Update analyzer to use factory**:
```python
def get_llm_client():
    if settings.llm_provider == "openai":
        return OpenAIClient()
    elif settings.llm_provider == "ollama":
        return OllamaClient()
    else:
        return DeepSeekClient()
```

### Adding Metrics Export

Export AIOps processor metrics to Prometheus:

```python
# Add to app.py
from prometheus_client import Counter, Histogram, make_asgi_app

# Metrics
alerts_processed = Counter('aiops_alerts_processed_total', 'Total alerts processed')
analysis_duration = Histogram('aiops_analysis_duration_seconds', 'Analysis duration')

# Mount metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Use in code
@analysis_duration.time()
async def analyze_alert(self, alert):
    result = await self._do_analysis(alert)
    alerts_processed.inc()
    return result
```

## Development Workflow

### Local Development

1. **Set up Python environment**:
```bash
cd aiops-processor
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt
```

2. **Run locally** (outside Docker):
```bash
export PROMETHEUS_URL=http://localhost:9090
export LOKI_URL=http://localhost:3100
export DEEPSEEK_API_KEY=your_key

python app.py
```

3. **Make changes and test**:
```bash
# The app will auto-reload if you use uvicorn with --reload
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

### Testing Changes in Docker

1. **Rebuild the container**:
```bash
docker-compose build aiops-processor
```

2. **Restart the service**:
```bash
docker-compose restart aiops-processor
```

3. **View logs**:
```bash
docker-compose logs -f aiops-processor
```

### Hot Reload in Docker

Use docker-compose override for development:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  aiops-processor:
    volumes:
      - ./aiops-processor:/app
    command: uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

## Testing

### Unit Tests

Create `aiops-processor/tests/test_analyzer.py`:

```python
import pytest
from services.analyzer import AlertAnalyzer
from models.schemas import Alert

@pytest.mark.asyncio
async def test_alert_analysis():
    analyzer = AlertAnalyzer()
    
    alert = Alert(
        status="firing",
        labels={"alertname": "TestAlert"},
        annotations={"summary": "Test"},
        startsAt="2025-10-16T10:00:00Z",
        endsAt="",
        generatorURL="http://test",
        fingerprint="test123"
    )
    
    result = await analyzer.analyze_alert(alert)
    assert result is not None
    assert result.alert_name == "TestAlert"
```

### Integration Tests

Test the full flow:

```bash
# Use the test-alert.sh script
./test-alert.sh

# Or curl directly
curl -X POST http://localhost:8000/analyze -H "Content-Type: application/json" -d @test_alert.json
```

## Debugging

### Enable Debug Logging

```python
# In app.py
logging.basicConfig(level=logging.DEBUG)
```

### Inspect Alert Context

```python
# In services/analyzer.py
async def analyze_alert(self, alert: Alert):
    logger.info(f"Full alert context: {alert.model_dump_json(indent=2)}")
    logger.info(f"Metrics data: {json.dumps(metrics_data, indent=2)}")
    logger.info(f"Logs data: {json.dumps(logs_data, indent=2)}")
```

### Test LLM Prompt

Save the prompt to see what's being sent:

```python
# In clients/deepseek.py
async def analyze_alert(self, ...):
    prompt = self._build_analysis_prompt(...)
    
    # Save for inspection
    with open('/tmp/llm_prompt.txt', 'w') as f:
        f.write(prompt)
    
    response = await self._call_api(prompt)
```

## Best Practices

1. **Always validate input data** - Use Pydantic models
2. **Handle errors gracefully** - Don't let one bad alert crash the system
3. **Log extensively** - You'll need it for debugging
4. **Keep queries efficient** - Limit time ranges and result sizes
5. **Rate limit LLM calls** - Implement backoff for API errors
6. **Cache when possible** - Cache frequent queries
7. **Monitor the monitor** - Export metrics about the AIOps system itself

## Performance Tuning

### Parallel Processing

```python
# Process multiple alerts concurrently
async def batch_analyze_alerts(self, alerts: List[Alert]):
    tasks = [self.analyze_alert(alert) for alert in alerts]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return [r for r in results if not isinstance(r, Exception)]
```

### Query Optimization

```python
# Limit metric data points
queries = {
    "cpu_usage": f'avg_over_time(cpu_usage[{window}m])[5m:30s]'  # 30s steps
}
```

### Caching

```python
from functools import lru_cache

@lru_cache(maxsize=100)
async def get_cached_metrics(query: str, start: str, end: str):
    # Cache metric queries
    pass
```

## Deployment Considerations

- Use Docker secrets for API keys in production
- Set resource limits in docker-compose.yml
- Enable HTTPS for webhook endpoints
- Implement authentication for API endpoints
- Set up monitoring for the AIOps processor itself
- Configure log rotation
- Use persistent volumes for any local caching

## Contributing

When extending the system:

1. Maintain backward compatibility
2. Add configuration options rather than hardcoding
3. Update documentation
4. Add tests for new features
5. Follow existing code style
6. Log important actions and decisions

---

Happy coding! 🚀


