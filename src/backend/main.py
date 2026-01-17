import asyncio
import logging
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime, timezone

import orjson
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import ORJSONResponse
from fastapi.staticfiles import StaticFiles

from src.backend.persistence import PersistenceManager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def _serialize_message(message: Dict[str, Any]) -> str:
    return orjson.dumps(message).decode("utf-8")

def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def is_valid_pyramid_placement(
    x: Any, y: Any, z: Any, blocks: List[Dict[str, Any]]
) -> Tuple[bool, Optional[str]]:
    if not all(isinstance(value, int) for value in (x, y, z)):
        return False, "Koordinater måste vara heltal"
    if z < 0:
        return False, "Z-koordinat kan inte vara negativ"
    if z == 0:
        if abs(x) > 100 or abs(y) > 100:
            return False, "Placering utanför basområdet"
        return True, None

    required_support = {
        (x - 1, y - 1, z - 1),
        (x - 1, y + 1, z - 1),
        (x + 1, y - 1, z - 1),
        (x + 1, y + 1, z - 1),
    }
    existing_positions = set()
    for block in blocks:
        if not isinstance(block, dict):
            continue
        bx = block.get("x")
        by = block.get("y")
        bz = block.get("z")
        if isinstance(bx, int) and isinstance(by, int) and isinstance(bz, int):
            existing_positions.add((bx, by, bz))
    if not required_support.issubset(existing_positions):
        return False, "Block måste ha 4 stödblock under sig"
    return True, None


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

    async def send_state_sync(self, websocket: WebSocket, user_id: str) -> None:
        state = await _build_state_payload(self, user_id)
        await websocket.send_text(_serialize_message({"type": "state_sync", "data": state}))

    async def broadcast(self, message: Dict[str, Any]) -> None:
        encoded = _serialize_message(message)
        for connection in list(self.active_connections):
            try:
                await connection.send_text(encoded)
            except WebSocketDisconnect:
                self.disconnect(connection)


async def _build_state_payload(manager: ConnectionManager, user_id: str) -> Dict[str, Any]:
    async with state_lock:
        pyramid_snapshot = list(pyramid_blocks)
        stone_snapshot = user_stones.get(user_id, DEFAULT_STARTING_STONE)
        chat_snapshot = list(chat_messages)
        usernames_snapshot = dict(usernames)
        leaderboard_payload = _generate_leaderboard_payload()
        user_unlocked = user_achievements.get(user_id, [])
    return {
        "pyramid": pyramid_snapshot,
        "stats": {
            "total_blocks": len(pyramid_snapshot),
            "online_players": len(manager.active_connections),
            "leaderboard": leaderboard_payload["data"]["leaderboard"],
        },
        "user_resources": {"stone": stone_snapshot},
        "achievements": user_unlocked,
        "achievements_meta": list(ACHIEVEMENTS.values()),
        "chat": chat_snapshot,
        "usernames": usernames_snapshot,
    }


def _generate_leaderboard_payload() -> Dict[str, Any]:
    leaderboard = []
    for user_id, count in user_blocks_placed.items():
        username = usernames.get(user_id)
        if not username:
             username = f"Player {str(user_id)[:4]}"
        leaderboard.append({"user_id": user_id, "username": username, "blocks_placed": count})
    
    # Sort by blocks placed (desc), then username (asc)
    leaderboard.sort(key=lambda entry: (-entry["blocks_placed"], entry["username"] or ""))
    
    return {
        "type": "leaderboard",
        "data": {"leaderboard": leaderboard[:10]},
    }


app = FastAPI(default_response_class=ORJSONResponse)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


connection_manager = ConnectionManager()
persistence_manager = PersistenceManager()

pyramid_blocks: List[Dict[str, Any]] = []
DEFAULT_STARTING_STONE = 10
MILESTONE_INTERVAL = 100
MAX_CHAT_MESSAGES = 50
user_stones: Dict[str, int] = {}
user_blocks_placed: Dict[str, int] = {}
usernames: Dict[str, str] = {}
user_achievements: Dict[str, List[str]] = {}
user_placed_types: Dict[str, set] = {}
chat_messages: List[Dict[str, Any]] = []
last_mine_time: Dict[str, float] = {}
state_lock = asyncio.Lock()

