"""Tests for products endpoints."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_products_empty(client: AsyncClient):
    """Should return empty list when no products exist."""
    response = await client.get("/api/v1/products")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_create_product(client: AsyncClient):
    """Should create a product and return it."""
    payload = {
        "name": "Test Widget",
        "description": "A great widget",
        "price": 9.99,
        "stock": 100,
    }
    response = await client.post("/api/v1/products", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Widget"
    assert data["price"] == 9.99
    assert "id" in data


@pytest.mark.asyncio
async def test_get_product(client: AsyncClient):
    """Should retrieve a product by ID."""
    # Create first
    create_resp = await client.post(
        "/api/v1/products", json={"name": "Widget Pro", "price": 19.99, "stock": 50}
    )
    product_id = create_resp.json()["id"]

    # Then fetch
    response = await client.get(f"/api/v1/products/{product_id}")
    assert response.status_code == 200
    assert response.json()["id"] == product_id


@pytest.mark.asyncio
async def test_get_product_not_found(client: AsyncClient):
    """Should return 404 for missing product."""
    response = await client.get("/api/v1/products/99999")
    assert response.status_code == 404
