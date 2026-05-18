"""Tests for health check endpoints."""
import pytest
from httpx import AsyncClient
 
 
@pytest.mark.asyncio
async def test_liveness(client: AsyncClient):
    """Liveness probe should always return 200."""
    response = await client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
 
 
@pytest.mark.asyncio
async def test_readiness(client: AsyncClient):
    """Readiness probe should return 200 when DB is up."""
    response = await client.get("/readyz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ready"
 
 
@pytest.mark.asyncio
async def test_docs_available_in_dev(client: AsyncClient):
    """Swagger docs should be accessible in dev mode."""
    response = await client.get("/docs")
    assert response.status_code == 200
 
 
@pytest.mark.asyncio
async def test_metrics_endpoint(client: AsyncClient):
    """Prometheus metrics endpoint should be available."""
    response = await client.get("/metrics")
    assert response.status_code == 200
    assert b"http_requests_total" in response.content
