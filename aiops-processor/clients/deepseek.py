import httpx
import logging
import json
from typing import Dict, Any, Optional
from tenacity import retry, stop_after_attempt, wait_exponential
from config import settings

logger = logging.getLogger(__name__)


class DeepSeekClient:
    """Client for DeepSeek LLM API"""
    
    def __init__(self, api_key: str = None, api_url: str = None, model: str = None):
        self.api_key = api_key or settings.deepseek_api_key
        self.api_url = api_url or settings.deepseek_api_url
        self.model = model or settings.deepseek_model
        self.timeout = settings.llm_timeout
        self.temperature = settings.llm_temperature
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    async def analyze_alert(
        self,
        alert_context: Dict[str, Any],
        metrics_data: Dict[str, Any],
        logs_data: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Analyze an alert using the LLM
        
        Args:
            alert_context: Alert details (labels, annotations, etc.)
            metrics_data: Prometheus metrics related to the alert
            logs_data: Loki logs related to the alert
        
        Returns:
            Analysis result as a dictionary
        """
        prompt = self._build_analysis_prompt(alert_context, metrics_data, logs_data)
        
        try:
            response = await self._call_api(prompt)
            return self._parse_analysis_response(response)
        except Exception as e:
            logger.error(f"Error analyzing alert with LLM: {e}")
            return None
    
    def _build_analysis_prompt(
        self,
        alert_context: Dict[str, Any],
        metrics_data: Dict[str, Any],
        logs_data: Dict[str, Any]
    ) -> str:
        """
        Build a comprehensive prompt for alert analysis
        
        Args:
            alert_context: Alert information
            metrics_data: Metrics time-series
            logs_data: Log entries
        
        Returns:
            Formatted prompt string
        """
        # Extract alert details
        alert_name = alert_context.get("alertname", "Unknown")
        severity = alert_context.get("severity", "unknown")
        summary = alert_context.get("summary", "")
        description = alert_context.get("description", "")
        labels = alert_context.get("labels", {})
        
        # Format metrics for the prompt
        metrics_summary = self._format_metrics_for_prompt(metrics_data)
        
        # Format logs for the prompt
        logs_summary = self._format_logs_for_prompt(logs_data)
        
        prompt = f"""You are an expert Site Reliability Engineer (SRE) analyzing a production alert. Your task is to perform root cause analysis and provide actionable remediation steps.

**ALERT INFORMATION:**
- Alert Name: {alert_name}
- Severity: {severity}
- Summary: {summary}
- Description: {description}
- Labels: {json.dumps(labels, indent=2)}

**METRICS DATA:**
{metrics_summary}

**LOG DATA:**
{logs_summary}

**ANALYSIS REQUIRED:**
Please analyze the above information and provide:

1. **Summary**: A brief 2-3 sentence summary of the incident
2. **Root Cause**: The most likely root cause based on metrics and logs
3. **Evidence**: Specific evidence from metrics and logs supporting your analysis (list 3-5 key pieces of evidence)
4. **Remediation Steps**: Concrete, actionable steps to resolve the issue (ordered by priority)
5. **Severity Assessment**: Your assessment of the actual impact (Critical/High/Medium/Low) with justification

**OUTPUT FORMAT:**
Respond ONLY with a valid JSON object in this exact format:
{{
  "summary": "Brief summary here",
  "root_cause": "Identified root cause",
  "evidence": [
    "Evidence point 1",
    "Evidence point 2",
    "Evidence point 3"
  ],
  "remediation_steps": [
    "Step 1: Immediate action",
    "Step 2: Short-term fix",
    "Step 3: Long-term solution"
  ],
  "severity_assessment": "Critical/High/Medium/Low - Justification",
  "confidence": 0.85
}}

Provide your analysis now:"""
        
        return prompt
    
    def _format_metrics_for_prompt(self, metrics_data: Dict[str, Any]) -> str:
        """Format metrics data for inclusion in prompt"""
        if not metrics_data:
            return "No metrics data available."
        
        formatted = []
        for metric_name, results in metrics_data.items():
            formatted.append(f"\n**{metric_name}:**")
            
            for result in results[:3]:  # Limit to first 3 series per metric
                metric_labels = result.get("metric", {})
                values = result.get("values", [])
                
                if values:
                    # Get first, middle, and last values
                    first_val = values[0][1] if len(values) > 0 else "N/A"
                    mid_val = values[len(values)//2][1] if len(values) > 1 else first_val
                    last_val = values[-1][1] if len(values) > 0 else first_val
                    
                    labels_str = ", ".join([f"{k}={v}" for k, v in metric_labels.items() if k != "__name__"])
                    formatted.append(f"  - {labels_str}")
                    formatted.append(f"    Start: {first_val}, Mid: {mid_val}, End: {last_val} ({len(values)} data points)")
        
        return "\n".join(formatted) if formatted else "No metric results found."
    
    def _format_logs_for_prompt(self, logs_data: Dict[str, Any]) -> str:
        """Format log data for inclusion in prompt"""
        if not logs_data:
            return "No log data available."
        
        formatted = []
        total_logs = 0
        
        for log_query, log_entries in logs_data.items():
            if not log_entries:
                continue
            
            formatted.append(f"\n**{log_query}** ({len(log_entries)} entries):")
            
            # Show most relevant logs (first 10)
            for entry in log_entries[:10]:
                timestamp = entry.get("timestamp", "")
                line = entry.get("line", "")
                # Truncate very long log lines
                if len(line) > 200:
                    line = line[:200] + "..."
                formatted.append(f"  [{timestamp}] {line}")
            
            total_logs += len(log_entries)
            
            if len(log_entries) > 10:
                formatted.append(f"  ... and {len(log_entries) - 10} more entries")
        
        if not formatted:
            return "No relevant logs found."
        
        return "\n".join([f"Total log entries: {total_logs}"] + formatted)
    
    async def _call_api(self, prompt: str) -> str:
        """
        Call the DeepSeek API
        
        Args:
            prompt: The prompt to send
        
        Returns:
            API response text
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": "You are an expert SRE and DevOps engineer specializing in incident analysis and root cause determination. Always respond with valid JSON."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": self.temperature,
            "max_tokens": 2000,
            "response_format": {"type": "json_object"}
        }
        
        logger.info(f"Calling DeepSeek API with model: {self.model}")
        
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                self.api_url,
                headers=headers,
                json=payload
            )
            response.raise_for_status()
            
            data = response.json()
            content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            
            logger.info("Successfully received response from DeepSeek API")
            return content
    
    def _parse_analysis_response(self, response: str) -> Dict[str, Any]:
        """
        Parse the LLM response into a structured format
        
        Args:
            response: Raw LLM response
        
        Returns:
            Parsed analysis result
        """
        try:
            # Try to parse as JSON
            result = json.loads(response)
            
            # Ensure all required fields are present
            required_fields = ["summary", "root_cause", "evidence", "remediation_steps", "severity_assessment"]
            for field in required_fields:
                if field not in result:
                    result[field] = f"Not provided"
            
            # Ensure lists are lists
            if not isinstance(result.get("evidence"), list):
                result["evidence"] = [str(result.get("evidence", ""))]
            
            if not isinstance(result.get("remediation_steps"), list):
                result["remediation_steps"] = [str(result.get("remediation_steps", ""))]
            
            # Add confidence if not present
            if "confidence" not in result:
                result["confidence"] = 0.75
            
            return result
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse LLM response as JSON: {e}")
            logger.error(f"Response was: {response}")
            
            # Return a fallback structure
            return {
                "summary": "Analysis parsing failed",
                "root_cause": "Unable to determine - LLM response format error",
                "evidence": [response[:500]],  # Include part of the raw response
                "remediation_steps": [
                    "Review the alert manually",
                    "Check system logs and metrics",
                    "Contact the on-call engineer"
                ],
                "severity_assessment": "Unknown - Manual review required",
                "confidence": 0.0
            }


