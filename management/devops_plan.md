# DevOps & QA Strategy (Prepared by Thoth)

## Deployment Strategy: Unified Service
To optimize for Railway and minimize latency/CORS issues, we will use a **single FastAPI service** that serves:
1.  **WebSocket API:** `/ws`
2.  **Static Frontend:** `/` (serving `src/frontend/index.html` and assets)

## Railway Configuration
*   **Command:** `uvicorn src.backend.main:app --host 0.0.0.0 --port $PORT`
*   **Environment Variables:** `PORT`, `ENV=production`

## Worker Execution Protocol (CRITICAL)
All Managers (Opus) must use the following template when delegating tasks to Workers to ensure cost-efficiency and context isolation:

```bash
codex exec -m gpt-5.1-codex-mini "TASK: [Brief description] | FILE: [Target Path] | INSTRUCTION: [Detailed instruction]"
```

## Folder Structure Update
```text
src/
└── backend/
    └── static/ (Symlink or copy of src/frontend during build)
```

## QA Milestones
1.  **Smoke Test:** Server starts and serves `index.html`.
2.  **Socket Test:** Client connects to `/ws` and receives initial state.
3.  **Concurrency Test:** 5+ tabs open, all seeing the same pyramid.
