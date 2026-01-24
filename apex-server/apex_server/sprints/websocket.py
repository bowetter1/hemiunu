"""WebSocket manager for real-time sprint events"""
import json
import asyncio
from typing import Dict, Set
from fastapi import WebSocket


class SprintWebSocketManager:
    """Manages WebSocket connections per sprint"""

    def __init__(self):
        # Map sprint_id -> set of connected WebSockets
        self._connections: Dict[str, Set[WebSocket]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, sprint_id: str, websocket: WebSocket):
        """Add a WebSocket connection for a sprint"""
        await websocket.accept()
        async with self._lock:
            if sprint_id not in self._connections:
                self._connections[sprint_id] = set()
            self._connections[sprint_id].add(websocket)

    async def disconnect(self, sprint_id: str, websocket: WebSocket):
        """Remove a WebSocket connection"""
        async with self._lock:
            if sprint_id in self._connections:
                self._connections[sprint_id].discard(websocket)
                if not self._connections[sprint_id]:
                    del self._connections[sprint_id]

    async def broadcast(self, sprint_id: str, event_type: str, data: dict):
        """Broadcast an event to all connections for a sprint"""
        message = json.dumps({
            "type": event_type,
            "data": data
        })

        async with self._lock:
            connections = self._connections.get(sprint_id, set()).copy()

        # Send to all connections (outside lock to avoid blocking)
        dead_connections = []
        for websocket in connections:
            try:
                await websocket.send_text(message)
            except Exception:
                dead_connections.append(websocket)

        # Clean up dead connections
        if dead_connections:
            async with self._lock:
                for ws in dead_connections:
                    if sprint_id in self._connections:
                        self._connections[sprint_id].discard(ws)

    def broadcast_sync(self, sprint_id: str, event_type: str, data: dict):
        """Synchronous wrapper for broadcasting (for use in sync code)"""
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # Schedule the coroutine to run in the event loop
                asyncio.ensure_future(self.broadcast(sprint_id, event_type, data))
            else:
                loop.run_until_complete(self.broadcast(sprint_id, event_type, data))
        except RuntimeError:
            # No event loop - create a new one
            asyncio.run(self.broadcast(sprint_id, event_type, data))

    def has_connections(self, sprint_id: str) -> bool:
        """Check if a sprint has any active WebSocket connections"""
        return sprint_id in self._connections and len(self._connections[sprint_id]) > 0


# Global instance
sprint_ws_manager = SprintWebSocketManager()
