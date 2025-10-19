# AIOps System Architecture

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        External Services                             │
│  ┌──────────────┐                           ┌──────────────┐        │
│  │ DeepSeek API │                           │ Slack/Webhook│        │
│  └──────┬───────┘                           └──────▲───────┘        │
│         │                                           │                │
└─────────┼───────────────────────────────────────────┼────────────────┘
          │                                           │
          │ HTTPS                                     │ HTTPS
          │                                           │
┌─────────┼───────────────────────────────────────────┼────────────────┐
│         │              Docker Network               │                │
│         │         (aiops-network)                   │                │
│         │                                           │                │
│  ┌──────▼─────────────────────────────────────┐     │                │
│  │         AIOps Processor                     │    │                │
│  │  ┌───────────────────────────────────────┐ │    │                 │
│  │  │         FastAPI Application           │ │    │                 │
│  │  │  - Webhook Endpoint (/webhook/alerts) │ │    │                 │
│  │  │  - Manual Analysis (/analyze)         │ │    │                 │
│  │  │  - Health Check (/health)             │ │    │                 │
│  │  │  - Queue Processor (background)       │ │    │                 │
│  │  └───────────────┬───────────────────────┘ │    │                 │
│  │                  │                          │    │                │
│  │  ┌───────────────▼──────────┐              │    │                 │
│  │  │   Alert Analyzer         │              │    │                 │
│  │  │   (services/analyzer.py) │              │    │                 │
│  │  └───┬──────────────────┬───┘              │    │                 │
│  │      │                  │                   │    │                │
│  │  ┌───▼─────┐       ┌───▼────┐   ┌─────────▼────▼──┐            │
│  │  │Prometheus│       │  Loki  │   │   DeepSeek      │            │
│  │  │ Client   │       │ Client │   │   LLM Client    │            │
│  │  └───┬──────┘       └───┬────┘   └─────────┬───────┘            │
│  │      │                  │                   │                    │
│  │      │                  │                   └─────────────┐      │
│  │      │                  │                                 │      │
│  └──────┼──────────────────┼─────────────────────────────────┼──────┘
│         │                  │                                 │       │
│         │                  │                   ┌─────────────▼──────┐│
│         │                  │                   │  Notification      ││
│         │                  │                   │  Service           ││
│         │                  │                   └────────────────────┘│
│  ┌──────▼──────┐    ┌──────▼──────┐                                 │
│  │ Prometheus  │    │    Loki     │                                 │
│  │  :9090      │    │   :3100     │                                 │
│  │             │    │             │                                 │
│  │ - Metrics   │    │ - Logs      │                                 │
│  │ - Alerts    │    │ - Search    │                                 │
│  └──────▲──────┘    └──────▲──────┘                                 │
│         │                  │                                         │
│         │Scrape            │Push                                     │
│         │                  │                                         │
│  ┌──────┴────┐      ┌──────┴───────┐                                │
│  │Node       │      │  Promtail    │                                │
│  │Exporter   │      │   :9080      │                                │
│  │ :9100     │      │              │                                │
│  └───────────┘      │ Collects logs│                                │
│                     │ from Docker  │                                │
│         ▲           └──────┬───────┘                                │
│         │                  │                                         │
│         │Metrics           │Logs                                     │
│         │                  │                                         │
│  ┌──────┴──────────────────▼──────┐                                 │
│  │   Docker Container Logs         │                                 │
│  │   /var/log                      │                                 │
│  │   /var/lib/docker/containers    │                                 │
│  └─────────────────────────────────┘                                 │
│                                                                       │
│  ┌─────────────────────────────────────────────┐                    │
│  │         AlertManager :9093                   │                    │
│  │  - Receives alerts from Prometheus           │                    │
│  │  - Routes to AIOps Processor webhook        │                    │
│  │  - Handles grouping & deduplication         │                    │
│  └─────────────────────────────────────────────┘                    │
│                                                                       │
│  ┌─────────────────────────────────────────────┐                    │
│  │         Grafana :3000                        │                    │
│  │  - Visualizes Prometheus metrics             │                    │
│  │  - Visualizes Loki logs                     │                    │
│  │  - Dashboards for monitoring                │                    │
│  └─────────────────────────────────────────────┘                    │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Alert Processing

