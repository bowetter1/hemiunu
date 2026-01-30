"""WebSocket manager for real-time project updates"""
import json
import asyncio
from typing import Dict, Set
from fastapi import WebSocket, WebSocketDisconnect

from apex_server.config import get_settings


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


async def _telegram_notify(project_id: str, message: str, preview_url: str = None):
    """Send a Telegram notification for a project event (if enabled)."""
    settings = get_settings()
    if not settings.telegram_enabled:
        return
    try:
        from apex_server.integrations.telegram import telegram_bot
        await telegram_bot.notify_project_event(project_id, message, preview_url)
    except Exception as e:
        print(f"[TELEGRAM] Notification error: {e}", flush=True)


async def _telegram_notify_clarification(project_id: str, questions: list):
    """Send Telegram clarification questions with inline buttons (if enabled)."""
    settings = get_settings()
    if not settings.telegram_enabled:
        return
    try:
        from apex_server.integrations.telegram import telegram_bot
        await telegram_bot.notify_clarification(project_id, questions)
    except Exception as e:
        print(f"[TELEGRAM] Clarification notification error: {e}", flush=True)


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
    await _telegram_notify(project_id, "🎨 Moodboard klar! Designförslag redo att granska.")


async def notify_layouts_ready(project_id: str, layouts: list):
    """Notify clients that layouts are ready"""
    await manager.broadcast(str(project_id), "layouts_ready", {
        "count": len(layouts)
    })
    await _telegram_notify(
        project_id,
        f"📐 Layouts klara! {len(layouts)} alternativ att välja mellan.",
    )


async def notify_page_updated(project_id: str, page_id: str):
    """Notify clients that a page was updated"""
    await manager.broadcast(str(project_id), "page_updated", {
        "page_id": page_id
    })
    await _telegram_notify(project_id, "✅ Sidan uppdaterad!")


async def notify_error(project_id: str, message: str):
    """Notify clients of an error"""
    await manager.broadcast(str(project_id), "error", {
        "message": message
    })
    await _telegram_notify(project_id, f"❌ Fel: {message[:200]}")


async def notify_research_ready(project_id: str, research_data: dict):
    """Notify clients that research is complete and ready for review"""
    print(f"[WS] Sending research_ready to {project_id}", flush=True)
    await manager.broadcast(str(project_id), "research_ready", research_data)
    await _telegram_notify(project_id, "🔍 Research klar! Granska varumärkesfärger och inspiration.")


async def notify_clarification_needed(project_id: str, questions: list):
    """Notify clients that clarification is needed (3 questions)"""
    print(f"[WS] Sending clarification_needed ({len(questions)} questions) to {project_id}", flush=True)
    await manager.broadcast(str(project_id), "clarification_needed", {
        "questions": questions
    })
    await _telegram_notify_clarification(project_id, questions)
