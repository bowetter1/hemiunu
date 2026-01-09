"""API routes."""

from factgrid.api.routes.health import router as health_router
from factgrid.api.routes.articles import router as articles_router
from factgrid.api.routes.pipeline import router as pipeline_router

__all__ = ["health_router", "articles_router", "pipeline_router"]
