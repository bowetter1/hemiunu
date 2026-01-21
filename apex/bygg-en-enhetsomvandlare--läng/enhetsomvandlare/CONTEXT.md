# PROJECT CONTEXT

## NEEDS (blockers)
| Från | Behöver | Från vem | Status |
|------|---------|----------|--------|

## Environment (DevOps)
- python: 3.14.2
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- jinja2: 3.1.2
- httpx: 0.27.0
- database: none (pure calculations)
- status: OK

## Tech Stack (Architect)
- framework: fastapi
- db: none (stateless calculations)
- templates: jinja2
- frontend: vanilla JS with fetch API
- See PLAN.md for full API contract

## Design System (AD)
- primary: #00d4aa (teal accent)
- background: #0f0f0f (dark)
- surface: #1a1a1a (cards)
- text: #e2e8f0 (light gray)
- error: #ef4444 (red)
- font: Inter (headings/body), JetBrains Mono (numbers)
- layout: 3 cards side-by-side (desktop), stacked (mobile)
- each card: icon + input + toggle + result
- See DESIGN.md for full specs

## API Endpoints (Backend)
- GET / → Serves the main application (HTML)
- POST /convert/{type} → Performs conversion.
  - Params: `type` (length, weight, temperature)
  - Body: `{"value": float, "direction": string}`
  - Returns: `{"result": float, "from_unit": str, "to_unit": str, "original_value": float}`
- See main.py for full details.

## Frontend (Frontend)
- pages: templates/index.html (Jinja2, single page with 3 converter cards)
- scripts: static/js/app.js (vanilla JS, fetch to POST /convert/{type})
- styles: static/css/style.css (follows DESIGN.md, dark theme, responsive grid)
- features: length/weight/temperature converters with direction toggles
- responsive: 1 col (mobile) → 2 col (tablet) → 3 col (desktop)
- live updates: no page reload, instant results on input

## Testing (Tester)
- test_file: test_api.py
- coverage: all endpoints (length, weight, temperature) + error handling
- status: ✅ All tests passing

## Deployment (DevOps)
- platform: Railway
- url: https://enhetsomvandlare-production.up.railway.app
- project_id: b26639ff-e1bd-4707-bf24-76a02449a6b9
- status: ✅ Deployed and verified

