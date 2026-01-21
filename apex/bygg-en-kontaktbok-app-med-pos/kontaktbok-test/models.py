"""
SQLAlchemy models for the Kontaktbok application.

Models:
- Contact: Stores contact information (name, email, phone)
"""

from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from database import Base


class Contact(Base):
    """
    Contact model for storing contact information.

    Fields:
    - id: Auto-incrementing primary key
    - name: Contact name (required, max 255 chars)
    - email: Email address (optional, max 255 chars, indexed)
    - phone: Phone number (optional, max 50 chars)
    - created_at: Timestamp of creation (auto-set)
    """
    __tablename__ = "contacts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), index=True)
    phone = Column(String(50))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def to_dict(self):
        """Convert model instance to dictionary for JSON serialization."""
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "phone": self.phone,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
