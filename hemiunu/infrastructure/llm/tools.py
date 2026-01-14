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


# Standard tool handlers
STANDARD_TOOLS = {
    "run_command": run_command,
    "read_file": read_file,
    "write_file": write_file,
    "list_files": list_files
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
    }
]