ACHIEVEMENTS = {
    "first_block": {"id": "first_block", "name": "Första Stenen", "icon": "🪨", "desc": "Placera 1 block"},
    "builder_10": {"id": "builder_10", "name": "Byggare", "icon": "🏗️", "desc": "Placera 10 blocks"},
    "architect_100": {"id": "architect_100", "name": "Arkitekt", "icon": "🏛️", "desc": "Placera 100 blocks"},
    "night_worker": {"id": "night_worker", "name": "Nattarbetare", "icon": "🌙", "desc": "Placera block under natt (20-06)"},
    "artist": {"id": "artist", "name": "Konstnär", "icon": "🎨", "desc": "Använd alla 3 blocktyper"},
}


@app.on_event("startup")
async def startup_event():
    await persistence_manager.init_db()
    
    # Load blocks
    global pyramid_blocks
    loaded_blocks = await persistence_manager.get_all_blocks()
    if loaded_blocks:
        pyramid_blocks = loaded_blocks
    else:
        # Optional: Seed initial blocks if DB is empty, matching previous hardcoded state
        initial_blocks = [
            {"x": 0, "y": 0, "z": 0, "type": "granite"},
            {"x": 1, "y": 0, "z": 0, "type": "limestone"},
        ]
        for block in initial_blocks:
            await persistence_manager.save_block(block)
        pyramid_blocks = initial_blocks
    
    # Load user stones
    global user_stones
    user_stones = await persistence_manager.get_all_user_stones()
    # Load user stats (blocks placed)
    global user_blocks_placed
    user_blocks_placed = await persistence_manager.get_all_user_stats()
    # Load usernames
    global usernames
    usernames = await persistence_manager.get_all_usernames()
    # Load achievements
    global user_achievements
    user_achievements = await persistence_manager.get_all_user_achievements()
    # Load placed types
    global user_placed_types
    user_placed_types = await persistence_manager.get_all_user_placed_types()
    
    logger.info(
        f"Loaded {len(pyramid_blocks)} blocks, {len(user_stones)} user profiles, "
        f"{len(user_blocks_placed)} user stats, "
        f"{len(usernames)} usernames, and achievements for {len(user_achievements)} users."
    )


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await connection_manager.connect(websocket)
    user_id = "unknown"
    try:
        while True:
            raw_message = await websocket.receive_text()
            try:
                message = orjson.loads(raw_message)
            except ValueError:
                continue

            message_type = message.get("type")
            if message_type == "init":
                user_id = message.get("user_id", "unknown")
                await connection_manager.send_state_sync(websocket, user_id)
            elif message_type == "set_username":
                await handle_set_username(message, websocket)
            elif message_type == "mine_stone":
                await handle_mine_stone(message, websocket)
            elif message_type == "place_block":
                await handle_place_block(message, websocket)
            elif message_type == "debug_clear_all":
                await handle_debug_clear(message, websocket)
            elif message_type == "chat_message":
                await handle_chat_message(message)
            elif message_type == "get_leaderboard":
                await handle_get_leaderboard(websocket)
    except WebSocketDisconnect:
        pass
    finally:
        connection_manager.disconnect(websocket)


static_directory = Path(__file__).resolve().parent / "static"
app.mount("/", StaticFiles(directory=str(static_directory), html=True), name="static")


async def handle_mine_stone(message: Dict[str, Any], websocket: WebSocket) -> None:
    user_id = message.get("user_id", "unknown")
    
    current_time = time.time()
    if current_time - last_mine_time.get(user_id, 0) < 1.0:
        await websocket.send_text(_serialize_message({"type": "rate_limited"}))
        return
    last_mine_time[user_id] = current_time

    async with state_lock:
        if user_id not in user_stones:
            user_stones[user_id] = DEFAULT_STARTING_STONE
        user_stones[user_id] += 1
        new_stone_count = user_stones[user_id]
        try:
            await persistence_manager.update_user_stones(user_id, user_stones[user_id])
        except Exception as e:
            logger.error(f"Failed to save user stones: {e}")

    # Send only a small resource update instead of full state sync
    await websocket.send_text(_serialize_message({
        "type": "resource_update",
        "data": {"stone": new_stone_count}
    }))


