"""Structured logging setup with structlog."""
import logging
import structlog
from src.config import settings
 
 
def setup_logging() -> None:
    """Configure structlog for JSON output in prod, pretty in dev."""
    log_level = getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO)
 
    shared_processors = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
    ]
 
    if settings.ENV == "dev":
        # Pretty colored output locally
        processors = shared_processors + [
            structlog.dev.ConsoleRenderer(colors=True)
        ]
    else:
        # JSON in staging/prod — parseable by Loki
        processors = shared_processors + [
            structlog.processors.dict_tracebacks,
            structlog.processors.JSONRenderer(),
        ]
 
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )
 
 
log = structlog.get_logger()
