"""Products router — sample CRUD endpoints."""

from typing import Annotated

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.database import get_db

log = structlog.get_logger()
router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────
class ProductCreate(BaseModel):
    name: str
    description: str | None = None
    price: float
    stock: int = 0


class ProductResponse(BaseModel):
    id: int
    name: str
    description: str | None
    price: float
    stock: int

    model_config = {"from_attributes": True}


# ── Routes ───────────────────────────────────────────────────────
@router.get("/products", response_model=list[ProductResponse])
async def list_products(
    db: Annotated[AsyncSession, Depends(get_db)],
    skip: int = 0,
    limit: int = 20,
):
    """List all products with pagination."""
    log.info("products.list", skip=skip, limit=limit)
    # Import model here to avoid circular imports
    from src.models.product import Product

    result = await db.execute(select(Product).offset(skip).limit(limit))
    return result.scalars().all()


@router.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Create a new product."""
    from src.models.product import Product

    product = Product(**payload.model_dump())
    db.add(product)
    await db.flush()
    await db.refresh(product)
    log.info("products.created", product_id=product.id, name=product.name)
    return product


@router.get("/products/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
):
    """Get a single product by ID."""
    from src.models.product import Product

    product = await db.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
