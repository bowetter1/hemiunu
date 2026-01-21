# Project Plan - Kontaktbok App

## Config
- **DATABASE**: postgres
- **FRAMEWORK**: fastapi
- **ORM**: sqlalchemy
- **DEPLOYMENT**: railway

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app, endpoints, CORS setup |
| database.py | PostgreSQL connection pool, SQLAlchemy engine |
| models.py | SQLAlchemy Contact model |
| templates/index.html | Base HTML template with form and list |
| static/css/style.css | Styling for the app |
| static/js/app.js | Frontend JavaScript for AJAX interactions |
| requirements.txt | Python dependencies |

## Sprint 1: Core Setup

### Features
1. **Project structure** - Files: main.py, database.py, models.py, templates/, static/
2. **PostgreSQL connection** - SQLAlchemy with Railway's DATABASE_URL
3. **Database schema** - contacts table with proper types and constraints
4. **Base template** - index.html with "Kontaktbok" header

### Database Schema

**Table: contacts**
```sql
CREATE TABLE contacts (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_contacts_name ON contacts(name);
CREATE INDEX idx_contacts_email ON contacts(email);
```

**SQLAlchemy Model (models.py):**
```python
from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from database import Base

class Contact(Base):
    __tablename__ = "contacts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), index=True)
    phone = Column(String(50))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

### Environment Variables
- **DATABASE_URL** - Set automatically by Railway for PostgreSQL
  - Format: `postgresql://user:password@host:port/database`
  - Used by SQLAlchemy to connect to PostgreSQL

### API Endpoints (Sprint 1)

No endpoints in Sprint 1 - just setup and base template.

## Sprint 2: Add Contact

### Features
1. **Add form** - HTML form with name, email, phone fields + submit button
2. **POST /contacts endpoint** - Creates contact in database, returns 201 with created contact
3. **Validation** - Name is required (non-empty), email format validated if provided
4. **Success feedback** - User sees confirmation message after successfully adding contact

### API Endpoints (Sprint 2)

#### POST /contacts
**Purpose:** Create a new contact in the database

**Request Body:**
```json
{
  "name": "string (required, 1-255 chars)",
  "email": "string (optional, valid email format)",
  "phone": "string (optional, max 50 chars)"
}
```

