import sqlite3
from typing import List, Dict, Any, Optional

DB_NAME = "todos.db"

def get_db_connection():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db_connection()
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            completed INTEGER DEFAULT 0
        )
    ''')
    conn.commit()
    conn.close()

# Helper functions for database operations

def create_todo(title: str) -> Dict[str, Any]:
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("INSERT INTO todos (title) VALUES (?)", (title,))
    todo_id = c.lastrowid
    conn.commit()
    
    # Fetch the created todo
    c.execute("SELECT * FROM todos WHERE id = ?", (todo_id,))
    row = c.fetchone()
    conn.close()
    
    return dict(row)

def get_all_todos() -> List[Dict[str, Any]]:
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM todos")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def get_todo(todo_id: int) -> Optional[Dict[str, Any]]:
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("SELECT * FROM todos WHERE id = ?", (todo_id,))
    row = c.fetchone()
    conn.close()
    if row:
        return dict(row)
    return None

def toggle_todo_complete(todo_id: int) -> Optional[Dict[str, Any]]:
    conn = get_db_connection()
    c = conn.cursor()
    
    # Check if exists and get current status
    c.execute("SELECT completed FROM todos WHERE id = ?", (todo_id,))
    row = c.fetchone()
    
    if row is None:
        conn.close()
        return None
    
    new_status = 0 if row['completed'] else 1
    
    c.execute("UPDATE todos SET completed = ? WHERE id = ?", (new_status, todo_id))
    conn.commit()
    
    # Fetch updated
    c.execute("SELECT * FROM todos WHERE id = ?", (todo_id,))
    updated_row = c.fetchone()
    conn.close()
    
    return dict(updated_row)

def delete_todo(todo_id: int) -> bool:
    conn = get_db_connection()
    c = conn.cursor()
    c.execute("DELETE FROM todos WHERE id = ?", (todo_id,))
    rows_affected = c.rowcount
    conn.commit()
    conn.close()
    return rows_affected > 0
