"""CloudNative Platform — FastAPI application."""
from contextlib import asynccontextmanager
 
import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
 
from src.config import settings
from src.database import engine, Base
from src.logger import setup_logging, log
from src.routers import health, products
 
# Setup logging first
setup_logging()
 
 
def setup_tracing() -> None:
    """Configure OpenTelemetry tracing — sends to Tempo via OTLP."""
    resource = Resource.create({
        "service.name": "cloudnative-api",
        "service.version": settings.VERSION,
        "deployment.environment": settings.ENV,
    })
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=settings.OTEL_EXPORTER_OTLP_ENDPOINT)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
 
 
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle."""
    log.info("api.startup", env=settings.ENV, version=settings.VERSION)
    # Create tables (use Alembic migrations in prod)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    log.info("api.shutdown")
    await engine.dispose()
 
 
# Setup tracing before app creation
setup_tracing()
 
app = FastAPI(
    title="CloudNative Platform API",
    version=settings.VERSION,
    lifespan=lifespan,
    docs_url="/docs" if settings.ENV != "prod" else None,
    redoc_url="/redoc" if settings.ENV != "prod" else None,
)
 
# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
 
# Prometheus metrics at /metrics
Instrumentator().instrument(app).expose(app)
 
# OpenTelemetry auto-instrumentation
FastAPIInstrumentor.instrument_app(app)
 
# Routers
app.include_router(health.router, tags=["health"])
app.include_router(products.router, prefix="/api/v1", tags=["products"])