```
1. ALERT TRIGGERED
   ┌─────────────┐
   │ Prometheus  │ Evaluates metrics against alert rules
   │             │ every 30 seconds
   └──────┬──────┘
          │
          │ Alert fires
          ▼
   ┌─────────────┐
   │AlertManager │ Receives alert, applies grouping rules
   └──────┬──────┘
          │
          │ HTTP POST /webhook/alerts
          ▼

2. WEBHOOK RECEIVED
   ┌──────────────────────────┐
   │ AIOps Processor          │
   │ FastAPI Endpoint         │
   │                          │
   │ 1. Validate payload      │
   │ 2. Filter firing alerts  │
   │ 3. Add to processing     │
   │    queue                 │
   └──────┬───────────────────┘
          │
          │ Alert queued
          ▼

3. BACKGROUND PROCESSING
   ┌──────────────────────────┐
   │ Queue Processor          │
   │ (async background task)  │
   │                          │
   │ 1. Dequeue alert         │
   │ 2. Call analyzer         │
   │ 3. Handle errors         │
   │ 4. Mark task done        │
   └──────┬───────────────────┘
          │
          │ Start analysis
          ▼

4. ALERT ANALYSIS
   ┌──────────────────────────┐
   │ Alert Analyzer           │
   │                          │
   │ A. Parse alert time      │
   │ B. Build context         │
   │ C. Gather data           │
   │ D. LLM analysis          │
   │ E. Format result         │
   └──────┬───────────────────┘
          │
          ├─────────────────────┐
          │                     │
          ▼                     ▼

5. DATA GATHERING (Parallel)
   
   ┌──────────────┐    ┌──────────────┐
   │ Prometheus   │    │   Loki       │
   │ Client       │    │   Client     │
   │              │    │              │
   │ Build queries│    │ Build queries│
   │ based on     │    │ based on     │
   │ alert labels │    │ alert labels │
   │              │    │              │
   │ - CPU usage  │    │ - Errors     │
   │ - Memory     │    │ - Warnings   │
   │ - Disk I/O   │    │ - Service    │
   │ - Network    │    │   logs       │
   │              │    │              │
   │ Query range: │    │ Query range: │
   │ [T-15m, T+15m]    │ [T-15m, T+15m]
   └──────┬───────┘    └──────┬───────┘
          │                   │
          │ Metrics data      │ Log data
          │                   │
          └─────────┬─────────┘
                    ▼

6. LLM ANALYSIS
   ┌──────────────────────────┐
   │ DeepSeek Client          │
   │                          │
   │ 1. Build comprehensive   │
   │    prompt:               │
   │    - Alert details       │
   │    - Metrics summary     │
   │    - Log entries         │
   │                          │
   │ 2. Call DeepSeek API     │
   │    (with retry logic)    │
   │                          │
   │ 3. Parse JSON response   │
   │                          │
   │ 4. Validate structure    │
   └──────┬───────────────────┘
          │
          │ Analysis Result:
          │ - Summary
          │ - Root Cause
          │ - Evidence
          │ - Remediation Steps
          │ - Severity Assessment
          ▼

7. NOTIFICATION
   ┌──────────────────────────┐
   │ Notification Service     │
   │                          │
   │ 1. Format for Slack      │
   │    - Rich blocks         │
   │    - Color coding        │
   │    - Structured layout   │
   │                          │
   │ 2. Send to configured    │
   │    channels              │
   │    - Slack webhook       │
   │    - Generic webhook     │
   │    - Log fallback        │
   └──────┬───────────────────┘
          │
          │ Success/Failure
          ▼
   ┌──────────────┐
   │   Slack /    │
   │   Webhook    │
   │   Endpoint   │
   └──────────────┘

8. COMPLETION
   - Alert marked as processed
   - Next alert dequeued
   - Logs written for audit
```

## Component Interaction Matrix

| Component | Calls | Called By | Data Flow |
|-----------|-------|-----------|-----------|
| **FastAPI App** | Analyzer, Notifier | AlertManager (webhook) | HTTP → Queue → Analysis |
| **Alert Analyzer** | Prometheus Client, Loki Client, DeepSeek Client | FastAPI App | Orchestrates analysis |
| **Prometheus Client** | Prometheus API | Alert Analyzer | PromQL → Time-series data |
| **Loki Client** | Loki API | Alert Analyzer | LogQL → Log entries |
| **DeepSeek Client** | DeepSeek API | Alert Analyzer | Context → LLM Analysis |
| **Notifier** | Slack, Webhooks | Alert Analyzer | Analysis → Notifications |
| **Prometheus** | Node Exporter, Services | Prometheus Client | Scrapes metrics |
| **AlertManager** | AIOps Webhook | Prometheus | Routes alerts |
| **Loki** | None | Loki Client, Promtail | Stores logs |
| **Promtail** | Loki | Docker logs | Ships logs |

## Key Design Patterns

### 1. **Async Processing**
- Webhook endpoint responds immediately
- Background queue processes alerts sequentially
- Prevents blocking and timeout issues

### 2. **Client Abstraction**
- Each external service has dedicated client
- Clients handle authentication, retries, errors
- Easy to swap implementations

### 3. **Dynamic Query Building**
- Queries built from alert labels, not hardcoded
- Adapts to any Prometheus/Loki setup
- Extensible for custom services

### 4. **Structured Data Models**
- Pydantic models for type safety
- Validation at boundaries
- Clear contracts between components

