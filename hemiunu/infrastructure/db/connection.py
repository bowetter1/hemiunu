"""
Databasanslutning och schema.
"""
import sqlite3
from pathlib import Path

# Databas ligger i projekt-root
DB_PATH = Path(__file__).parent.parent.parent / "hemiunu.db"


def get_connection():
    """Hämta en databasanslutning."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    """Skapa tabeller om de inte finns."""
    conn = get_connection()
    conn.executescript("""
        -- Master: Projektets DNA
        CREATE TABLE IF NOT EXISTS master (
            id TEXT PRIMARY KEY DEFAULT 'root',
            vision TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- Tasks: Alla uppgifter
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            parent_id TEXT,
            description TEXT NOT NULL,
            cli_test TEXT,
            status TEXT DEFAULT 'TODO',
            worker_status TEXT,
            tester_status TEXT,
            branch TEXT,
            code_path TEXT,
            test_path TEXT,
            error TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (parent_id) REFERENCES tasks(id)
        );

        -- Test Results: Resultat från Testare
        CREATE TABLE IF NOT EXISTS test_results (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            passed INTEGER NOT NULL,
            output TEXT,
            tester_tests TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (task_id) REFERENCES tasks(id)
        );

        -- Deploy Log: Historik över deploy-cykler
        CREATE TABLE IF NOT EXISTS deploy_log (
            id TEXT PRIMARY KEY,
            branches TEXT NOT NULL,
            status TEXT NOT NULL,
            commit_hash TEXT,
            error TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- Conflicts: Merge-konflikter att lösa
        CREATE TABLE IF NOT EXISTS conflicts (
            id TEXT PRIMARY KEY,
            branch_a TEXT NOT NULL,
            branch_b TEXT NOT NULL,
            file_path TEXT,
            status TEXT DEFAULT 'PENDING',
            resolution TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    conn.close()
