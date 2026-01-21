# Project Plan - Kontaktbok

## Config
- **DATABASE**: sqlite
- **FRAMEWORK**: fastapi

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app + API endpoints |
| database.py | SQLite connection with SQLAlchemy |
| models.py | Contact SQLAlchemy model |
| templates/index.html | Main page with contact list + forms |
| static/css/style.css | Styling |
| static/js/main.js | Frontend JavaScript (fetch API calls) |

## Database Schema

### contacts table
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| name | VARCHAR(100) | NOT NULL |
| phone | VARCHAR(50) | NULL |
| email | VARCHAR(100) | NULL |
| notes | TEXT | NULL |
| created_at | DATETIME | DEFAULT CURRENT_TIMESTAMP |
| updated_at | DATETIME | DEFAULT CURRENT_TIMESTAMP |

## Features (Sprint 1) ✅
1. Project structure with main.py, database.py, models.py
2. SQLite database with contacts table
3. View all contacts (GET /contacts + table display)
4. Add contact form (POST /contacts)

## Features (Sprint 2) ✅
1. Search contacts (GET /contacts?q=term filters by name/phone/email)
2. Search UI with input field, results update on search
3. Get single contact (GET /contacts/{id})
4. Update contact (PUT /contacts/{id})
5. Edit UI - click contact to edit, form pre-fills, save updates

## Features (Sprint 3)
1. Delete contact (DELETE /contacts/{id} removes contact from database)
2. Delete UI - Delete button on each contact row, confirmation dialog before delete
3. Empty state - Shows "Inga kontakter ännu" message when contact list is empty
4. Validation - Required fields (name) validated, clear error messages shown to user

**See CRITERIA.md for full acceptance criteria!**

## API Endpoints

### GET /
Serves the main HTML page (templates/index.html)

Response: HTML page

---

### GET /contacts
Returns all contacts as JSON list.

Query params:
- q: string (optional) - search term for name/phone/email

Response 200:
```json
[
  {
    "id": 1,
    "name": "Anna Svensson",
    "phone": "070-123 45 67",
    "email": "anna@example.com",
    "notes": "Kollega",
    "created_at": "2024-01-15T10:30:00",
    "updated_at": "2024-01-15T10:30:00"
  }
]
```

---

### POST /contacts
Creates a new contact.

Request body:
```json
{
  "name": "string (required)",
  "phone": "string (optional)",
  "email": "string (optional)",
  "notes": "string (optional)"
}
```

Response 201:
```json
{
  "id": 1,
  "name": "Anna Svensson",
  "phone": "070-123 45 67",
  "email": "anna@example.com",
  "notes": "Kollega",
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-15T10:30:00"
}
```

Response 422 (validation error):
```json
{
  "detail": [{"loc": ["body", "name"], "msg": "field required"}]
}
```

---

### GET /contacts/{id}
Returns a single contact by ID.

Response 200:
```json
{
  "id": 1,
  "name": "Anna Svensson",
  "phone": "070-123 45 67",
  "email": "anna@example.com",
  "notes": "Kollega",
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-15T10:30:00"
}
```

Response 404:
```json
{
  "detail": "Contact not found"
}
```

---

### PUT /contacts/{id}
Updates an existing contact. The `updated_at` field is automatically set to current timestamp.

Request body:
```json
{
  "name": "string (required)",
  "phone": "string (optional, null to clear)",
  "email": "string (optional, null to clear)",
  "notes": "string (optional, null to clear)"
}
```

Response 200:
```json
{
  "id": 1,
  "name": "Anna Svensson (updated)",
  "phone": "070-999 88 77",
  "email": "anna.updated@example.com",
  "notes": "Uppdaterad anteckning",
  "created_at": "2024-01-15T10:30:00",
  "updated_at": "2024-01-16T14:20:00"
}
```

Response 404:
```json
{
  "detail": "Contact not found"
}
```

Response 422 (validation error):
```json
{
  "detail": [{"loc": ["body", "name"], "msg": "field required"}]
}
```

---

### DELETE /contacts/{id}
Deletes a contact permanently from the database.

Path parameters:
- id: integer (required) - the contact ID to delete

Response 200 (success):
```json
{
  "message": "Contact deleted"
}
```

Response 404 (contact not found):
```json
{
  "detail": "Contact not found"
}
```

**Implementation notes:**
- Check if contact exists before attempting delete
- Return 404 with `{"detail": "Contact not found"}` if ID doesn't exist
- Return 200 with success message after successful deletion
- No request body required

## Environment Variables
- PORT (set by Railway, default 8000)
- DATABASE_URL (optional - defaults to sqlite:///./contacts.db)

## Tech Notes
- SQLite file stored as `contacts.db` in project root
- FastAPI with Jinja2 for template rendering
- SQLAlchemy ORM for database operations
- Pydantic schemas for request/response validation
- datetime fields returned as ISO 8601 strings

## Sprint 3 Implementation Notes

### Delete Endpoint
- Backend: Add DELETE /contacts/{id} endpoint in main.py
- Query database for contact by ID first
- If not found: raise HTTPException(status_code=404, detail="Contact not found")
- If found: delete from database, commit, return {"message": "Contact deleted"}

### Frontend Delete UI
- Add delete button (red, danger color) to each contact row/card
- Show confirmation dialog before delete: "Är du säker på att du vill ta bort [name]?"
- Dialog has "Avbryt" (cancel) and "Ta bort" (delete, red) buttons
- On confirm: call DELETE /contacts/{id}, remove from list, show success toast
- On 404 error: show error toast "Kontakten hittades inte"

### Empty State
- Check if contacts array is empty after fetch
- Show centered message: "Inga kontakter ännu"
- Optionally show "Lägg till din första kontakt" button/link

### Validation (Frontend)
- Name field is required - show error if empty on submit
- Error style: red border (#EF4444), error message below field
- Prevent form submission if validation fails
- Clear errors when user starts typing
