import httpx
import logging
from typing import List, Dict, Any
from datetime import datetime, timedelta
from config import settings

logger = logging.getLogger(__name__)


class LokiClient:
    """Client for querying Loki logs"""
    
    def __init__(self, base_url: str = None):
        self.base_url = base_url or settings.loki_url
        self.timeout = 30.0
    
    async def query_range(
        self,
        query: str,
        start_time: datetime,
        end_time: datetime,
        limit: int = None
    ) -> List[Dict[str, Any]]:
        """
        Query Loki for logs in a time range
        
        Args:
            query: LogQL query string
            start_time: Start of time range
            end_time: End of time range
            limit: Maximum number of log lines to return
        
        Returns:
            List of log entries
        """
        url = f"{self.base_url}/loki/api/v1/query_range"
        limit = limit or settings.max_log_lines
        
        params = {
            "query": query,
            "start": int(start_time.timestamp() * 1e9),  # Loki uses nanoseconds
            "end": int(end_time.timestamp() * 1e9),
            "limit": limit,
            "direction": "backward"  # Get most recent first
        }
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "success":
                    return self._parse_loki_response(data)
                else:
                    logger.error(f"Loki query failed: {data}")
                    return []
        except Exception as e:
            logger.error(f"Error querying Loki: {e}")
            return []
    
    def _parse_loki_response(self, response: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Parse Loki response into a list of log entries
        
        Args:
            response: Raw Loki API response
        
        Returns:
            List of parsed log entries
        """
        logs = []
        result = response.get("data", {}).get("result", [])
        
        for stream in result:
            stream_labels = stream.get("stream", {})
            values = stream.get("values", [])
            
            for timestamp_ns, log_line in values:
                logs.append({
                    "timestamp": datetime.fromtimestamp(int(timestamp_ns) / 1e9).isoformat(),
                    "line": log_line,
                    "labels": stream_labels
                })
        
        return logs
    
    async def get_logs_for_alert(
        self,
        alert_labels: Dict[str, str],
        alert_time: datetime,
        window_minutes: int = None
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Get relevant logs for an alert based on its labels
        
        Args:
            alert_labels: Labels from the alert
            alert_time: Time when alert fired
            window_minutes: Time window to query (default from settings)
        
        Returns:
            Dictionary of log queries and their results
        """
        window = window_minutes or settings.time_window_minutes
        start_time = alert_time - timedelta(minutes=window)
        end_time = alert_time + timedelta(minutes=window)
        
        # Build queries based on alert context
        queries = self._build_queries_from_labels(alert_labels)
        
        results = {}
        for query_name, query in queries.items():
            logger.info(f"Executing log query: {query_name} - {query}")
            result = await self.query_range(query, start_time, end_time)
            if result:
                results[query_name] = result
        
        return results
    
    def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
        """
        Build relevant LogQL queries based on alert labels
        
        Args:
            labels: Alert labels
        
        Returns:
            Dictionary of query names to LogQL queries
        """
        queries = {}
        service = labels.get("service", "")
        job = labels.get("job", "")
        instance = labels.get("instance", "")
        
        # Service-specific logs
        if service:
            # All logs for the service
            queries["service_all_logs"] = f'{{service="{service}"}}'
            
            # Error logs
            queries["service_errors"] = f'{{service="{service}"}} |~ "(?i)(error|exception|fatal|critical)"'
            
            # Warning logs
            queries["service_warnings"] = f'{{service="{service}"}} |~ "(?i)(warn|warning)"'
        
        # Job-specific logs
        if job:
            queries["job_logs"] = f'{{job="{job}"}}'
            queries["job_errors"] = f'{{job="{job}"}} |~ "(?i)(error|exception|fatal)"'
        
        # Container-specific logs (from Docker)
        if service:
            queries["container_logs"] = f'{{container=~".*{service}.*"}}'
            queries["container_errors"] = f'{{container=~".*{service}.*"}} |~ "(?i)(error|exception|failed|fatal)"'
        
        # If we have instance info, try to get system logs
        if instance:
            instance_host = instance.split(":")[0]
            queries["instance_logs"] = f'{{instance=~".*{instance_host}.*"}}'
        
        # Generic error patterns if no specific service
        if not queries:
            queries["all_errors"] = '{job=~".+"} |~ "(?i)(error|exception|fatal|critical)"'
            queries["all_warnings"] = '{job=~".+"} |~ "(?i)(warn|warning)"'
        
        return queries
    
    async def search_logs_by_pattern(
        self,
        pattern: str,
        start_time: datetime,
        end_time: datetime,
        labels: Dict[str, str] = None,
        limit: int = None
    ) -> List[Dict[str, Any]]:
        """
        Search logs by a specific pattern with optional label filters
        
        Args:
            pattern: Regex pattern to search for
            start_time: Start of time range
            end_time: End of time range
            labels: Optional label filters
            limit: Maximum number of results
        
        Returns:
            List of matching log entries
        """
        # Build label selector
        label_selector = ""
        if labels:
            label_pairs = [f'{k}="{v}"' for k, v in labels.items()]
            label_selector = "{" + ",".join(label_pairs) + "}"
        else:
            label_selector = '{job=~".+"}'
        
        query = f'{label_selector} |~ "{pattern}"'
        
        return await self.query_range(query, start_time, end_time, limit)


