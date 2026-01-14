import sqlite3
import pytest
from src.contacts.db import init_contacts_db

def test_init_contacts_db_creates_table():
    """Test att init_contacts_db skapar contacts-tabellen"""
    init_contacts_db()
    
    # Anslut till databasen
    conn = sqlite3.connect('contacts.db')
    cursor = conn.cursor()
    
    # Kontrollera att tabellen finns
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='contacts'")
    table_exists = cursor.fetchone()
    
    conn.close()
    assert table_exists is not None, "Contacts-tabellen skapades inte"

def test_contacts_table_structure():
    """Verifiera contacts-tabellens kolumner"""
    init_contacts_db()
    
    conn = sqlite3.connect('contacts.db')
    cursor = conn.cursor()
    
    # Hämta tabellinfo
    cursor.execute("PRAGMA table_info(contacts)")
    columns = cursor.fetchall()
    
    # Förväntade kolumner
    expected_columns = [
        (0, 'id', 'TEXT', 1, None, 1),  # UUID som TEXT, primärnyckel
        (1, 'name', 'TEXT', 1, None, 0),  # NOT NULL
        (2, 'phone', 'TEXT', 0, None, 0),
        (3, 'email', 'TEXT', 0, None, 0),
        (4, 'created_at', 'TIMESTAMP', 0, None, 0)
    ]
    
    conn.close()
    assert columns == expected_columns, "Tabellstrukturen är felaktig"

def test_multiple_init_calls():
    """Testa att init-funktionen kan köras flera gånger utan fel"""
    init_contacts_db()
    init_contacts_db()  # Upprepad initiering ska inte orsaka fel
    
    conn = sqlite3.connect('contacts.db')
    cursor = conn.cursor()
    
    # Kontrollera att tabellen fortfarande finns
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='contacts'")
    table_exists = cursor.fetchone()
    
    conn.close()
    assert table_exists is not None, "Tabellen försvann vid upprepad initiering"