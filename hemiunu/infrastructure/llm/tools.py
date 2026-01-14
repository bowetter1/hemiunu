"""
Tool execution för LLM.
"""
import subprocess
from pathlib import Path
from typing import Callable

# Project root för filoperationer
PROJECT_ROOT = Path(__file__).parent.parent.parent


def execute_tool(name: str, arguments: dict, tool_handlers: dict) -> dict:
    """
    Exekvera ett tool.

    Args:
        name: Tool-namn
        arguments: Tool-argument
        tool_handlers: Dict med {tool_name: handler_function}

    Returns:
        Tool-resultat som dict
    """
    if name not in tool_handlers:
        return {"success": False, "error": f"Unknown tool: {name}"}

    try:
        handler = tool_handlers[name]
        return handler(arguments)
    except Exception as e:
        return {"success": False, "error": str(e)}


def format_tool_result(tool_id: str, result: dict) -> dict:
    """
    Formatera tool-resultat för Claude API.

    Args:
        tool_id: Tool-anrop ID
        result: Resultat från tool

    Returns:
        Formaterat meddelande för API
    """
    import json
    return {
        "role": "user",
        "content": [{
            "type": "tool_result",
            "tool_use_id": tool_id,
            "content": json.dumps(result, ensure_ascii=False, indent=2)
        }]
    }


# === Standard Tools ===

def run_command(arguments: dict) -> dict:
    """Kör ett shell-kommando."""
    command = arguments.get("command", "")
    timeout = arguments.get("timeout", 30)

    try:
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=PROJECT_ROOT
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": f"Command timed out after {timeout}s"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def read_file(arguments: dict) -> dict:
    """Läs en fil."""
    path = arguments.get("path", "")
    full_path = PROJECT_ROOT / path

    try:
        if not full_path.exists():
            return {"success": False, "error": f"File not found: {path}"}
        content = full_path.read_text()
        return {"success": True, "content": content}
    except Exception as e:
        return {"success": False, "error": str(e)}


def write_file(arguments: dict) -> dict:
    """Skriv till en fil."""
    path = arguments.get("path", "")
    content = arguments.get("content", "")
    full_path = PROJECT_ROOT / path

    try:
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(content)
        return {"success": True, "error": None}
    except Exception as e:
        return {"success": False, "error": str(e)}


def list_files(arguments: dict) -> dict:
    """Lista filer i en katalog."""
    path = arguments.get("path", ".")
    full_path = PROJECT_ROOT / path

    try:
        if not full_path.exists():
            return {"success": False, "error": f"Directory not found: {path}"}

        files = []
        for item in full_path.iterdir():
            if item.name.startswith('.'):
                continue
            files.append({
                "name": item.name,
                "is_dir": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else 0
            })

        return {"success": True, "files": files}
    except Exception as e:
        return {"success": False, "error": str(e)}


# === SQLite Tools ===

