"""
Hemiunu Substrate - SQLite persistens
Minimal state för att AI ska kunna fortsätta där den slutade.
"""
import sqlite3
import json
from pathlib import Path
from datetime import datetime
from typing import Optional
import uuid

DB_PATH = Path(__file__).parent.parent / "hemiunu.db"


def get_connection():
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


# === MASTER ===

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


# === TASKS ===

def create_task(description: str, cli_test: str = None, parent_id: str = None) -> str:
    """Skapa en ny uppgift. Returnerar task_id."""
    task_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO tasks (id, parent_id, description, cli_test, status) VALUES (?, ?, ?, ?, 'TODO')",
        (task_id, parent_id, description, cli_test)
    )
    conn.commit()
    conn.close()
    return task_id


def get_task(task_id: str) -> Optional[dict]:
    """Hämta en uppgift."""
    conn = get_connection()
    row = conn.execute("SELECT * FROM tasks WHERE id = ?", (task_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_next_todo() -> Optional[dict]:
    """Hämta nästa TODO-uppgift."""
    conn = get_connection()
    row = conn.execute(
        "SELECT * FROM tasks WHERE status = 'TODO' ORDER BY created_at LIMIT 1"
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def get_tasks_by_status(status: str) -> list[dict]:
    """Hämta alla uppgifter med viss status."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM tasks WHERE status = ? ORDER BY created_at", (status,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def update_task(task_id: str, **kwargs):
    """Uppdatera en uppgift."""
    allowed = {"status", "worker_status", "tester_status", "branch", "code_path", "test_path", "error", "cli_test"}
    updates = {k: v for k, v in kwargs.items() if k in allowed}
    if not updates:
        return

    set_clause = ", ".join(f"{k} = ?" for k in updates.keys())
    values = list(updates.values()) + [task_id]

    conn = get_connection()
    conn.execute(f"UPDATE tasks SET {set_clause} WHERE id = ?", values)
    conn.commit()
    conn.close()


# === TEST RESULTS ===

def save_test_result(task_id: str, passed: bool, output: str, tester_tests: str = None) -> str:
    """Spara testresultat."""
    result_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO test_results (id, task_id, passed, output, tester_tests) VALUES (?, ?, ?, ?, ?)",
        (result_id, task_id, 1 if passed else 0, output, tester_tests)
    )
    conn.commit()
    conn.close()
    return result_id


def get_test_results(task_id: str) -> list[dict]:
    """Hämta alla testresultat för en task."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM test_results WHERE task_id = ? ORDER BY created_at DESC",
        (task_id,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def get_all_tasks() -> list[dict]:
    """Hämta alla uppgifter."""
    conn = get_connection()
    rows = conn.execute("SELECT * FROM tasks ORDER BY created_at").fetchall()
    conn.close()
    return [dict(row) for row in rows]


# === DEPLOY LOG ===

def save_deploy(branches: list, status: str, commit_hash: str = None, error: str = None) -> str:
    """Spara deploy-resultat."""
    deploy_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO deploy_log (id, branches, status, commit_hash, error) VALUES (?, ?, ?, ?, ?)",
        (deploy_id, json.dumps(branches), status, commit_hash, error)
    )
    conn.commit()
    conn.close()
    return deploy_id


def get_deploy_log(limit: int = 10) -> list[dict]:
    """Hämta senaste deploys."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM deploy_log ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


# === CONFLICTS ===

def save_conflict(branch_a: str, branch_b: str, file_path: str = None) -> str:
    """Spara en merge-konflikt."""
    conflict_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO conflicts (id, branch_a, branch_b, file_path) VALUES (?, ?, ?, ?)",
        (conflict_id, branch_a, branch_b, file_path)
    )
    conn.commit()
    conn.close()
    return conflict_id


def get_pending_conflicts() -> list[dict]:
    """Hämta olösta konflikter."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM conflicts WHERE status = 'PENDING' ORDER BY created_at"
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def resolve_conflict(conflict_id: str, resolution: str):
    """Markera konflikt som löst."""
    conn = get_connection()
    conn.execute(
        "UPDATE conflicts SET status = 'RESOLVED', resolution = ? WHERE id = ?",
        (resolution, conflict_id)
    )
    conn.commit()
    conn.close()


# Initiera DB vid import
init_db()


# === DEPLOY LOG ===

def save_deploy(branches: list, status: str, commit_hash: str = None, error: str = None) -> str:
    """Spara deploy-resultat."""
    deploy_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO deploy_log (id, branches, status, commit_hash, error) VALUES (?, ?, ?, ?, ?)",
        (deploy_id, json.dumps(branches), status, commit_hash, error)
    )
    conn.commit()
    conn.close()
    return deploy_id


def get_deploy_log(limit: int = 10) -> list[dict]:
    """Hämta senaste deploys."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM deploy_log ORDER BY created_at DESC LIMIT ?", (limit,)
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


# === CONFLICTS ===

def save_conflict(branch_a: str, branch_b: str, file_path: str = None) -> str:
    """Spara en merge-konflikt."""
    conflict_id = str(uuid.uuid4())[:8]
    conn = get_connection()
    conn.execute(
        "INSERT INTO conflicts (id, branch_a, branch_b, file_path) VALUES (?, ?, ?, ?)",
        (conflict_id, branch_a, branch_b, file_path)
    )
    conn.commit()
    conn.close()
    return conflict_id


def get_pending_conflicts() -> list[dict]:
    """Hämta olösta konflikter."""
    conn = get_connection()
    rows = conn.execute(
        "SELECT * FROM conflicts WHERE status = 'PENDING' ORDER BY created_at"
    ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def resolve_conflict(conflict_id: str, resolution: str):
    """Markera konflikt som löst."""
    conn = get_connection()
    conn.execute(
        "UPDATE conflicts SET status = 'RESOLVED', resolution = ? WHERE id = ?",
        (resolution, conflict_id)
    )
    conn.commit()
    conn.close()


if __name__ == "__main__":
    # Test
    print("Testing db.py...")
    set_master("Test-projekt för primtalsberäkning")
    print(f"Master: {get_master()}")

    task_id = create_task(
        description="Implementera is_prime(n)",
        cli_test="python -m cli prime 7"
    )
    print(f"Created task: {task_id}")
    print(f"Task: {get_task(task_id)}")
    print(f"Next TODO: {get_next_todo()}")