### 5. **Error Handling**
- Retries with exponential backoff
- Graceful degradation (continue even if data source fails)
- Comprehensive logging

### 6. **Configuration as Code**
- Environment variables for all settings
- Sensible defaults
- No hardcoded values

## Network Topology

```
┌─────────────────────────────────────────────────────────┐
│              aiops-network (bridge)                      │
│                                                          │
│  Container Name       Internal DNS        Ports         │
│  ───────────────────────────────────────────────────    │
│  prometheus          prometheus:9090      9090→9090     │
│  alertmanager        alertmanager:9093    9093→9093     │
│  grafana             grafana:3000         3000→3000     │
│  loki                loki:3100            3100→3100     │
│  promtail            promtail:9080        (internal)    │
│  aiops-processor     aiops-processor:8000 8000→8000     │
│  node-exporter       node-exporter:9100   9100→9100     │
│  ollama              ollama:11434         11434→11434   │
│                                                          │
│  All containers can reach each other by name            │
│  Host can access via localhost:PORT                     │
└─────────────────────────────────────────────────────────┘

External Access:
┌────────────────────┐
│   Host Machine     │
│                    │
│ localhost:9090  ──┼──→ Prometheus UI
│ localhost:3000  ──┼──→ Grafana UI
│ localhost:9093  ──┼──→ AlertManager UI
│ localhost:8000  ──┼──→ AIOps API
│                    │
└────────────────────┘
```

## Data Storage

```
Docker Volumes (Persistent):
┌────────────────────────────────────────┐
│ prometheus_data                        │
│  └─ Time-series metrics database       │
│                                        │
│ alertmanager_data                      │
│  └─ Alert state and silences           │
│                                        │
│ grafana_data                           │
│  └─ Dashboards, users, settings        │
│                                        │
│ loki_data                              │
│  └─ Log chunks and index               │
│                                        │
│ ollama_data                            │
│  └─ Downloaded LLM models              │
└────────────────────────────────────────┘

Mounted Directories (Configuration):
┌────────────────────────────────────────┐
│ ./prometheus/* → Prometheus config     │
│ ./alertmanager/* → AlertManager config │
│ ./loki/* → Loki/Promtail config        │
│ ./grafana/* → Grafana datasources      │
│ ./aiops-processor/* → Application code │
└────────────────────────────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────┐
│              Security Layers                         │
├─────────────────────────────────────────────────────┤
│                                                      │
│ 1. Network Isolation                                │
│    - Private Docker network                         │
│    - No direct external access (except ports)       │
│                                                      │
│ 2. Container Security                               │
│    - Non-root user (UID 1000)                       │
│    - Read-only root filesystem where possible       │
│    - Minimal base images (Python slim)              │
│                                                      │
│ 3. Secret Management                                │
│    - Environment variables                          │
│    - .gitignore for sensitive files                 │
│    - Docker secrets (production ready)              │
│                                                      │
│ 4. API Security                                     │
│    - HTTPS for external APIs (DeepSeek)             │
│    - Webhook signature verification (to add)        │
│    - Rate limiting (to add)                         │
│                                                      │
│ 5. Data Security                                    │
│    - No PII logged                                  │
│    - Configurable data retention                    │
│    - Volume encryption (optional)                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Scalability Considerations

### Current Capacity
- **Sequential processing**: One alert at a time
- **In-memory queue**: Lost on restart
- **Single instance**: No horizontal scaling

### Scaling Path

```
Phase 1: Current (Single Node)
┌──────────────────┐
│ AIOps Processor  │
│ (1 instance)     │
└──────────────────┘

Phase 2: Parallel Processing
┌──────────────────┐
│ AIOps Processor  │
│ (1 instance)     │
│ + Worker pool    │
└──────────────────┘

Phase 3: Distributed Queue
┌──────────────────┐      ┌──────────┐
│ AIOps Processor  │─────▶│  Redis   │
│ (multiple)       │      │  Queue   │
└──────────────────┘      └──────────┘

Phase 4: Full Distribution
┌──────────────────┐      ┌──────────┐      ┌────────────┐
│ AIOps Processor  │─────▶│  Redis   │─────▶│ PostgreSQL │
│ (load balanced)  │      │  Queue   │      │  History   │
└──────────────────┘      └──────────┘      └────────────┘
```

## Extensibility Points

1. **Add New Data Sources**
   - Create client in `clients/`
   - Call from analyzer
   - Include in LLM context

2. **Add New LLM Providers**
   - Implement client interface
   - Add to config
   - Update analyzer factory

3. **Add New Notification Channels**
   - Add method to notifier
   - Configure endpoint
   - Format payload

4. **Add Webhooks**
   - Add FastAPI endpoint
   - Implement handler
   - Update routing

5. **Add Persistence**
   - Add database client
   - Store analysis results
   - Query history

---

This architecture provides a solid foundation for an enterprise-grade AIOps system with clear separation of concerns, extensibility, and production readiness.


