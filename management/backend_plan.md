# Backend Technical Specification (Prepared by Imhotep)

## Architecture Overview
- **Framework:** FastAPI (Async)
- **Protocol:** WebSockets for real-time bi-directional events.
- **Pattern:** Broadcaster/Subscriber model. Every "place_block" event is broadcast to all connected clients.

## Folder Structure (`src/backend/`)
```text
src/
└── backend/
    ├── main.py             # Entry point, app initialization
    ├── config.py           # Environment variables & settings
    ├── api/
    │   └── websockets.py   # WebSocket route handlers
    ├── core/
    │   ├── game_state.py   # The "Pyramid" logic (Global State)
    │   ├── connection.py   # Manages active WebSocket connections
    │   └── events.py       # Event definitions (BlockPlaced, UserJoined)
    ├── models/
    │   └── schemas.py      # Pydantic models for client messages
    └── requirements.txt
```

## Dependencies
- `fastapi`
- `uvicorn[standard]`
- `pydantic`
- `orjson` (Fast JSON processing)
- `python-dotenv`

## Implementation Phase 1
1. **Setup:** Initialize `src/backend` and `requirements.txt`.
2. **Core:** Implement `ConnectionManager` to handle connect/disconnect.
3. **Game Loop:** Implement simple in-memory counter/array for the pyramid.
4. **API:** Expose `ws://` endpoint.
