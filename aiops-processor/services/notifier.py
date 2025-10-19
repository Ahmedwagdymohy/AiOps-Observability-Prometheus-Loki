import httpx
import logging
import json
from typing import Optional
from datetime import datetime
from models.schemas import AnalysisResult, NotificationPayload
from config import settings

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for sending notifications about alert analysis"""
    
    def __init__(
        self,
        slack_webhook_url: str = None,
        generic_webhook_url: str = None
    ):
        self.slack_webhook_url = slack_webhook_url or settings.slack_webhook_url
        self.generic_webhook_url = generic_webhook_url or settings.generic_webhook_url
        self.timeout = 10.0
    
    async def send_analysis(
        self,
        analysis: AnalysisResult,
        alert_context: dict = None
    ) -> bool:
        """
        Send analysis result via configured notification channels
        
        Args:
            analysis: AnalysisResult object
            alert_context: Additional context about the alert
        
        Returns:
            True if at least one notification was sent successfully
        """
        success = False
        
        # Build notification payload
        payload = NotificationPayload(
            alert_name=analysis.alert_name,
            severity=analysis.severity,
            instance=alert_context.get("instance") if alert_context else None,
            analysis=analysis,
            alert_url=alert_context.get("generator_url") if alert_context else None,
            prometheus_url=settings.prometheus_url
        )
        
        # Send to Slack if configured
        if self.slack_webhook_url:
            slack_success = await self._send_slack_notification(payload)
            success = success or slack_success
        
        # Send to generic webhook if configured
        if self.generic_webhook_url:
            webhook_success = await self._send_generic_webhook(payload)
            success = success or webhook_success
        
        # Log if no notifications were configured
        if not self.slack_webhook_url and not self.generic_webhook_url:
            logger.warning("No notification channels configured. Logging analysis result:")
            logger.info(f"Analysis: {analysis.model_dump_json(indent=2)}")
            success = True  # Consider it successful if we logged it
        
        return success
    
    async def _send_slack_notification(self, payload: NotificationPayload) -> bool:
        """
        Send notification to Slack
        
        Args:
            payload: NotificationPayload object
        
        Returns:
            True if successful
        """
        try:
            # Build Slack message
            slack_message = self._build_slack_message(payload)
            
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.slack_webhook_url,
                    json=slack_message
                )
                response.raise_for_status()
            
            logger.info(f"Successfully sent Slack notification for {payload.alert_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send Slack notification: {e}")
            return False
    
    def _build_slack_message(self, payload: NotificationPayload) -> dict:
        """Build a formatted Slack message"""
        analysis = payload.analysis
        
        # Determine color based on severity
        color_map = {
            "critical": "#d32f2f",  # Red
            "warning": "#f57c00",   # Orange
            "info": "#1976d2"       # Blue
        }
        color = color_map.get(payload.severity.lower(), "#757575")
        
        # Build evidence text
        evidence_text = "\n".join([f"• {ev}" for ev in analysis.evidence[:5]])
        
        # Build remediation steps
        remediation_text = "\n".join([f"{i+1}. {step}" for i, step in enumerate(analysis.remediation_steps)])
        
        # Build the message
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"🚨 Alert Analysis: {payload.alert_name}",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "fields": [
                    {
                        "type": "mrkdwn",
                        "text": f"*Severity:*\n{payload.severity.upper()}"
                    },
                    {
                        "type": "mrkdwn",
                        "text": f"*Confidence:*\n{analysis.confidence:.0%}"
                    }
                ]
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Summary:*\n{analysis.summary}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Root Cause:*\n{analysis.root_cause}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Evidence:*\n{evidence_text}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Remediation Steps:*\n{remediation_text}"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*Severity Assessment:*\n{analysis.severity_assessment}"
                }
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": f"Analyzed at {analysis.analyzed_at} | <{payload.prometheus_url}|Prometheus Dashboard>"
                    }
                ]
            }
        ]
        
        return {
            "attachments": [
                {
                    "color": color,
                    "blocks": blocks
                }
            ]
        }
    
    async def _send_generic_webhook(self, payload: NotificationPayload) -> bool:
        """
        Send notification to a generic webhook
        
        Args:
            payload: NotificationPayload object
        
        Returns:
            True if successful
        """
        try:
            # Convert to dict for JSON serialization
            webhook_data = {
                "alert_name": payload.alert_name,
                "severity": payload.severity,
                "instance": payload.instance,
                "analysis": {
                    "summary": payload.analysis.summary,
                    "root_cause": payload.analysis.root_cause,
                    "evidence": payload.analysis.evidence,
                    "remediation_steps": payload.analysis.remediation_steps,
                    "severity_assessment": payload.analysis.severity_assessment,
                    "confidence": payload.analysis.confidence,
                    "analyzed_at": payload.analysis.analyzed_at
                },
                "urls": {
                    "alert": payload.alert_url,
                    "prometheus": payload.prometheus_url
                }
            }
            
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.generic_webhook_url,
                    json=webhook_data
                )
                response.raise_for_status()
            
            logger.info(f"Successfully sent webhook notification for {payload.alert_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to send webhook notification: {e}")
            return False
    
    def format_analysis_text(self, analysis: AnalysisResult) -> str:
        """
        Format analysis result as plain text
        
        Args:
            analysis: AnalysisResult object
        
        Returns:
            Formatted text string
        """
        evidence_text = "\n".join([f"  - {ev}" for ev in analysis.evidence])
        remediation_text = "\n".join([f"  {i+1}. {step}" for i, step in enumerate(analysis.remediation_steps)])
        
        return f"""
Alert Analysis: {analysis.alert_name}
Severity: {analysis.severity}
Confidence: {analysis.confidence:.0%}

Summary:
{analysis.summary}

Root Cause:
{analysis.root_cause}

Evidence:
{evidence_text}

Remediation Steps:
{remediation_text}

Severity Assessment:
{analysis.severity_assessment}

Analyzed at: {analysis.analyzed_at}
"""


