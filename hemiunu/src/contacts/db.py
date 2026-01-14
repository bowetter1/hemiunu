"""
Database module for contacts management.
Handles SQLite database initialization and schema creation.
"""

import sqlite3
import uuid
from pathlib import Path
from typing import Optional


def init_contacts_db(db_path: Optional[str] = None) -> str:
    """
    Initialize the contacts database by creating the contacts table if it doesn't exist.
    
    Args:
        db_path: Path to the database file. If None, uses 'contacts.db' in current directory.
        
    Returns:
        The path to the database file that was initialized.
    """
    if db_path is None:
        db_path = "contacts.db"
    
    # Ensure the directory exists
    db_file = Path(db_path)
    db_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Connect to the database (creates it if it doesn't exist)
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Create the contacts table with the specified schema
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT,
                email TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Commit the changes
        conn.commit()
        
    finally:
        # Always close the connection
        conn.close()
    
    return db_path


def generate_contact_id() -> str:
    """
    Generate a new UUID for a contact.
    
    Returns:
        A string representation of a UUID4.
    """
    return str(uuid.uuid4())