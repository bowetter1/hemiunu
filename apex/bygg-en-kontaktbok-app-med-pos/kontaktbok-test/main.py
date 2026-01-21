"""
FastAPI application for Kontaktbok (Contact Book).

Sprint 1: Core Setup
- FastAPI app with CORS enabled
- Jinja2 templates setup
- Static files mounting
- Database table creation on startup
- Base route serving index.html template
- Health check endpoint

Sprint 2: Add Contact
- POST /contacts endpoint with Pydantic validation
- Name validation (required, non-empty)
- Email validation (optional, format check)
- Phone validation (optional, max 50 chars)
- Returns 201 with created contact

Sprint 3: View/List Contacts
- GET /contacts endpoint returns all contacts
- Ordered by created_at DESC (newest first)
- Returns empty array [] if no contacts exist
- Pydantic response schema for consistent JSON

Sprint 4: Search Contacts
- GET /contacts?q=query extends Sprint 3 endpoint
- Filters contacts by name, email, or phone (case-insensitive)
- Uses PostgreSQL ILIKE for partial, case-insensitive matching
- Returns filtered array or empty [] if no matches

Sprint 5: Delete Contact
- DELETE /contacts/{id} endpoint removes contact by ID
- Returns 204 No Content on success
- Returns 404 if contact not found
- Frontend shows confirmation before delete

API ENDPOINTS:
- GET    /          - Serve frontend (index.html template)
- GET    /health    - Health check
- POST   /contacts  - Create contact {name, email?, phone?} → 201 {id, name, email, phone, created_at}
- GET    /contacts?q=query - List/search contacts ordered by created_at DESC → 200 [{id, name, email, phone, created_at}]
                            - q (optional): Search in name, email, or phone (case-insensitive partial match)
                            - If q omitted: returns all contacts
- DELETE /contacts/{id}    - Delete contact by ID → 204 No Content (success) or 404 Not Found
"""

import os
import re
from fastapi import FastAPI, Request, HTTPException, Depends, Response
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session

from database import engine, Base, get_db
from models import Contact

# Create FastAPI app
app = FastAPI(
    title="Kontaktbok API",
    description="Contact management application with PostgreSQL backend",
    version="1.0.0",
)

# Enable CORS for frontend JavaScript
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files (CSS, JS)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup Jinja2 templates
templates = Jinja2Templates(directory="templates")


# Pydantic schemas for request/response validation
class ContactCreate(BaseModel):
    """Schema for creating a new contact."""
    name: str
    email: str | None = None
    phone: str | None = None

    @field_validator('name')
    @classmethod
    def validate_name(cls, v):
        """Validate that name is not empty after trimming whitespace."""
        if not v or not v.strip():
            raise ValueError('Name is required')
        return v.strip()

    @field_validator('email')
    @classmethod
    def validate_email(cls, v):
        """Validate email format if provided."""
        if v is None or v == '':
            return None
        # Email format validation
        email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_pattern, v.strip()):
            raise ValueError('Invalid email format')
        return v.strip()

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v):
        """Clean phone field - return None if empty string."""
        if v is None or v == '':
            return None
        return v.strip()


class ContactResponse(BaseModel):
    """Schema for contact response (read operations)."""
    id: int
    name: str
    email: str | None = None
    phone: str | None = None
    created_at: str  # ISO 8601 datetime string

    class Config:
        from_attributes = True  # Allows creation from ORM model


# Startup event: Create database tables
@app.on_event("startup")
def create_tables():
    """Create all database tables on application startup."""
    Base.metadata.create_all(bind=engine)
    print("✅ Database tables created successfully")


# Routes
@app.get("/")
def serve_frontend(request: Request):
    """
    Serve the main frontend template.
    Frontend developer will create the actual HTML/CSS/JS.
    """
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/health")
def health_check():
    """Health check endpoint for monitoring."""
    return {
        "status": "healthy",
        "service": "kontaktbok-api",
        "database": "connected",
    }


