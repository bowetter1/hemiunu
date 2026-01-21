"""
Apex Server - Multi-tenant AI Team SaaS
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from apex_server.config import get_settings
from apex_server.shared.database import init_db

# Import routers
from apex_server.auth.routes import router as auth_router
from apex_server.tenants.routes import router as tenants_router
from apex_server.sprints.routes import router as sprints_router

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    print("Starting Apex Server...")
    init_db()
    print("Database initialized")
    yield
    # Shutdown
    print("Shutting down...")


app = FastAPI(
    title="Apex Server",
    description="Multi-tenant SaaS for AI development teams",
    version="0.1.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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


@app.get("/")
def root():
    """Root endpoint"""
    return {
        "name": "Apex Server",
        "docs": "/docs",
        "health": "/health"
    }
