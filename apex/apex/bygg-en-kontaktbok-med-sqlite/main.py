from fastapi import FastAPI, Depends, Request, HTTPException, status
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict

import models
from database import engine, get_db

# Create database tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Kontaktbok API")

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Pydantic Schemas
class ContactBase(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    notes: Optional[str] = None

class ContactCreate(ContactBase):
    pass

class Contact(ContactBase):
    id: int
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

# API ENDPOINTS:
# GET  /                  - serve index.html
# GET  /contacts          - list all (?q=search)
# POST /contacts          - create (body: {name, phone, email, notes})
# GET  /contacts/{id}     - get one
# PUT  /contacts/{id}     - update (body: {name, phone, email, notes})
# DELETE /contacts/{id}   - delete

@app.get("/")
def serve_frontend(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/contacts", response_model=List[Contact])
def get_contacts(q: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(models.Contact)
    if q:
        query = query.filter(
            (models.Contact.name.ilike(f"%{q}%")) |
            (models.Contact.phone.ilike(f"%{q}%")) |
            (models.Contact.email.ilike(f"%{q}%"))
        )
    return query.all()

@app.post("/contacts", response_model=Contact, status_code=status.HTTP_201_CREATED)
def create_contact(contact: ContactCreate, db: Session = Depends(get_db)):
    db_contact = models.Contact(**contact.model_dump())
    db.add(db_contact)
    db.commit()
    db.refresh(db_contact)
    return db_contact

@app.get("/contacts/{contact_id}", response_model=Contact)
def get_contact(contact_id: int, db: Session = Depends(get_db)):
    contact = db.query(models.Contact).filter(models.Contact.id == contact_id).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    return contact

@app.put("/contacts/{contact_id}", response_model=Contact)
def update_contact(contact_id: int, contact_update: ContactCreate, db: Session = Depends(get_db)):
    db_contact = db.query(models.Contact).filter(models.Contact.id == contact_id).first()
    if not db_contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    update_data = contact_update.model_dump()
    for key, value in update_data.items():
        setattr(db_contact, key, value)
    
    db.commit()
    db.refresh(db_contact)
    return db_contact

@app.delete("/contacts/{contact_id}", status_code=status.HTTP_200_OK)
def delete_contact(contact_id: int, db: Session = Depends(get_db)):
    contact = db.query(models.Contact).filter(models.Contact.id == contact_id).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    
    db.delete(contact)
    db.commit()
    return {"message": "Contact deleted"}
