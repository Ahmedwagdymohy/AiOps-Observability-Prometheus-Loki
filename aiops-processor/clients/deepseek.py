import httpx
import logging
import json
from typing import Dict, Any, Optional
from tenacity import retry, stop_after_attempt, wait_exponential
from config import settings

logger = logging.getLogger(__name__)


class DeepSeekClient:
    """
    Client for Huawei Cloud DeepSeek API
    
    This client implements the Huawei Cloud ModelArts API for DeepSeek models
    as specified in the competition documentation.
    
    Supported Models:
    - deepseek-r1-distil-qwen-32b_raziqt (32B - More powerful)
    - distill-llama-8b_46e6iu (8B - Faster)
    """
    
    def __init__(self, api_key: str = None, api_url: str = None, model: str = None):
        """
        Initialize the Huawei Cloud DeepSeek client
        
        Args:
            api_key: Huawei API key (X-Auth-Token)
            api_url: Huawei API endpoint URL
            model: Model name to use
        """
        self.api_key = api_key or settings.huawei_api_key
        self.api_url = api_url or settings.huawei_api_url
        self.model = model or settings.huawei_model_name
        self.timeout = settings.llm_timeout
        self.temperature = settings.llm_temperature
        self.max_tokens = settings.llm_max_tokens
        self.top_p = settings.llm_top_p
        self.top_k = settings.llm_top_k
        
        # Validate configuration
        if not self.api_key:
            logger.error("Huawei API key is not configured! Please set HUAWEI_API_KEY environment variable.")
        else:
            logger.info(f"DeepSeek client initialized with model: {self.model}")
            logger.info(f"API endpoint: {self.api_url}")
            logger.info(f"Timeout: {self.timeout}s, Temperature: {self.temperature}")
    
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
        Analyze an alert using the Huawei Cloud LLM
        
        Args:
            alert_context: Alert details (labels, annotations, etc.)
            metrics_data: Prometheus metrics related to the alert
            logs_data: Loki logs related to the alert
        
        Returns:
            Analysis result as a dictionary
        """
        prompt = self._build_analysis_prompt(alert_context, metrics_data, logs_data)
        system_prompt = "You are an expert Site Reliability Engineer (SRE) and DevOps engineer specializing in incident analysis and root cause determination. Always respond with valid JSON."
        
        try:
            response = await self._call_api(prompt, system_prompt)
            return self._parse_analysis_response(response)
        except Exception as e:
            logger.error(f"Error analyzing alert with Huawei Cloud LLM: {e}")
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
    
    async def _call_api(self, prompt: str, system_prompt: str = None) -> str:
        """
        Call the Huawei Cloud DeepSeek API
        
        This implements the Huawei Cloud ModelArts API specification:
        - Endpoint: https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions
        - Authentication: Bearer token (Authorization header)
        - Request format: OpenAI-compatible chat completion
        
        Args:
            prompt: The user prompt to send
            system_prompt: Optional system prompt to set behavior
        
        Returns:
            API response text
        """
        if not self.api_key:
            raise ValueError("Huawei API key is not configured. Please set HUAWEI_API_KEY environment variable.")
        
        # Build headers according to Huawei Cloud API specification
        # Use Bearer token authentication (tested and working)
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        
        # Build messages array
        messages = []
        if system_prompt:
            messages.append({
                "role": "system",
                "content": system_prompt
            })
        messages.append({
            "role": "user",
            "content": prompt
        })
        
        # Build payload according to Huawei Cloud API specification
        payload = {
            "model": self.model,  # e.g., "deepseek-r1-distil-qwen-32b_raziqt"
            "messages": messages,
            "max_tokens": self.max_tokens,
            "temperature": self.temperature,
            "top_p": self.top_p,
            "top_k": self.top_k,
            "stream": False  # Non-streaming mode for simplicity
        }
        
        logger.info(f"Calling Huawei Cloud API with model: {self.model}")
        logger.info(f"Request parameters - Temperature: {self.temperature}, Max Tokens: {self.max_tokens}")
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    self.api_url,
                    headers=headers,
                    json=payload
                )
                response.raise_for_status()
                
                # Parse response according to OpenAI-compatible format
                data = response.json()
                
                # Extract content from response
                # Response format: data['choices'][0]['message']['content']
                if "choices" in data and len(data["choices"]) > 0:
                    content = data["choices"][0]["message"]["content"]
                    logger.info(f"Successfully received response from Huawei Cloud API ({len(content)} characters)")
                    
                    # Log token usage if available
                    if "usage" in data:
                        usage = data["usage"]
                        logger.info(f"Token usage - Prompt: {usage.get('prompt_tokens')}, "
                                  f"Completion: {usage.get('completion_tokens')}, "
                                  f"Total: {usage.get('total_tokens')}")
                    
                    return content
                else:
                    logger.error(f"Unexpected response format: {data}")
                    raise ValueError("Invalid response format from Huawei Cloud API")
                    
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error from Huawei Cloud API: {e.response.status_code}")
            logger.error(f"Response body: {e.response.text}")
            
            if e.response.status_code == 401:
                raise ValueError("Authentication failed. Please check your HUAWEI_API_KEY.")
            elif e.response.status_code == 429:
                raise ValueError("Rate limit exceeded. Please wait before retrying.")
            elif e.response.status_code == 503:
                raise ValueError("Huawei Cloud API service unavailable. Please try again later.")
            else:
                raise
        except httpx.TimeoutException:
            logger.error(f"Request timed out after {self.timeout} seconds")
            logger.warning("Tip: The model might be slow. Consider using distill-llama-8b_46e6iu for faster responses.")
            raise
        except Exception as e:
            logger.error(f"Unexpected error calling Huawei Cloud API: {e}")
            raise
    
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


