# PROJECT CONTEXT

## Vision
Build a simple, functional todo list application with SQLite persistence. Users can add tasks, mark them complete, and delete them. Clean, minimal UI - nothing fancy, just works.

## Sprint Goals
- SQLite database for persistent storage
- Full CRUD operations (Create, Read, Update, Delete)
- Single-page UI with real-time updates
- Deploy to Railway

## NEEDS (blockers)
| From | Need | From who | Status |
|------|------|----------|--------|

## Environment (DevOps)
- python: 3.14.2
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- sqlalchemy: 2.0.23
- jinja2: 3.1.2
- httpx: 0.27.0
- status: ✅ OK (all tools working)

## Tech Stack (Architect)
- framework: fastapi
- db: sqlite
- orm: none (raw SQL with sqlite3)
- templates: jinja2
- See PLAN.md for full API contract

## Design System (AD)
- primary: #4F46E5 (Indigo 600)
- background: #F3F4F6 (Gray 100)
- text: #1F2937 (Gray 800)
- font: System UI (-apple-system, BlinkMacSystemFont...)
- spacing: 4px base
- See DESIGN.md for details

## Security Audit (Security)
- status: ✅ SECURE (Low severity findings only)
- report: SECURITY_AUDIT.md
- last_check: 2026-01-21

## API Endpoints (Backend)
- GET /todos → List all todos `[{"id": 1, "title": "...", "completed": false}]`
- POST /todos {title} → Create todo `{"id": 1, "title": "...", "completed": false}`
- PUT /todos/{id} → Toggle completed status `{"id": 1, ..., "completed": true}`
- DELETE /todos/{id} → Delete todo
- See main.py for full API

## Frontend
- pages: templates/index.html
- scripts: static/js/main.js
- styles: static/css/style.css
- features: Add todo, List todos, Toggle completion, Delete todo, Responsive design