async def handle_place_block(message: Dict[str, Any], websocket: WebSocket) -> None:
    block_data = message.get("data")
    if not isinstance(block_data, dict):
        return

    user_id = message.get("user_id", "unknown")
    error_payload = None
    new_block = None
    milestone_reached = False
    total_blocks = 0
    username = None

    async with state_lock:
        x = block_data.get("x")
        y = block_data.get("y")
        z = block_data.get("z")
        block_type = block_data.get("type")

        is_valid, error_message = is_valid_pyramid_placement(x, y, z, pyramid_blocks)
        if not is_valid:
            error_payload = {
                "type": "error",
                "data": {
                    "message": error_message or "Ogiltig blockplacering.",
                },
            }
        else:
            current_stones = user_stones.get(user_id, DEFAULT_STARTING_STONE)
            if current_stones < 1:
                return
            if user_id not in user_stones:
                user_stones[user_id] = DEFAULT_STARTING_STONE
            user_stones[user_id] -= 1

            new_block = {
                "x": x,
                "y": y,
                "z": z,
                "type": block_type,
            }
            pyramid_blocks.append(new_block)
            user_blocks_placed[user_id] = user_blocks_placed.get(user_id, 0) + 1
            total_blocks = len(pyramid_blocks)
            milestone_reached = total_blocks % MILESTONE_INTERVAL == 0
            username = usernames.get(user_id)

            try:
                await persistence_manager.update_user_stones(user_id, user_stones[user_id])
                await persistence_manager.save_block(new_block)
                await persistence_manager.update_user_stats(user_id, user_blocks_placed[user_id])
                
                # Achievement Checks
                current_blocks = user_blocks_placed[user_id]
                if user_id not in user_placed_types:
                    user_placed_types[user_id] = set()
                
                if block_type not in user_placed_types[user_id]:
                    user_placed_types[user_id].add(block_type)
                    await persistence_manager.save_user_placed_type(user_id, block_type)

                unlocked_now = []
                user_unlocked_ids = set(user_achievements.get(user_id, []))
                
                # 1. First Block
                if current_blocks >= 1 and "first_block" not in user_unlocked_ids:
                    unlocked_now.append("first_block")
                
                # 2. Builder 10
                if current_blocks >= 10 and "builder_10" not in user_unlocked_ids:
                    unlocked_now.append("builder_10")
                
                # 3. Architect 100
                if current_blocks >= 100 and "architect_100" not in user_unlocked_ids:
                    unlocked_now.append("architect_100")
                
                # 4. Night Worker (20-06)
                current_hour = datetime.now().hour
                if (current_hour >= 20 or current_hour < 6) and "night_worker" not in user_unlocked_ids:
                    unlocked_now.append("night_worker")
                
                # 5. Artist (all 3 types)
                required_types = {"granite", "limestone", "sandstone"}
                if required_types.issubset(user_placed_types[user_id]) and "artist" not in user_unlocked_ids:
                    unlocked_now.append("artist")

                # Save and Notify
                if unlocked_now:
                    if user_id not in user_achievements:
                        user_achievements[user_id] = []
                    
                    for ach_id in unlocked_now:
                        user_achievements[user_id].append(ach_id)
                        await persistence_manager.save_achievement(user_id, ach_id)
                        # Prepare notification
                        ach_def = ACHIEVEMENTS.get(ach_id)
                        if ach_def:
                             await websocket.send_text(_serialize_message({
                                 "type": "achievement_unlocked",
                                 "data": ach_def
                             }))

            except Exception as e:
                logger.error(f"Failed to save block or update stones/achievements: {e}")

    if error_payload:
        await websocket.send_text(_serialize_message(error_payload))
        return
    if not new_block:
        return

    block_payload = {
        "type": "block_placed",
        "data": {
            "block": {
                "x": new_block["x"],
                "y": new_block["y"],
                "z": new_block["z"],
                "type": new_block["type"],
                "user_id": user_id,
                "username": username,
            },
            "total_blocks": total_blocks,
        },
    }
    await connection_manager.broadcast(block_payload)

    # Broadcast leaderboard update
    async with state_lock:
         leaderboard_payload = _generate_leaderboard_payload()
    await connection_manager.broadcast(leaderboard_payload)

    if milestone_reached:
        await connection_manager.broadcast(
            {
                "type": "milestone-event",
                "data": {
                    "total_blocks": total_blocks,
                    "interval": MILESTONE_INTERVAL,
                    "user_id": user_id,
                    "username": username,
                },
            }
        )
    # await connection_manager.send_state_sync(websocket, user_id)  <-- Removed to prevent full state sync on place