**Validation Rules:**
- `name`: REQUIRED, must not be empty string, max 255 characters
- `email`: OPTIONAL, but if provided must be valid email format (regex: `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
- `phone`: OPTIONAL, max 50 characters (no format validation - accepts any string)

**Response 201 (Created):**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+46701234567",
  "created_at": "2026-01-21T15:30:00Z"
}
```

**Response 400 (Bad Request):**
```json
{
  "detail": "Name is required"
}
```

**Response 422 (Validation Error):**
```json
{
  "detail": "Invalid email format"
}
```

**Type Conversions:**
- `created_at`: PostgreSQL TIMESTAMP → ISO 8601 string (e.g., "2026-01-21T15:30:00Z")
- `id`: PostgreSQL SERIAL (integer) → JSON number
- All strings returned as-is from database

**Backend Implementation Notes:**
- Use Pydantic model for request validation
- Trim whitespace from name before validation
- Store email and phone as NULL in database if not provided or empty string
- Return the created contact immediately after insertion
- Use SQLAlchemy session to insert and commit

**Frontend Implementation Notes:**
- Form should have three input fields: name (required), email (optional), phone (optional)
- Submit button should be labeled in Swedish (e.g., "Lägg till kontakt")
- Use `fetch()` to POST JSON to `/contacts`
- Show success message on 201 response
- Show error message on 400/422 response
- Clear form after successful submission

## Sprint 3: View/List Contacts

### Features
1. **GET /contacts endpoint** - Returns list of all contacts ordered by created_at DESC
2. **Contact list UI** - Display all contacts in a clean list/table
3. **Contact details** - Each contact shows name, email, phone
4. **Empty state** - Show friendly message when no contacts exist

### API Endpoints (Sprint 3)

#### GET /contacts
**Purpose:** Retrieve all contacts from the database, ordered by creation date (newest first)

**Request:** None (no query parameters in Sprint 3)

**Response 200 (OK):**
```json
[
  {
    "id": 2,
    "name": "Jane Smith",
    "email": "jane@example.com",
    "phone": "+46709876543",
    "created_at": "2026-01-21T16:00:00Z"
  },
  {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+46701234567",
    "created_at": "2026-01-21T15:30:00Z"
  }
]
```

**Response 200 (Empty):**
```json
[]
```

**Type Conversions:**
- `created_at`: PostgreSQL TIMESTAMP → ISO 8601 string (e.g., "2026-01-21T15:30:00Z")
- `id`: PostgreSQL SERIAL (integer) → JSON number
- `email`: NULL in database → `null` in JSON
- `phone`: NULL in database → `null` in JSON

**Backend Implementation Notes:**
- Query all contacts from database using SQLAlchemy
- Order by `created_at DESC` (newest first)
- Return empty array `[]` if no contacts exist (not 404)
- Use Pydantic response model to ensure consistent JSON structure
- Serialize datetime to ISO 8601 format automatically

**Frontend Implementation Notes:**
- Call `GET /contacts` on page load (DOMContentLoaded event)
- Display contacts in a `<ul>` list or `<table>` (see DESIGN.md for styling)
- Show contact name (bold), email, and phone for each contact
- Display empty state message when array is empty: "Inga kontakter än. Lägg till din första kontakt ovan!"
- Update contact list after successfully adding a new contact (append to top)
- Handle loading state while fetching contacts
- Handle errors gracefully with user-friendly Swedish messages

**Frontend Page Load Flow:**
1. Page loads → `DOMContentLoaded` fires
2. Show loading indicator (optional, e.g., skeleton or spinner)
3. `fetch('/contacts')` → GET request to backend
4. On success (200):
   - If array is empty → show empty state message
   - If array has contacts → render contact list
5. On error → show error message "Kunde inte ladda kontakter"

**Contact Display Format (example):**
```html
<ul id="contact-list">
  <li class="contact-item">
    <h3 class="contact-name">Jane Smith</h3>
    <p class="contact-email">jane@example.com</p>
    <p class="contact-phone">+46709876543</p>
  </li>
  <li class="contact-item">
    <h3 class="contact-name">John Doe</h3>
    <p class="contact-email">john@example.com</p>
    <p class="contact-phone">+46701234567</p>
  </li>
</ul>
```

**Empty State (example):**
```html
<div id="empty-state">
  <p>Inga kontakter än. Lägg till din första kontakt ovan!</p>
</div>
```

## Sprint 4: Search Contacts

### Features
1. **Search input** - Search field visible at top of page
2. **GET /contacts?q=query** - Filters contacts by name, email, or phone
3. **Live results** - Results update as user types or on form submit
4. **No results state** - "No contacts found" message when search returns empty

### API Endpoints (Sprint 4)

#### GET /contacts?q={query}
**Purpose:** Search and filter contacts by name, email, or phone (extends Sprint 3 endpoint)

**Request Query Parameters:**
- `q` (optional, string): Search query to filter contacts
  - If omitted or empty: returns all contacts (same as Sprint 3)
  - If provided: filters contacts matching the query

**Search Behavior:**
- **Case-insensitive** - "john" matches "John", "JOHN", "john"
- **Partial matching** - "doe" matches "John Doe" and "doeson@example.com"
- **Multiple fields** - Searches in name, email, AND phone fields
- **SQL Implementation**: Use PostgreSQL `ILIKE` operator for case-insensitive pattern matching

**SQL Query Logic:**
```sql
SELECT * FROM contacts
WHERE
  name ILIKE '%query%' OR
  email ILIKE '%query%' OR
  phone ILIKE '%query%'
ORDER BY created_at DESC;
```

**Example Requests:**
- `GET /contacts` → Returns all contacts (Sprint 3 behavior)
- `GET /contacts?q=john` → Returns contacts where name/email/phone contains "john"
- `GET /contacts?q=070` → Returns contacts with "070" in phone number
- `GET /contacts?q=@gmail.com` → Returns contacts with Gmail addresses

**Response 200 (OK with results):**
```json
[
  {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+46701234567",
    "created_at": "2026-01-21T15:30:00Z"
  }
]
```

**Response 200 (OK with no results):**
```json
[]
```

**Type Conversions:**
- Same as Sprint 3 (created_at → ISO 8601, NULL → null)

**Backend Implementation Notes:**
- Extend existing `GET /contacts` endpoint from Sprint 3
- Add optional query parameter `q: str | None = None` in FastAPI route
- If `q` is None or empty string, return all contacts (backward compatible)
- If `q` is provided, build SQLAlchemy query with OR conditions:
  ```python
  from sqlalchemy import or_

  query = db.query(Contact)
  if q:
      search_pattern = f"%{q}%"
      query = query.filter(
          or_(
              Contact.name.ilike(search_pattern),
              Contact.email.ilike(search_pattern),
              Contact.phone.ilike(search_pattern)
          )
      )
  query = query.order_by(Contact.created_at.desc())
  ```
- Return empty array `[]` if no matches (not 404)
- Sanitize query input to prevent SQL injection (SQLAlchemy handles this with parameterized queries)

**Frontend Implementation Notes:**
- Add search input field at top of contact list section
- Options for triggering search:
  1. **Live search** (recommended): Debounce input, search as user types (300ms delay)
  2. **Submit button**: Search on form submit
- Clear search button/icon to reset to full list
- Call `GET /contacts?q={userInput}` when search is triggered
- Replace contact list with search results
- Show "No contacts found" empty state when array is empty AND search query is active
- Show total results count: "Visar X kontakter" or "Inga kontakter matchar 'query'"
- Handle errors gracefully with Swedish messages

**Frontend Search Flow:**
1. User types in search field
2. After debounce delay (300ms):
   - If input is empty → `GET /contacts` (show all)
   - If input has value → `GET /contacts?q={value}`
3. Replace contact list with results
4. Update results count/message
5. Show empty state if no results: "Inga kontakter matchar '[query]'"

**Search UX Considerations:**
- Preserve search query in input field during search
- Clear button removes query and shows all contacts
- Maintain search state during add contact (optional)
- Highlight matching text in results (advanced, optional)

## Sprint 5: Delete Contact

### Features
1. **Delete button** - Each contact in the list has a delete button/icon
2. **DELETE /contacts/{id}** - Removes contact from database by ID
3. **Confirmation** - "Are you sure?" confirmation prompt before delete
4. **UI update** - Contact removed from list immediately after successful delete

### API Endpoints (Sprint 5)

#### DELETE /contacts/{id}
**Purpose:** Delete a contact from the database by ID

**Request Path Parameter:**
- `id` (required, integer): The unique ID of the contact to delete

**Example Request:**
```
DELETE /contacts/5
```

**Response 204 (No Content):**
- No response body
- HTTP status 204 indicates successful deletion
- Contact has been permanently removed from database

**Response 404 (Not Found):**
```json
{
  "detail": "Contact not found"
}
```
- Returned when contact with given ID does not exist
- Frontend should handle this gracefully (contact may have been deleted by another user/session)

**Backend Implementation Notes:**
- Use FastAPI path parameter: `@app.delete("/contacts/{id}")`
- Query database for contact by ID using SQLAlchemy
- If contact not found, raise `HTTPException(status_code=404, detail="Contact not found")`
- If found, delete contact using `db.delete(contact)` and `db.commit()`
- Return `Response(status_code=204)` (no content)
- Handle database errors gracefully (e.g., integrity constraints, connection issues)

**SQLAlchemy Implementation:**
```python
contact = db.query(Contact).filter(Contact.id == id).first()
if not contact:
    raise HTTPException(status_code=404, detail="Contact not found")
db.delete(contact)
db.commit()
return Response(status_code=204)
```

**Frontend Implementation Notes:**
- Add delete button/icon to each contact card/row
- Label button clearly in Swedish (e.g., "Ta bort" or "🗑️" trash icon)
- **Confirmation flow:**
  1. User clicks delete button
  2. Show confirmation dialog: "Är du säker på att du vill ta bort [contact name]?"
  3. Two options: "Avbryt" (cancel) and "Ta bort" (confirm delete)
  4. Only proceed with DELETE request if user confirms
- Use native `confirm()` dialog or custom modal (see DESIGN.md for styling)
- Call `DELETE /contacts/{id}` with fetch API
- On 204 response (success):
  - Remove contact from DOM immediately (optimistic UI update)
  - Show success toast: "[Contact name] har tagits bort"
  - Update contact count
- On 404 response:
  - Remove contact from DOM (already deleted elsewhere)
  - Show info message: "Kontakten hade redan tagits bort"
- On network error:
  - Show error message: "Kunde inte ta bort kontakten. Försök igen."
  - Keep contact in list (do not remove from DOM)
- Handle loading state: Disable delete button during request to prevent double-clicks

**Frontend Delete Flow:**
1. User clicks delete button on contact card
2. Confirmation dialog appears: "Är du säker på att du vill ta bort [Name]?"
3. If user cancels → close dialog, no action
4. If user confirms:
   - Disable delete button (show loading state, optional)
   - `fetch('/contacts/{id}', { method: 'DELETE' })`
   - On success (204):
     - Remove contact card from DOM with fade-out animation (optional)
     - Update contact list count
     - Show success toast
   - On error (404 or network):
     - Show appropriate error message
     - Handle as described above

**UX Considerations:**
- Delete button should be clearly identifiable but not too prominent (avoid accidental clicks)
- Confirmation dialog prevents accidental deletion (critical UX requirement)
- Swedish language for all messages
- Optimistic UI: Remove from list immediately after confirmation for snappy UX
- Consider fade-out animation for smooth transition
- Update "no contacts" empty state if deleting last contact

**Accessibility:**
- Delete button: `aria-label="Ta bort [contact name]"`
- Confirmation dialog: proper focus management, Esc to cancel
- Keyboard support: Enter to confirm, Esc to cancel
- Screen reader announcements: "Kontakt borttagen" (aria-live region)

## Technical Notes

### Database Connection (database.py)
- Use SQLAlchemy async or sync engine (sync recommended for simplicity)
- Connection pooling: `pool_size=5, max_overflow=10`
- Handle DATABASE_URL parsing with SQLAlchemy
- Create `Base` declarative base for models
- Implement `get_db()` dependency for FastAPI

### FastAPI Setup (main.py)
- Enable CORS for frontend JS
- Static files mounted at `/static`
- Templates with Jinja2Templates
- Startup event: create tables if not exist
- Health check endpoint: `GET /health`

### Error Handling
- Use FastAPI HTTPException for errors
- Return proper status codes (400, 404, 422, etc.)
- Validation errors with detailed messages

### Data Types
- **Datetime**: PostgreSQL TIMESTAMP WITH TIME ZONE → ISO 8601 string in JSON
- **ID**: PostgreSQL SERIAL (auto-increment) → integer in JSON
- **Strings**: VARCHAR with length limits to prevent abuse

### Railway Deployment
- PORT is set by Railway via environment variable (default: 8000)
- Use `uvicorn main:app --host 0.0.0.0 --port $PORT`
- DATABASE_URL automatically injected by Railway when PostgreSQL is added
- No need for local .env in production

### Frontend-Backend Integration
- Frontend uses `fetch()` API for AJAX calls
- Base template served by FastAPI at `/`
- Static assets (CSS, JS) loaded from `/static`
- JSON responses for all API endpoints
- CORS configured to allow same-origin requests
