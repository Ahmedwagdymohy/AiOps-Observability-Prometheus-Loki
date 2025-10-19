import httpx
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
from config import settings

logger = logging.getLogger(__name__)


class PrometheusClient:
    """Client for querying Prometheus metrics"""
    
    def __init__(self, base_url: str = None):
        self.base_url = base_url or settings.prometheus_url
        self.timeout = 30.0
    
    async def query_range(
        self,
        query: str,
        start_time: datetime,
        end_time: datetime,
        step: str = "15s"
    ) -> List[Dict[str, Any]]:
        """
        Query Prometheus for a range of time-series data
        
        Args:
            query: PromQL query string
            start_time: Start of time range
            end_time: End of time range
            step: Query resolution step
        
        Returns:
            List of metric results with labels and values
        """
        url = f"{self.base_url}/api/v1/query_range"
        params = {
            "query": query,
            "start": int(start_time.timestamp()),
            "end": int(end_time.timestamp()),
            "step": step
        }
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "success":
                    return data.get("data", {}).get("result", [])
                else:
                    logger.error(f"Prometheus query failed: {data}")
                    return []
        except Exception as e:
            logger.error(f"Error querying Prometheus: {e}")
            return []
    
    async def get_metrics_for_alert(
        self,
        alert_labels: Dict[str, str],
        alert_time: datetime,
        window_minutes: int = None
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Get relevant metrics for an alert based on its labels
        
        Args:
            alert_labels: Labels from the alert
            alert_time: Time when alert fired
            window_minutes: Time window to query (default from settings)
        
        Returns:
            Dictionary of metric queries and their results
        """
        window = window_minutes or settings.time_window_minutes
        start_time = alert_time - timedelta(minutes=window)
        end_time = alert_time + timedelta(minutes=window)
        
        # Build queries based on alert context
        queries = self._build_queries_from_labels(alert_labels)
        
        results = {}
        for query_name, query in queries.items():
            logger.info(f"Executing query: {query_name} - {query}")
            result = await self.query_range(query, start_time, end_time)
            if result:
                results[query_name] = result
        
        return results
    
    def _build_queries_from_labels(self, labels: Dict[str, str]) -> Dict[str, str]:
        """
        Build relevant PromQL queries based on alert labels
        
        Args:
            labels: Alert labels
        
        Returns:
            Dictionary of query names to PromQL queries
        """
        queries = {}
        instance = labels.get("instance", "")
        job = labels.get("job", "")
        component = labels.get("component", "")
        
        # CPU metrics
        if component == "cpu" or "cpu" in labels.get("alertname", "").lower():
            if instance:
                queries["cpu_usage"] = f'100 - (avg by(instance) (irate(node_cpu_seconds_total{{mode="idle",instance="{instance}"}}[5m])) * 100)'
                queries["cpu_by_mode"] = f'irate(node_cpu_seconds_total{{instance="{instance}"}}[5m])'
            else:
                queries["cpu_usage"] = '100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'
        
        # Memory metrics
        if component == "memory" or "memory" in labels.get("alertname", "").lower():
            if instance:
                queries["memory_usage"] = f'(1 - (node_memory_MemAvailable_bytes{{instance="{instance}"}} / node_memory_MemTotal_bytes{{instance="{instance}"}})) * 100'
                queries["memory_details"] = f'node_memory_MemAvailable_bytes{{instance="{instance}"}}'
            else:
                queries["memory_usage"] = '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'
        
        # Disk metrics
        if component == "disk" or "disk" in labels.get("alertname", "").lower():
            if instance:
                queries["disk_usage"] = f'(1 - (node_filesystem_avail_bytes{{instance="{instance}",fstype!="tmpfs"}} / node_filesystem_size_bytes{{instance="{instance}",fstype!="tmpfs"}})) * 100'
            else:
                queries["disk_usage"] = '(1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100'
        
        # Instance availability
        if job:
            queries["instance_up"] = f'up{{job="{job}"}}'
        elif instance:
            queries["instance_up"] = f'up{{instance="{instance}"}}'
        
        # Load average
        if instance:
            queries["load_average"] = f'node_load1{{instance="{instance}"}}'
        
        # Network I/O
        if instance:
            queries["network_receive"] = f'irate(node_network_receive_bytes_total{{instance="{instance}"}}[5m])'
            queries["network_transmit"] = f'irate(node_network_transmit_bytes_total{{instance="{instance}"}}[5m])'
        
        # Disk I/O
        if instance:
            queries["disk_read"] = f'irate(node_disk_read_bytes_total{{instance="{instance}"}}[5m])'
            queries["disk_write"] = f'irate(node_disk_written_bytes_total{{instance="{instance}"}}[5m])'
        
        # If no specific queries were built, add a generic instance query
        if not queries and instance:
            queries["instance_up"] = f'up{{instance="{instance}"}}'
        
        return queries
    
    async def get_current_value(self, query: str) -> Optional[float]:
        """
        Get current value for a PromQL query
        
        Args:
            query: PromQL query
        
        Returns:
            Current value or None
        """
        url = f"{self.base_url}/api/v1/query"
        params = {"query": query}
        
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
                
                if data.get("status") == "success":
                    results = data.get("data", {}).get("result", [])
                    if results:
                        value = results[0].get("value", [None, None])[1]
                        return float(value) if value else None
        except Exception as e:
            logger.error(f"Error getting current value: {e}")
        
        return None


