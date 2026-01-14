import sqlite3
import os
import pytest
from src.contacts.db import init_contacts_db

DB_PATH = 'contacts.db'

def test_init_contacts_db_creates_database():
    """Verifiera att databasen skapas"""
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    init_contacts_db()
    
    assert os.path.exists(DB_PATH), "Databasen skapades inte"

def test_contacts_table_structure():
    """Verifiera kontakttabellens struktur"""
    init_contacts_db()
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Hämta tabellinfo
    cursor.execute("PRAGMA table_info(contacts)")
    columns = cursor.fetchall()
    
    # Förväntade kolumner och deras egenskaper
    expected_columns = [
        {'name': 'id', 'type': 'TEXT', 'notnull': 1, 'pk': 1},
        {'name': 'name', 'type': 'TEXT', 'notnull': 1, 'pk': 0},
        {'name': 'phone', 'type': 'TEXT', 'notnull': 0, 'pk': 0},
        {'name': 'email', 'type': 'TEXT', 'notnull': 0, 'pk': 0},
        {'name': 'created_at', 'type': 'TIMESTAMP', 'notnull': 0, 'pk': 0}
    ]
    
    assert len(columns) == 5, "Fel antal kolumner"
    
    for i, column in enumerate(columns):
        # column = (index, name, type, notnull, default_value, pk)
        assert column[1] == expected_columns[i]['name'], f"Felaktigt kolumnnamn för kolumn {i}"
        assert column[2] == expected_columns[i]['type'], f"Felaktig datatyp för {column[1]}"
        assert column[3] == expected_columns[i]['notnull'], f"Felaktigt NOT NULL för {column[1]}"
        assert column[5] == expected_columns[i]['pk'], f"Felaktig primary key för {column[1]}"
    
    conn.close()

def test_multiple_init_calls():
    """Verifiera att upprepade initialiseringar fungerar"""
    init_contacts_db()
    init_contacts_db()  # Ska inte kasta fel
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Kontrollera att tabellen finns
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='contacts'")
    assert cursor.fetchone() is not None, "Tabellen försvann vid upprepad initiering"
    
    conn.close()