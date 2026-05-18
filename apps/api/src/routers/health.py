"""Health check endpoints for Kubernetes probes."""
from fastapi import APIRouter, status
from sqlalchemy import text
 
from src.database import AsyncSessionLocal
 
router = APIRouter()
 
 
@router.get("/healthz", status_code=status.HTTP_200_OK)
async def liveness():
    """
    Liveness probe — is the process alive?
    K8s restarts the pod if this fails.
    """
    return {"status": "ok"}
 
 
@router.get("/readyz", status_code=status.HTTP_200_OK)
async def readiness():
    """
    Readiness probe — can we serve traffic?
    K8s stops sending requests if this fails.
    """
    async with AsyncSessionLocal() as session:
        await session.execute(text("SELECT 1"))
    return {"status": "ready", "database": "connected"}
