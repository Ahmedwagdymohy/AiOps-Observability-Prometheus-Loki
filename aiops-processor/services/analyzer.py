import logging
from typing import Dict, Any, Optional
from datetime import datetime
from clients.prometheus import PrometheusClient
from clients.loki import LokiClient
from clients.deepseek import DeepSeekClient
from models.schemas import Alert, AnalysisResult

logger = logging.getLogger(__name__)


class AlertAnalyzer:
    """Orchestrates the alert analysis process"""
    
    def __init__(
        self,
        prometheus_client: PrometheusClient = None,
        loki_client: LokiClient = None,
        llm_client: DeepSeekClient = None
    ):
        self.prometheus = prometheus_client or PrometheusClient()
        self.loki = loki_client or LokiClient()
        self.llm = llm_client or DeepSeekClient()
    
    async def analyze_alert(self, alert: Alert) -> Optional[AnalysisResult]:
        """
        Perform comprehensive analysis of an alert
        
        Args:
            alert: Alert object from AlertManager
        
        Returns:
            AnalysisResult with root cause and remediation steps
        """
        try:
            logger.info(f"Starting analysis for alert: {alert.labels.get('alertname', 'Unknown')}")
            
            # Parse alert time
            alert_time = self._parse_alert_time(alert.startsAt)
            
            # Step 1: Gather context
            alert_context = self._build_alert_context(alert)
            
            # Step 2: Fetch Prometheus metrics
            logger.info("Fetching Prometheus metrics...")
            metrics_data = await self.prometheus.get_metrics_for_alert(
                alert.labels,
                alert_time
            )
            logger.info(f"Retrieved {len(metrics_data)} metric queries")
            
            # Step 3: Fetch Loki logs
            logger.info("Fetching Loki logs...")
            logs_data = await self.loki.get_logs_for_alert(
                alert.labels,
                alert_time
            )
            total_logs = sum(len(logs) for logs in logs_data.values())
            logger.info(f"Retrieved {total_logs} log entries from {len(logs_data)} queries")
            
            # Step 4: Analyze with LLM
            logger.info("Analyzing with LLM...")
            analysis = await self.llm.analyze_alert(
                alert_context,
                metrics_data,
                logs_data
            )
            
            if not analysis:
                logger.error("LLM analysis failed")
                return None
            
            # Step 5: Build result
            result = AnalysisResult(
                alert_name=alert.labels.get("alertname", "Unknown"),
                severity=alert.labels.get("severity", "unknown"),
                summary=analysis.get("summary", ""),
                root_cause=analysis.get("root_cause", ""),
                evidence=analysis.get("evidence", []),
                remediation_steps=analysis.get("remediation_steps", []),
                severity_assessment=analysis.get("severity_assessment", ""),
                confidence=analysis.get("confidence", 0.0)
            )
            
            logger.info(f"Analysis completed successfully for {result.alert_name}")
            return result
            
        except Exception as e:
            logger.error(f"Error during alert analysis: {e}", exc_info=True)
            return None
    
    def _parse_alert_time(self, starts_at: str) -> datetime:
        """
        Parse alert timestamp
        
        Args:
            starts_at: ISO format timestamp string
        
        Returns:
            datetime object
        """
        try:
            # Handle different timestamp formats
            if "." in starts_at:
                # Has microseconds
                return datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
            else:
                # No microseconds
                return datetime.fromisoformat(starts_at.replace("Z", "+00:00"))
        except Exception as e:
            logger.warning(f"Error parsing alert time '{starts_at}': {e}, using current time")
            return datetime.utcnow()
    
    def _build_alert_context(self, alert: Alert) -> Dict[str, Any]:
        """
        Build context dictionary from alert
        
        Args:
            alert: Alert object
        
        Returns:
            Context dictionary for LLM
        """
        context = {
            "alertname": alert.labels.get("alertname", "Unknown"),
            "severity": alert.labels.get("severity", "unknown"),
            "status": alert.status,
            "summary": alert.annotations.get("summary", ""),
            "description": alert.annotations.get("description", ""),
            "runbook_url": alert.annotations.get("runbook_url", ""),
            "labels": alert.labels,
            "starts_at": alert.startsAt,
            "generator_url": alert.generatorURL
        }
        
        return context
    
    async def batch_analyze_alerts(self, alerts: list[Alert]) -> list[AnalysisResult]:
        """
        Analyze multiple alerts
        
        Args:
            alerts: List of Alert objects
        
        Returns:
            List of AnalysisResult objects
        """
        results = []
        
        for alert in alerts:
            # Skip resolved alerts unless needed
            if alert.status == "resolved":
                logger.info(f"Skipping resolved alert: {alert.labels.get('alertname')}")
                continue
            
            result = await self.analyze_alert(alert)
            if result:
                results.append(result)
        
        return results


