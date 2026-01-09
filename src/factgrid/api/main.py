"""FastAPI application for FactGrid."""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from factgrid.api.routes import health_router, articles_router, pipeline_router

app = FastAPI(
    title="FactGrid API",
    description="AI-driven news platform that separates facts, opinions, and quotes",
    version="0.1.0",
)

# CORS middleware - allow all origins for PoC
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_router)
app.include_router(articles_router)
app.include_router(pipeline_router)

# Static files for web frontend
STATIC_DIR = Path(__file__).parent / "static"
if STATIC_DIR.exists():
    app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

    @app.get("/")
    async def serve_frontend():
        """Serve the web frontend."""
        return FileResponse(str(STATIC_DIR / "index.html"))
