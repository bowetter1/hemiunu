"""
Apex Server - AI Design Tool Backend
"""
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from apex_server.config import get_settings
from apex_server.shared.database import init_db

# Import routers
from apex_server.auth.routes import router as auth_router
from apex_server.projects.routes import router as projects_router, set_main_loop

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    print("Starting Apex Server...")
    init_db()
    print("Database initialized")
    # Store main event loop for background thread notifications
    set_main_loop()
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
app.include_router(projects_router, prefix="/api/v1")


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
