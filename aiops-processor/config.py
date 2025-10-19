import os
from typing import Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Service URLs
    prometheus_url: str = os.getenv("PROMETHEUS_URL", "http://prometheus:9090")
    loki_url: str = os.getenv("LOKI_URL", "http://loki:3100")
    
    # Huawei Cloud DeepSeek API Configuration (Competition)
    # API Endpoint for Huawei Cloud ModelArts
    # Note: Try both URL formats - with or without dash in "ap-southeast"
    huawei_api_url: str = os.getenv(
        "HUAWEI_API_URL", 
        "https://pangu.ap-southeast-1.myhuaweicloud.com/api/v2/chat/completions"
    )
    # API Key (X-Auth-Token) - Replace with your competition API key
    huawei_api_key: str = os.getenv("HUAWEI_API_KEY", "")
    
    # Model Selection - Choose which Huawei Cloud model to use
    # Options: 
    #   - "deepseek-r1-distil-qwen-32b_raziqt" (More powerful, better for complex tasks)
    #   - "distill-llama-8b_46e6iu" (Faster, lighter)
    huawei_model_name: str = os.getenv(
        "HUAWEI_MODEL_NAME", 
        "deepseek-r1-distil-qwen-32b_raziqt"
    )
    
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
    # Increased timeout for large Huawei models (can be slow)
    llm_timeout: int = int(os.getenv("LLM_TIMEOUT", "180"))
    llm_max_retries: int = int(os.getenv("LLM_MAX_RETRIES", "3"))
    # Temperature: 0.1 for precise answers, 0.7-0.8 for creative responses
    llm_temperature: float = float(os.getenv("LLM_TEMPERATURE", "0.3"))
    llm_max_tokens: int = int(os.getenv("LLM_MAX_TOKENS", "2000"))
    llm_top_p: float = float(os.getenv("LLM_TOP_P", "0.9"))
    llm_top_k: int = int(os.getenv("LLM_TOP_K", "40"))
    
    # Backward compatibility (deprecated, but kept for reference)
    deepseek_api_key: str = os.getenv("DEEPSEEK_API_KEY", "")
    deepseek_api_url: str = os.getenv("DEEPSEEK_API_URL", "")
    deepseek_model: str = os.getenv("DEEPSEEK_MODEL", "")
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
