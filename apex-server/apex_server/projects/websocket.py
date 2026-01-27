"""WebSocket manager for real-time project updates"""
import json
import asyncio
from typing import Dict, Set
from fastapi import WebSocket, WebSocketDisconnect


class ConnectionManager:
    """Manages WebSocket connections per project"""

    def __init__(self):
        # project_id -> set of WebSocket connections
        self.active_connections: Dict[str, Set[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, project_id: str):
        """Accept a new WebSocket connection for a project"""
        await websocket.accept()
        if project_id not in self.active_connections:
            self.active_connections[project_id] = set()
        self.active_connections[project_id].add(websocket)
        print(f"WebSocket connected for project {project_id}")

    def disconnect(self, websocket: WebSocket, project_id: str):
        """Remove a WebSocket connection"""
        if project_id in self.active_connections:
            self.active_connections[project_id].discard(websocket)
            if not self.active_connections[project_id]:
                del self.active_connections[project_id]
        print(f"WebSocket disconnected for project {project_id}")

    async def broadcast(self, project_id: str, event: str, data: dict = None):
        """Broadcast an event to all connections for a project"""
        if project_id not in self.active_connections:
            return

        message = json.dumps({
            "event": event,
            "data": data or {}
        })

        # Send to all connected clients
        dead_connections = set()
        for websocket in self.active_connections[project_id]:
            try:
                await websocket.send_text(message)
            except Exception:
                dead_connections.add(websocket)

        # Clean up dead connections
        for ws in dead_connections:
            self.active_connections[project_id].discard(ws)


# Global manager instance
manager = ConnectionManager()


async def notify_status_change(project_id: str, status: str, data: dict = None):
    """Notify all clients that project status changed"""
    await manager.broadcast(str(project_id), "status_changed", {
        "status": status,
        **(data or {})
    })


async def notify_moodboard_ready(project_id: str, moodboards: list):
    """Notify clients that moodboards are ready"""
    await manager.broadcast(str(project_id), "moodboard_ready", {
        "moodboards": moodboards
    })


async def notify_layouts_ready(project_id: str, layouts: list):
    """Notify clients that layouts are ready"""
    await manager.broadcast(str(project_id), "layouts_ready", {
        "count": len(layouts)
    })


async def notify_page_updated(project_id: str, page_id: str):
    """Notify clients that a page was updated"""
    await manager.broadcast(str(project_id), "page_updated", {
        "page_id": page_id
    })


async def notify_error(project_id: str, message: str):
    """Notify clients of an error"""
    await manager.broadcast(str(project_id), "error", {
        "message": message
    })


async def notify_clarification_needed(project_id: str, questions: list):
    """Notify clients that clarification is needed (3 questions)"""
    print(f"[WS] Sending clarification_needed ({len(questions)} questions) to {project_id}", flush=True)
    await manager.broadcast(str(project_id), "clarification_needed", {
        "questions": questions
    })
