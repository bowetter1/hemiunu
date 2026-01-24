"""
NEON TRAIL - FastAPI Server
Racing meets Snake - your neon trail is your worst enemy
"""
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import uvicorn

app = FastAPI(title="NEON TRAIL")

# Mount static directories
app.mount("/node_modules", StaticFiles(directory="node_modules"), name="node_modules")
app.mount("/src", StaticFiles(directory="src"), name="src")
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/assets", StaticFiles(directory="assets"), name="assets")

@app.get("/")
async def root():
    return FileResponse("index.html")

@app.get("/health")
async def health():
    return {"status": "ok", "game": "NEON TRAIL"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
