"""
Master/Vision hantering.
"""
from typing import Optional
from .connection import get_connection


def set_master(vision: str):
    """Sätt projektets vision."""
    conn = get_connection()
    conn.execute(
        "INSERT OR REPLACE INTO master (id, vision) VALUES ('root', ?)",
        (vision,)
    )
    conn.commit()
    conn.close()


def get_master() -> Optional[str]:
    """Hämta projektets vision."""
    conn = get_connection()
    row = conn.execute("SELECT vision FROM master WHERE id = 'root'").fetchone()
    conn.close()
    return row["vision"] if row else None
