"""
Apex Server - AI Design Tool Backend
"""
import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI

# Configure logging to stdout for Railway
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger("apex")
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
    logger.info("Starting Apex Server...")
    init_db()
    logger.info("Database initialized")
    try:
        from apex_server.auth import firebase as firebase_auth
        if not firebase_auth._ensure_initialized():
            print("Firebase Admin not initialized at startup", flush=True)
    except Exception as e:
        print(f"Firebase Admin startup check failed: {e}", flush=True)
    # Store main event loop for background thread notifications
    set_main_loop()

    # Start Telegram bot if enabled
    if settings.telegram_enabled:
        from apex_server.integrations.telegram import telegram_bot
        await telegram_bot.start()

    # Start Daytona service if enabled
    if settings.daytona_enabled:
        from apex_server.integrations.daytona_service import daytona_service
        await daytona_service.start()

    yield

    # Shutdown
    if settings.daytona_enabled:
        from apex_server.integrations.daytona_service import daytona_service
        await daytona_service.stop()
    if settings.telegram_enabled:
        from apex_server.integrations.telegram import telegram_bot
        await telegram_bot.stop()
    logger.info("Shutting down...")


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
    logger.info("Health check called")
    return {
        "status": "ok",
        "version": "0.1.0",
        "storage": settings.storage_path,
        "telegram_enabled": settings.telegram_enabled,
        "daytona_enabled": settings.daytona_enabled
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
