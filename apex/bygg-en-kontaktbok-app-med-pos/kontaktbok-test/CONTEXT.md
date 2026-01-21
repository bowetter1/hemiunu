# PROJECT CONTEXT

## Environment (DevOps)
- python: 3.14.2
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- psycopg2-binary: 2.9.11
- httpx: 0.27.0
- status: OK

## Tech Stack (Architect)
- framework: fastapi
- db: postgres
- orm: sqlalchemy
- deployment: railway
- See PLAN.md for complete architecture

## Design System (AD)
- primary: #5B7C99 (soft blue - trust, Swedish flag)
- accent: #D4A574 (warm beige - approachable)
- background: #F7F5F2 (warm off-white)
- surface: #FFFFFF (cards, modals)
- text: #2D3142 (dark navy)
- font: Inter (headings + body), JetBrains Mono (mono)
- spacing: 4px base (xs-4, sm-8, md-16, lg-24, xl-32)
- border-radius: cards-12px, buttons-8px, inputs-4px
- shadows: soft, subtle (Scandinavian minimalism)
- accessibility: WCAG AA compliant, 44px touch targets
- **Sprint 2: Add Contact Form**
  - validation: inline on blur, real-time error removal
  - error color: #C4756E, success: #8FAA92
  - submit button: full-width, 48px min-height, loading state
  - toast notifications: fixed top-right, 4s auto-dismiss, slideInRight animation
  - Swedish UI: "Namn är obligatoriskt", "Ogiltig e-postadress"
- **Sprint 3: Contact List View**
  - layout: card-based grid (1-2-3 columns responsive)
  - card style: white bg, 12px radius, 20-24px padding, soft shadow
  - monospace: JetBrains Mono for email/phone (better readability)
  - empty state: "Inga kontakter ännu" with 📇 icon, friendly Swedish message
  - hover: subtle lift (2px) + enhanced shadow
  - missing fields: hide empty email/phone lines
  - responsive: 1 col mobile, 2 col tablet, 3 col desktop