async def handle_set_username(message: Dict[str, Any], websocket: WebSocket) -> None:
    user_id = message.get("user_id")
    data = message.get("data")
    if not user_id and isinstance(data, dict):
        user_id = data.get("user_id")
    if not isinstance(user_id, str) or not user_id:
        user_id = "unknown"

    raw_username = message.get("username")
    if raw_username is None and isinstance(data, dict):
        raw_username = data.get("username")
    if not isinstance(raw_username, str):
        await websocket.send_text(
            _serialize_message(
                {"type": "error", "data": {"message": "Invalid username."}}
            )
        )
        return
    username = raw_username.strip()
    if not username:
        await websocket.send_text(
            _serialize_message(
                {"type": "error", "data": {"message": "Invalid username."}}
            )
        )
        return

    async with state_lock:
        usernames[user_id] = username
        try:
            await persistence_manager.save_username(user_id, username)
        except Exception as e:
            logger.error(f"Failed to save username: {e}")

    await connection_manager.broadcast(
        {
            "type": "username_updated",
            "data": {"user_id": user_id, "username": username},
        }
    )
    # Also broadcast leaderboard as username might change ranking display
    async with state_lock:
         leaderboard_payload = _generate_leaderboard_payload()
    await connection_manager.broadcast(leaderboard_payload)

    await connection_manager.send_state_sync(websocket, user_id)


async def handle_debug_clear(message: Dict[str, Any], websocket: WebSocket) -> None:
    admin_key = message.get("admin_key")
    if admin_key is None and isinstance(message.get("data"), dict):
        admin_key = message["data"].get("admin_key")
    expected_key = os.getenv("ADMIN_KEY") or "hemiunu-admin-2026"
    if not isinstance(admin_key, str) or admin_key.strip() != expected_key:
        await websocket.send_text(
            _serialize_message({"type": "error", "data": {"message": "Unauthorized"}})
        )
        return
    user_id = message.get("user_id", "unknown")
    async with state_lock:
        pyramid_blocks.clear()
        usernames_snapshot = dict(usernames)
        cleared_by = {"user_id": user_id, "username": usernames.get(user_id)}
        try:
            await persistence_manager.clear_all_blocks()
        except Exception as e:
            logger.error(f"Failed to clear blocks: {e}")
        
        leaderboard_payload = _generate_leaderboard_payload()

        await connection_manager.broadcast(
            {
                "type": "state_sync",
                "data": {
                    "pyramid": [],
                    "stats": {
                        "total_blocks": 0,
                        "online_players": len(connection_manager.active_connections),
                        "leaderboard": leaderboard_payload["data"]["leaderboard"],
                    },
                    "cleared_by": cleared_by,
                    "usernames": usernames_snapshot,
                },
            }
        )


async def handle_chat_message(message: Dict[str, Any]) -> None:
    user_id = message.get("user_id")
    data = message.get("data")
    if not user_id and isinstance(data, dict):
        user_id = data.get("user_id")
    if not isinstance(user_id, str) or not user_id:
        user_id = "unknown"

    message_text = None
    if isinstance(message.get("message"), str):
        message_text = message.get("message")
    elif isinstance(data, dict):
        if isinstance(data.get("message"), str):
            message_text = data.get("message")
    elif isinstance(data, str):
        message_text = data

    if not isinstance(message_text, str):
        return
    message_text = message_text.strip()
    if not message_text:
        return

    payload = None
    async with state_lock:
        payload = {
            "user_id": user_id,
            "username": usernames.get(user_id),
            "message": message_text,
            "timestamp": _utc_timestamp(),
        }
        chat_messages.append(payload)
        if len(chat_messages) > MAX_CHAT_MESSAGES:
            chat_messages[:] = chat_messages[-MAX_CHAT_MESSAGES:]

    await connection_manager.broadcast({"type": "chat_message", "data": payload})


async def handle_get_leaderboard(websocket: WebSocket) -> None:
    async with state_lock:
        payload = _generate_leaderboard_payload()
    await websocket.send_text(_serialize_message(payload))
