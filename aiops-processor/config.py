import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Service URLs
    prometheus_url: str = os.getenv("PROMETHEUS_URL", "http://prometheus:9090")
    loki_url: str = os.getenv("LOKI_URL", "http://loki:3100")
    ollama_url: str = os.getenv("OLLAMA_URL", "http://ollama:11434")
    
    # DeepSeek API Configuration
    deepseek_api_key: str = os.getenv("DEEPSEEK_API_KEY", "")
    deepseek_api_url: str = os.getenv("DEEPSEEK_API_URL", "https://api.deepseek.com/v1/chat/completions")
    deepseek_model: str = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")
    
    # Analysis Configuration
    time_window_minutes: int = int(os.getenv("TIME_WINDOW_MINUTES", "15"))
    max_log_lines: int = int(os.getenv("MAX_LOG_LINES", "500"))
    max_metrics_points: int = int(os.getenv("MAX_METRICS_POINTS", "100"))
    
    # Notification Configuration
    slack_webhook_url: Optional[str] = os.getenv("SLACK_WEBHOOK_URL", None)
    generic_webhook_url: Optional[str] = os.getenv("GENERIC_WEBHOOK_URL", None)
    
    # API Configuration
    api_host: str = os.getenv("API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("API_PORT", "8000"))
    
    # LLM Configuration
    llm_timeout: int = int(os.getenv("LLM_TIMEOUT", "120"))
    llm_max_retries: int = int(os.getenv("LLM_MAX_RETRIES", "3"))
    llm_temperature: float = float(os.getenv("LLM_TEMPERATURE", "0.7"))
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()


