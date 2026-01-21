# PROJECT CONTEXT

## NEEDS (blockers)
| Från | Behöver | Från vem | Status |
|------|---------|----------|--------|

## Environment (DevOps)
- python: 3.14.2
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- httpx: 0.27.0
- status: OK

## Tech Stack (Architect)
- framework: fastapi
- db: sqlite (file: contacts.db)
- orm: sqlalchemy
- templates: jinja2
- See PLAN.md for full architecture

## Design System (AD)
- primary: #0D9488 (teal)
- primary-hover: #0F766E
- background: #F8FAFC
- surface: #FFFFFF
- text: #1E293B
- text-muted: #64748B
- danger: #EF4444
- success: #10B981
- warning: #F59E0B
- font: Inter (Google Fonts)
- spacing base: 4px
- border-radius: 8px (buttons/inputs), 12px (cards)
- **Sprint 2 additions:**
  - Edit mode: Modal title "Redigera kontakt", pre-filled fields
  - Validation states: error border #EF4444, error bg #FEF2F2
  - Required indicator: red asterisk (*) + legend "* Obligatoriskt fält"
  - Inline errors: 13px, #EF4444, with alert-circle icon
  - Toast notifications: bottom-right, success/error/warning types
  - Toast timing: success 3s auto-dismiss, error NO auto-dismiss
- **Sprint 3 additions:**
  - Delete confirmation modal: centered, max-width 400px, danger icon (#EF4444)
  - Modal title: "Ta bort kontakt", shows contact name in bold
  - Warning text: "Denna åtgärd kan inte ångras."
  - Danger button: #EF4444, hover #DC2626, focus ring rgba(239,68,68,0.3)
  - Icon delete button: transparent bg, hover #FEF2F2 with red icon
  - Empty state: dashed border (#E2E8F0), 80px icon circle (#F1F5F9)
  - Empty state text: "Inga kontakter ännu" + description + optional CTA
  - Delete animation: fadeOutDelete 0.3s with slide-left effect
- See DESIGN.md for full details

## Tester (Tester)
- tests: tests/test_api.py (comprehensive API tests)
- status: 11 tests passing (GET, POST, PUT, DELETE, validation, 404)
- fixtures: tests/conftest.py (in-memory sqlite, async client)

## API Endpoints (Backend)
- GET / → Serves index.html
- GET /contacts?q=search → List all contacts, optional search filter
- POST /contacts {name, phone, email, notes} → Create a new contact
- GET /contacts/{id} → Get single contact by ID
- PUT /contacts/{id} {name, phone, email, notes} → Update contact
- DELETE /contacts/{id} → Delete contact (200 success, 404 if not found)
- See PLAN.md for full request/response schemas

## Frontend (Frontend)
- templates/index.html: Main page with contact list, search, add/edit/delete modals
- static/css/style.css: All styles following DESIGN.md (colors, typography, spacing)
- static/js/main.js: JavaScript for API calls (GET/POST/PUT/DELETE /contacts)
- Features: Contact list rendering, search with debounce, add/edit/delete contacts, toast notifications, loading states, empty state
- API calls match PLAN.md contract exactly
- **Sprint 3 updates:**
  - Enhanced delete confirmation modal with danger icon, contact name, and warning text
  - Danger button styles with hover/focus/active/disabled states
  - Enhanced empty state with dashed border, 80px icon circle, and CTA button
  - Delete animation (fadeOutDelete) with slide-left effect
  - Modal backdrop with blur effect
