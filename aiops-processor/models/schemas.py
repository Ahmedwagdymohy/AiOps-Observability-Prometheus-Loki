from typing import Dict, List, Optional
from pydantic import BaseModel, Field
from datetime import datetime


class Alert(BaseModel):
    """Single alert from AlertManager"""
    status: str
    labels: Dict[str, str]
    annotations: Dict[str, str]
    startsAt: str
    endsAt: Optional[str] = ""
    generatorURL: Optional[str] = ""
    fingerprint: Optional[str] = ""


class AlertWebhook(BaseModel):
    """Webhook payload from AlertManager"""
    receiver: str
    status: str
    alerts: List[Alert]
    groupLabels: Optional[Dict[str, str]] = {}
    commonLabels: Optional[Dict[str, str]] = {}
    commonAnnotations: Optional[Dict[str, str]] = {}
    externalURL: Optional[str] = ""
    version: Optional[str] = "4"
    groupKey: Optional[str] = ""


class MetricData(BaseModel):
    """Prometheus metric data"""
    metric: Dict[str, str]
    values: List[List]  # [[timestamp, value], ...]


class LogEntry(BaseModel):
    """Loki log entry"""
    timestamp: str
    line: str
    labels: Optional[Dict[str, str]] = {}


class RemediationStep(BaseModel):
    """Single remediation step"""
    priority: int
    action: str
    command: Optional[str] = None
    description: str


class AnalysisResult(BaseModel):
    """Complete analysis result from LLM"""
    alert_name: str
    severity: str
    root_cause: str
    evidence: List[str]
    remediation_steps: List[RemediationStep]
    additional_context: Optional[str] = None
    confidence: Optional[str] = "medium"
    analyzed_at: str = Field(default_factory=lambda: datetime.utcnow().isoformat())

