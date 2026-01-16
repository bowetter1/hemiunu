# Vision: Hemiunu's Infinite Pyramid

## Core Concept
A persistent, real-time Massive Multiplayer Incremental Game (MMIG).
Every player in the world contributes to building the *same* pyramid.

## User Experience
1. **The View:** When a user opens the site, they see a massive pyramid.
2. **The Action:** Users can "Mine Stone" (click button) or "Place Block" (spend stone).
3. **The Sync:** As soon as *anyone* places a block, the pyramid grows for *everyone* instantly.
4. **The Scale:** The pyramid has no height limit. It just gets wider and taller.

## Architecture Guidelines
*   **Backend:** Python FastAPI. Must handle high-concurrency WebSockets (using `uvicorn`).
*   **State:** In-memory state for prototype, later Redis/Postgres.
*   **Frontend:** No framework hell. Pure Vanilla JS. HTML5 Canvas for the pyramid rendering to support thousands of blocks efficiently.
*   **Deployment:** Containerized (Docker) on Railway.

## Current Phase: Prototype 1
*   Goal: A working "Hello World" where two users can click a button and see a counter go up on both screens.
