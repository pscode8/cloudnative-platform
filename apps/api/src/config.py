"""App configuration — all values from environment variables."""
from pydantic_settings import BaseSettings, SettingsConfigDict
 
 
class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
 
    # App
    ENV: str = "dev"
    VERSION: str = "0.1.0"
    DEBUG: bool = False
    LOG_LEVEL: str = "INFO"
 
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://appuser:apppass@localhost:5432/appdb"
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20
 
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
 
    # Kafka
    KAFKA_BOOTSTRAP_SERVERS: str = "localhost:9092"
    KAFKA_TOPIC_ORDERS: str = "orders"
    KAFKA_TOPIC_EVENTS: str = "events"
 
    # CORS
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000"]
 
    # Observability
    OTEL_EXPORTER_OTLP_ENDPOINT: str = "http://localhost:4317"
 
 
settings = Settings()
