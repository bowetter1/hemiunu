"""
GRAVSHIFT - Racing Where Gravity Is Just A Suggestion
FastAPI server for serving the game
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn
import os

app = FastAPI(title="GRAVSHIFT")

# Mount directories for game assets
app.mount("/node_modules", StaticFiles(directory="node_modules"), name="node_modules")
app.mount("/assets", StaticFiles(directory="assets"), name="assets")
app.mount("/static", StaticFiles(directory="static"), name="static")

# Serve both src/ and static/src/ from /src/ path
from starlette.routing import Mount
from starlette.staticfiles import StaticFiles as StarletteStatic
import os

# Custom handler to check both directories
from fastapi.responses import Response
from fastapi import HTTPException

@app.get("/src/{file_path:path}")
async def serve_src(file_path: str):
    """Serve files from src/ or static/src/"""
    # Try src/ first
    src_path = f"src/{file_path}"
    if os.path.isfile(src_path):
        return FileResponse(src_path)
    # Try static/src/
    static_src_path = f"static/src/{file_path}"
    if os.path.isfile(static_src_path):
        return FileResponse(static_src_path)
    raise HTTPException(status_code=404, detail=f"File not found: {file_path}")

@app.get("/")
async def serve_game():
    """Serve the main game HTML"""
    return FileResponse("index.html")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "game": "GRAVSHIFT"}

if __name__ == "__main__":
    # Ensure asset directories exist
    for dir_path in ["assets/images", "assets/audio", "assets/fonts", "static/css"]:
        os.makedirs(dir_path, exist_ok=True)
    
    uvicorn.run(app, host="0.0.0.0", port=8000)
