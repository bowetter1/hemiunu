"""Health check routes."""

from fastapi import APIRouter

from factgrid.api.schemas import HealthResponse
from factgrid.shared import utc_now

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Check API health."""
    return HealthResponse(status="ok", timestamp=utc_now())
