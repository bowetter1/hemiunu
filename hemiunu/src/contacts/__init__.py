"""
Contacts module for contact management.
"""

from .db import init_contacts_db, generate_contact_id

__all__ = ['init_contacts_db', 'generate_contact_id']