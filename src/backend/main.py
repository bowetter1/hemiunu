import asyncio
from pathlib import Path
from typing import Any, Dict, List

import orjson
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import ORJSONResponse
from fastapi.staticfiles import StaticFiles


def _serialize_message(message: Dict[str, Any]) -> str:
    return orjson.dumps(message).decode("utf-8")


class ConnectionManager:
    """Track active websocket connections and broadcast messages."""

    def __init__(self) -> None:
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def send_state_sync(self, websocket: WebSocket) -> None:
        state = await _build_state_payload(self)
        await websocket.send_text(_serialize_message({"type": "state_sync", "data": state}))

    async def broadcast(self, message: Dict[str, Any]) -> None:
        encoded = _serialize_message(message)
        for connection in list(self.active_connections):
            try:
                await connection.send_text(encoded)
            except WebSocketDisconnect:
                self.disconnect(connection)


async def _build_state_payload(manager: ConnectionManager) -> Dict[str, Any]:
    async with state_lock:
        pyramid_snapshot = list(pyramid_blocks)
        stone_snapshot = stone_counter
    return {
        "pyramid": pyramid_snapshot,
        "stats": {
            "total_blocks": len(pyramid_snapshot),
            "online_players": len(manager.active_connections),
        },
        "user_resources": {"stone": stone_snapshot},
    }


app = FastAPI(default_response_class=ORJSONResponse)

static_directory = Path(__file__).resolve().parent / "static"
app.mount("/", StaticFiles(directory=str(static_directory), html=True), name="static")

connection_manager = ConnectionManager()

pyramid_blocks: List[Dict[str, Any]] = [
    {"x": 0, "y": 0, "z": 0, "type": "granite"},
    {"x": 1, "y": 0, "z": 0, "type": "limestone"},
]
stone_counter = 10
state_lock = asyncio.Lock()


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await connection_manager.connect(websocket)
    try:
        await connection_manager.send_state_sync(websocket)
        while True:
            raw_message = await websocket.receive_text()
            try:
                message = orjson.loads(raw_message)
            except ValueError:
                continue

            message_type = message.get("type")
            if message_type == "mine_stone":
                await handle_mine_stone(message, websocket)
            elif message_type == "place_block":
                await handle_place_block(message)
    except WebSocketDisconnect:
        pass
    finally:
        connection_manager.disconnect(websocket)


async def handle_mine_stone(message: Dict[str, Any], websocket: WebSocket) -> None:
    global stone_counter
    async with state_lock:
        stone_counter += 1
        pyramid_snapshot = list(pyramid_blocks)
        stone_snapshot = stone_counter

    state = {
        "pyramid": pyramid_snapshot,
        "stats": {
            "total_blocks": len(pyramid_snapshot),
            "online_players": len(connection_manager.active_connections),
        },
        "user_resources": {"stone": stone_snapshot},
    }

    response = {"type": "state_sync", "data": state}
    await websocket.send_text(_serialize_message(response))


async def handle_place_block(message: Dict[str, Any]) -> None:
    block_data = message.get("data")
    if not isinstance(block_data, dict):
        return

    user_id = message.get("user_id", "unknown")

    async with state_lock:
        pyramid_blocks.append(
            {
                "x": block_data.get("x"),
                "y": block_data.get("y"),
                "z": block_data.get("z"),
                "type": block_data.get("type"),
            }
        )

    block_payload = {
        "type": "block_placed",
        "data": {
            "x": block_data.get("x"),
            "y": block_data.get("y"),
            "z": block_data.get("z"),
            "type": block_data.get("type"),
            "user_id": user_id,
        },
    }
    await connection_manager.broadcast(block_payload)