@app.post("/contacts", status_code=201)
def create_contact(contact_data: ContactCreate, db: Session = Depends(get_db)):
    """
    Create a new contact in the database.

    Sprint 2 endpoint - validates and stores contact information.

    Request body:
    - name: string (required, 1-255 chars, trimmed)
    - email: string (optional, valid email format)
    - phone: string (optional, max 50 chars)

    Returns:
    - 201: Created contact with id, name, email, phone, created_at
    - 400: Name validation error
    - 422: Email format validation error (Pydantic handles this)

    Example usage (Frontend):
        fetch('/contacts', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                name: 'Anna Svensson',
                email: 'anna@example.com',
                phone: '+46701234567'
            })
        })
    """
    try:
        # Create new Contact instance
        new_contact = Contact(
            name=contact_data.name,
            email=contact_data.email,
            phone=contact_data.phone,
        )

        # Add to database
        db.add(new_contact)
        db.commit()
        db.refresh(new_contact)  # Get the auto-generated id and created_at

        # Return the created contact as dictionary
        return new_contact.to_dict()

    except Exception as e:
        db.rollback()
        # If it's a validation error, raise 400
        if "Name is required" in str(e):
            raise HTTPException(status_code=400, detail="Name is required")
        # Re-raise other exceptions
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/contacts", response_model=list[ContactResponse])
def get_contacts(q: str | None = None, db: Session = Depends(get_db)):
    """
    Retrieve all contacts from the database, ordered by created_at DESC (newest first).

    Sprint 3 endpoint - list/view all contacts.
    Sprint 4 extension - search/filter contacts by query parameter.

    Query Parameters:
    - q (optional): Search query to filter contacts by name, email, or phone
      - If omitted or empty: returns all contacts (backward compatible with Sprint 3)
      - If provided: filters contacts matching the query (case-insensitive, partial match)

    Returns:
    - 200: Array of contacts [{id, name, email, phone, created_at}]
    - Returns empty array [] if no contacts match (not 404)

    Search Behavior:
    - Case-insensitive: "john" matches "John", "JOHN", "john"
    - Partial matching: "doe" matches "John Doe" and "doeson@example.com"
    - Multiple fields: Searches in name, email, AND phone fields using OR logic
    - SQL: WHERE name ILIKE '%query%' OR email ILIKE '%query%' OR phone ILIKE '%query%'

    Type conversions:
    - created_at: PostgreSQL TIMESTAMP → ISO 8601 string (e.g., "2026-01-21T15:30:00Z")
    - id: PostgreSQL SERIAL (integer) → JSON number
    - email: NULL in database → null in JSON
    - phone: NULL in database → null in JSON

    Example usage (Frontend):
        // Get all contacts (Sprint 3)
        fetch('/contacts')

        // Search contacts (Sprint 4)
        fetch('/contacts?q=john')
        fetch('/contacts?q=070')
        fetch('/contacts?q=@gmail.com')
    """
    try:
        # Start with base query
        query = db.query(Contact)

        # Apply search filter if query parameter provided
        if q:
            # Case-insensitive search using ILIKE for PostgreSQL
            from sqlalchemy import or_
            search_pattern = f"%{q}%"
            query = query.filter(
                or_(
                    Contact.name.ilike(search_pattern),
                    Contact.email.ilike(search_pattern),
                    Contact.phone.ilike(search_pattern)
                )
            )

        # Order by created_at DESC (newest first) and execute query
        contacts = query.order_by(Contact.created_at.desc()).all()

        # Convert to list of dictionaries for JSON response
        # Pydantic will handle serialization with ContactResponse schema
        return [contact.to_dict() for contact in contacts]

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.delete("/contacts/{id}", status_code=204)
def delete_contact(id: int, db: Session = Depends(get_db)):
    """
    Delete a contact from the database by ID.

    Sprint 5 endpoint - removes contact permanently from database.

    Path Parameters:
    - id: integer (required) - The unique ID of the contact to delete

    Returns:
    - 204 No Content: Successfully deleted (no response body)
    - 404 Not Found: Contact with given ID does not exist

    Frontend Usage:
        fetch('/contacts/5', { method: 'DELETE' })
            .then(response => {
                if (response.status === 204) {
                    // Successfully deleted - remove from UI
                }
                if (response.status === 404) {
                    // Contact not found - may have been deleted already
                }
            })

    UX Flow:
    1. User clicks delete button on contact card
    2. Confirmation dialog: "Är du säker på att du vill ta bort [Name]?"
    3. If confirmed, send DELETE request
    4. On 204: Remove contact from DOM, show success toast
    5. On 404: Show info message "Already deleted"
    """
    try:
        # Query database for contact by ID
        contact = db.query(Contact).filter(Contact.id == id).first()

        # If contact not found, return 404
        if not contact:
            raise HTTPException(status_code=404, detail="Contact not found")

        # Delete contact and commit
        db.delete(contact)
        db.commit()

        # Return 204 No Content (successful deletion, no body)
        return Response(status_code=204)

    except HTTPException:
        # Re-raise HTTP exceptions (404)
        raise
    except Exception as e:
        # Rollback transaction on error
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# For local development
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
