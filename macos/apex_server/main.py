"""
Apex Server - Multi-tenant AI Team SaaS
"""
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from apex_server.config import get_settings, get_cors_origins, validate_settings
from apex_server.shared.database import init_db

# Import routers
from apex_server.auth.routes import router as auth_router
from apex_server.tenants.routes import router as tenants_router
from apex_server.sprints.routes import router as sprints_router

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("Starting Apex Server...")
    validate_settings()
    init_db()
    logger.info("Database initialized")
    yield
    # Shutdown
    logger.info("Shutting down...")


app = FastAPI(
    title="Apex Server",
    description="Multi-tenant SaaS for AI development teams",
    version="0.1.0",
    lifespan=lifespan
)

# CORS - configured via CORS_ORIGINS environment variable
cors_origins = get_cors_origins()
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True if cors_origins != ["*"] else False,  # Never allow credentials with wildcard
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# Include routers
app.include_router(auth_router, prefix="/api/v1")
app.include_router(tenants_router, prefix="/api/v1")
app.include_router(sprints_router, prefix="/api/v1")


@app.get("/health")
def health():
    """Health check endpoint"""
    return {
        "status": "ok",
        "version": "0.1.0",
        "storage": settings.storage_path
    }


# Static files
static_dir = Path(__file__).parent / "web" / "static"
if static_dir.exists():
    app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/")
def root():
    """Serve the dashboard"""
    index_file = static_dir / "index.html"
    if index_file.exists():
        return FileResponse(index_file)
    return {
        "name": "Apex Server",
        "docs": "/docs",
        "health": "/health"
    }