- **Sprint 4: Search**
  - search input: white bg, 2px border #E5E7EB, 4px radius, 48px min-height
  - placeholder: "Sök kontakter..." (Swedish)
  - search icon: 🔍 magnifying glass left (20px, #6B7280)
  - clear button: × right side, hidden by default, shows when input has text
  - debounced live search: 300ms delay to prevent excessive API calls
  - no results state: 🔍 icon + "Inga träffar" + "Försök med ett annat sökord"
  - keyboard: Tab, Esc to clear, full ARIA accessibility
  - mobile: 16px font (prevents iOS zoom), full-width responsive
  - placement: above contact list, below add form
- **Sprint 5: Delete Contact**
  - delete button: top-right corner of card, circular (36px), trash icon 🗑️
  - button states: muted by default (#6B7280), danger color on hover (#C4756E)
  - confirmation modal: "Radera kontakt?" with specific contact name shown
  - modal text: "Vill du verkligen ta bort [Namn]?" + "Denna åtgärd kan inte ångras"
  - reversed button order (Scandinavian pattern): Cancel first, Delete last
  - default focus: Cancel button (safety-first, prevents accidental Enter deletion)
  - danger styling: red/error color #C4756E for delete button
  - modal animations: fadeIn 0.2s overlay, slideUp 0.3s modal container
  - success toast: "✓ [Namn] har raderats" (4s auto-dismiss)
  - error toast: "❌ Kunde inte radera kontakt. Försök igen."
  - keyboard: Tab, Esc to cancel, Enter to confirm (when Delete focused)
  - accessibility: ARIA dialog, focus trap, screen reader announcements
  - mobile: stacked buttons (Cancel top, Delete bottom), full-width, 48px touch targets
- See DESIGN.md for full system

## API Endpoints (Backend)
**Sprint 1 (Core Setup) - DONE:**
- GET / → Serve frontend (index.html template)
- GET /health → Health check endpoint

**Sprint 2 (Add Contact) - DONE:**
- POST /contacts → Create new contact
  - Request: {name: string (required), email: string (optional), phone: string (optional)}
  - Response 201: {id, name, email, phone, created_at}
  - Response 400: Name validation error (empty or whitespace-only name)
  - Response 422: Email format error (invalid email format)
  - Validation: Name trimmed, email format checked with regex, phone optional
  - Implementation: Pydantic schema with field_validator for name and email

**Sprint 3 (View/List Contacts) - DONE:**
- GET /contacts → List all contacts ordered by created_at DESC
  - Request: None (no query parameters)
  - Response 200: Array of contacts [{id, name, email, phone, created_at}]
  - Empty array [] if no contacts exist
  - Type conversions: created_at → ISO 8601 string, NULL → null in JSON
  - Implementation: Pydantic ContactResponse schema, SQLAlchemy query with order_by DESC
  - Frontend: Load on page load (DOMContentLoaded), display in list/table, empty state message

**Sprint 4 (Search Contacts) - DONE:**
- GET /contacts?q=query → Search/filter contacts (extends Sprint 3 endpoint)
  - Request: Optional query parameter 'q' (string)
  - Response 200: Filtered array of contacts [{id, name, email, phone, created_at}]
  - Search logic: Case-insensitive ILIKE matching in name, email, OR phone fields
  - SQL: WHERE name ILIKE '%query%' OR email ILIKE '%query%' OR phone ILIKE '%query%'
  - If q is empty/omitted: returns all contacts (backward compatible with Sprint 3)
  - Empty array [] if no matches
  - Implementation: ✅ SQLAlchemy or_() with .ilike() for multiple field search, order_by DESC
  - Backend: main.py:200 - get_contacts() function with optional q parameter
  - Frontend: Search input field, debounced live search (300ms) or submit button, show "Inga kontakter matchar '[query]'" when no results

**Sprint 5 (Delete Contact) - DONE:**
- DELETE /contacts/{id} → Delete contact by ID
  - Request: Path parameter id (integer)
  - Response 204: No content (successful deletion)
  - Response 404: {"detail": "Contact not found"}
  - Frontend: Delete button on each contact, confirmation dialog "Är du säker på att du vill ta bort [name]?", optimistic UI update, toast notification
  - Implementation: ✅ SQLAlchemy query + delete, HTTPException for 404, Response(status_code=204)
  - Backend: main.py:273 - delete_contact() function with path parameter id
  - UX: Swedish confirmation, disabled button during request, fade-out animation, update count

**Implementation:**
- database.py: PostgreSQL connection with SQLAlchemy (DATABASE_URL env var)
- models.py: Contact model (id, name, email, phone, created_at)
- main.py: FastAPI app with CORS, Jinja2 templates, static files
- Tables created automatically on startup

## Frontend (Frontend)
**Sprint 1 (Core Setup) - DONE:**
- base template: templates/base.html
- index page: templates/index.html
- styles: static/style.css
- design tokens: CSS variables in style.css (colors, spacing, typography)
- Swedish UI: "Kontaktbok", "Välkommen till din kontaktbok"

**Sprint 2 (Add Contact) - DONE:**
- templates/index.html: Add contact form with name (required), email, phone fields
- static/style.css: Form styling, validation states, toast notifications, responsive design
- static/js/app.js: Form submission, validation, fetch API, toast notifications
- Validation: Inline on blur, real-time error removal, Swedish error messages
- Success feedback: Toast notification "Kontakt tillagd! [Name] har sparats"
- Error handling: Network errors, validation errors (400, 422), user-friendly Swedish messages
- Form behavior: Clears on success, focus returns to name field, loading spinner during submission
- Accessibility: aria-required, aria-invalid, aria-live for toasts, keyboard navigation (Tab, Enter, Esc)

**Sprint 3 (View/List Contacts) - DONE:**
- templates/index.html: Contact list section with grid layout, heading with count, empty state
- static/style.css: Contact card styles (white bg, 12px radius, 20-24px padding, soft shadow), responsive grid (1-2-3 columns), hover effects (2px lift + shadow), empty state styling, fade-in animations
- static/js/app.js: loadContacts() fetches GET /contacts on page load, renderContactList() displays cards, updates count, shows empty state "Inga kontakter ännu" when no contacts
- Card display: Name (18px bold), email (monospace, primary color), phone (monospace, muted color)
- Missing fields: Empty email/phone hidden automatically with CSS :empty selector
- List updates: Contact list refreshes after successfully adding new contact
- Empty state: 📇 icon, "Inga kontakter ännu", friendly Swedish message
- Responsive: 1 column mobile, 2 columns tablet, 3 columns desktop
- Accessibility: Semantic HTML (article), role attributes, proper heading structure

**Sprint 4 (Search Contacts) - DONE:**
- templates/index.html: Search input section above contact list with search icon (🔍), input field, clear button (×), no results state
- static/style.css: Search input styling (white bg, 2px border, 4px radius, 48px min-height), search icon left (20px), clear button right (32px, hidden by default), no results state (🔍 icon + "Inga träffar" + "Försök med ett annat sökord")
- static/js/app.js: Debounced live search (300ms delay), performSearch() function, clear button toggle, Esc key to clear, GET /contacts?q=query API call, renderContactList() updated to show no results state when search active
- Search behavior: Live search updates results as user types (debounced), clear button appears when input has text, Esc clears search, empty query shows all contacts
- No results state: Shows when search query returns empty array (different from general empty state)
- Accessibility: role="searchbox", aria-label, aria-live announcement for screen readers, keyboard support (Tab, Esc)
- Mobile: 16px font prevents iOS zoom, full-width responsive, 48px touch targets