def db_execute(arguments: dict) -> dict:
    """Kör SQL mot en SQLite-databas."""
    import sqlite3

    db_path = arguments.get("db_path", "app.db")
    sql = arguments.get("sql", "")
    params = arguments.get("params", [])

    full_path = PROJECT_ROOT / db_path

    try:
        # Skapa mapp om den inte finns
        full_path.parent.mkdir(parents=True, exist_ok=True)

        conn = sqlite3.connect(full_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute(sql, params)

        # Om det är en SELECT, returnera rader
        if sql.strip().upper().startswith("SELECT"):
            rows = cursor.fetchall()
            result = [dict(row) for row in rows]
            conn.close()
            return {"success": True, "rows": result, "count": len(result)}
        else:
            conn.commit()
            affected = cursor.rowcount
            conn.close()
            return {"success": True, "affected_rows": affected}

    except Exception as e:
        return {"success": False, "error": str(e)}


def db_schema(arguments: dict) -> dict:
    """Visa schema för en SQLite-databas."""
    import sqlite3

    db_path = arguments.get("db_path", "app.db")
    full_path = PROJECT_ROOT / db_path

    try:
        if not full_path.exists():
            return {"success": False, "error": f"Database not found: {db_path}"}

        conn = sqlite3.connect(full_path)
        cursor = conn.cursor()

        # Hämta alla tabeller
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        tables = [row[0] for row in cursor.fetchall()]

        # Hämta schema för varje tabell
        schema = {}
        for table in tables:
            cursor.execute(f"PRAGMA table_info({table})")
            columns = [{
                "name": row[1],
                "type": row[2],
                "nullable": not row[3],
                "primary_key": bool(row[5])
            } for row in cursor.fetchall()]
            schema[table] = columns

        conn.close()
        return {"success": True, "tables": tables, "schema": schema}

    except Exception as e:
        return {"success": False, "error": str(e)}


# === Codebase Index Tools ===

def codebase_summary(arguments: dict) -> dict:
    """Hämta sammanfattning av kodbasen."""
    from infrastructure.codebase import get_project_summary
    try:
        summary = get_project_summary()
        return {"success": True, "summary": summary}
    except Exception as e:
        return {"success": False, "error": str(e)}


def codebase_search(arguments: dict) -> dict:
    """Sök efter funktioner eller klasser i kodbasen."""
    from infrastructure.codebase import find_function, find_class

    query = arguments.get("query", "")
    search_type = arguments.get("type", "all")  # "function", "class", eller "all"

    if not query:
        return {"success": False, "error": "Du måste ange en sökterm (query)"}

    try:
        results = {"functions": [], "classes": []}

        if search_type in ["function", "all"]:
            results["functions"] = find_function(query)

        if search_type in ["class", "all"]:
            results["classes"] = find_class(query)

        total = len(results["functions"]) + len(results["classes"])
        return {
            "success": True,
            "query": query,
            "total_matches": total,
            "results": results
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def codebase_file_info(arguments: dict) -> dict:
    """Hämta information om en specifik fil."""
    from infrastructure.codebase import get_file_summary

    path = arguments.get("path", "")
    if not path:
        return {"success": False, "error": "Du måste ange en sökväg (path)"}

    try:
        info = get_file_summary(path)
        if info is None:
            return {"success": False, "error": f"Filen finns inte i indexet: {path}"}
        return {"success": True, "path": path, "info": info}
    except Exception as e:
        return {"success": False, "error": str(e)}


# Standard tool handlers
STANDARD_TOOLS = {
    "run_command": run_command,
    "read_file": read_file,
    "write_file": write_file,
    "list_files": list_files,
    "db_execute": db_execute,
    "db_schema": db_schema,
    "codebase_summary": codebase_summary,
    "codebase_search": codebase_search,
    "codebase_file_info": codebase_file_info
}


# Tool definitions för Claude API
STANDARD_TOOL_DEFINITIONS = [
    {
        "name": "run_command",
        "description": "Kör ett shell-kommando.",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Kommandot att köra"
                },
                "timeout": {
                    "type": "integer",
                    "description": "Timeout i sekunder (default 30)"
                }
            },
            "required": ["command"]
        }
    },
    {
        "name": "read_file",
        "description": "Läs innehållet i en fil.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg till filen"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "write_file",
        "description": "Skriv innehåll till en fil.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg till filen"
                },
                "content": {
                    "type": "string",
                    "description": "Innehållet att skriva"
                }
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "list_files",
        "description": "Lista filer i en katalog.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg till katalogen"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "db_execute",
        "description": "Kör SQL mot en SQLite-databas. Skapar databasen automatiskt om den inte finns. Använd för CREATE TABLE, INSERT, UPDATE, DELETE, SELECT.",
        "input_schema": {
            "type": "object",
            "properties": {
                "db_path": {
                    "type": "string",
                    "description": "Sökväg till databasen (t.ex. 'data/app.db')"
                },
                "sql": {
                    "type": "string",
                    "description": "SQL-sats att köra"
                },
                "params": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Parametrar för prepared statement (optional)"
                }
            },
            "required": ["db_path", "sql"]
        }
    },
    {
        "name": "db_schema",
        "description": "Visa schema för en SQLite-databas. Visar alla tabeller och deras kolumner.",
        "input_schema": {
            "type": "object",
            "properties": {
                "db_path": {
                    "type": "string",
                    "description": "Sökväg till databasen"
                }
            },
            "required": ["db_path"]
        }
    },
    {
        "name": "codebase_summary",
        "description": "Hämta en sammanfattning av kodbasen: antal filer, funktioner, klasser, och de viktigaste modulerna. Använd detta FÖRST för att förstå projektets struktur.",
        "input_schema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "codebase_search",
        "description": "Sök efter funktioner eller klasser i kodbasen. Returnerar filsökväg, namn, och signatur för matchningar.",
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Sökterm (t.ex. 'add', 'User', 'test')"
                },
                "type": {
                    "type": "string",
                    "enum": ["function", "class", "all"],
                    "description": "Typ av sökning: 'function', 'class', eller 'all' (default)"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "codebase_file_info",
        "description": "Hämta detaljerad information om en specifik fil: funktioner, klasser, imports, och docstrings.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Relativ sökväg till filen (t.ex. 'domain/agents/worker.py')"
                }
            },
            "required": ["path"]
        }
    }
]
