import sqlite3
import os
import uuid
from src.contacts.db import init_contacts_db

DB_PATH = 'contacts.db'

def test_init_contacts_db_creates_table():
    # Rensa eventuell gammal testdatabas
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    # Initiera databasen
    init_contacts_db()
    
    # Anslut och kontrollera tabellstruktur
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Hämta tabellinfo
    cursor.execute("PRAGMA table_info(contacts)")
    columns = cursor.fetchall()
    
    # Förväntad struktur
    expected_columns = [
        (0, 'id', 'TEXT', 1, None, 1),  # UUID som TEXT, primary key
        (1, 'name', 'TEXT', 1, None, 0),  # NOT NULL
        (2, 'phone', 'TEXT', 0, None, 0),
        (3, 'email', 'TEXT', 0, None, 0),
        (4, 'created_at', 'TIMESTAMP', 0, None, 0)
    ]
    
    assert len(columns) == len(expected_columns), "Antal kolumner matchar inte"
    for actual, expected in zip(columns, expected_columns):
        assert actual == expected, f"Kolumn {actual} matchar inte förväntad struktur"
    
    conn.close()

def test_init_contacts_db_multiple_calls():
    # Rensa eventuell gammal testdatabas
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    # Anropa init två gånger - ska inte kasta fel
    try:
        init_contacts_db()
        init_contacts_db()
    except Exception as e:
        assert False, f"Multipla anrop kastade oväntat fel: {e}"

def test_can_insert_contact():
    # Rensa eventuell gammal testdatabas
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    
    # Initiera databasen
    init_contacts_db()
    
    # Anslut och testa insertion
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    test_id = str(uuid.uuid4())
    cursor.execute("""
        INSERT INTO contacts (id, name, phone, email, created_at) 
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
    """, (test_id, "Test Testsson", "123456", "test@example.com"))
    
    conn.commit()
    
    # Verifiera insättning
    cursor.execute("SELECT * FROM contacts WHERE id = ?", (test_id,))
    result = cursor.fetchone()
    
    assert result is not None, "Kunde inte infoga kontakt"
    assert result[0] == test_id
    assert result[1] == "Test Testsson"
    
    conn.close()