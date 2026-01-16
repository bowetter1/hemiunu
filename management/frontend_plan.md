# Frontend Technical Specification (Prepared by Senmut)

## Architecture Overview
- **Stack:** Pure Vanilla JavaScript (ES6+) + HTML5 Canvas
- **Protocol:** WebSocket client connecting to Imhotep's FastAPI backend
- **Pattern:** Event-driven architecture with clear separation between network, state, and rendering layers
- **Philosophy:** No frameworks. No build tools.

## Folder Structure (`src/frontend/`)
```text
src/
└── frontend/
    ├── index.html              # Entry point, canvas container, basic UI
    ├── styles/
    │   └── main.css            # Minimal styling for UI controls
    ├── js/
    │   ├── main.js             # Application bootstrap & initialization
    │   ├── network/
    │   │   ├── websocket.js    # WebSocket client connection manager
    │   │   └── messageHandler.js   # Handles incoming WS messages
    │   ├── state/
    │   │   ├── gameState.js    # Client-side game state (pyramid data)
    │   │   └── eventBus.js     # Internal event bus
    │   ├── rendering/
    │   │   ├── canvas.js       # Canvas management
    │   │   └── pyramid.js      # Isometric rendering logic
    │   └── ui/
    │       ├── controls.js     # Button handlers
    │       └── hud.js          # HUD display
```

## Implementation Phase 1 (Prototype)
1. **Setup:** Create `index.html` and basic JS structure.
2. **Canvas:** Draw a static pyramid.
3. **Network:** Connect to `ws://localhost:8000/ws`.
4. **Interactive:** Make buttons send JSON to backend.

## Worker Delegation Policy
All implementation of the JS modules above should be handled by `codex exec -m gpt-5.1-codex-mini`.
