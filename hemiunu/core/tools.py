"""
Hemiunu Tools - Verktyg som AI kan använda.
Dessa exponeras som "tools" till Claude API.
"""
import subprocess
import os
from pathlib import Path
from typing import Optional

# Projektrot
PROJECT_ROOT = Path(__file__).parent.parent


def run_command(command: str, timeout: int = 60) -> dict:
    """
    Kör ett shell-kommando.
    Returnerar {success, stdout, stderr, returncode}
    """
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
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Command timed out after {timeout}s",
            "returncode": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }


def read_file(path: str) -> dict:
    """
    Läs en fil.
    Returnerar {success, content, error}
    """
    try:
        full_path = PROJECT_ROOT / path
        with open(full_path, "r") as f:
            content = f.read()
        return {"success": True, "content": content, "error": None}
    except Exception as e:
        return {"success": False, "content": None, "error": str(e)}


def write_file(path: str, content: str) -> dict:
    """
    Skriv till en fil. Skapar mappar om de saknas.
    Returnerar {success, error}
    """
    try:
        full_path = PROJECT_ROOT / path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        with open(full_path, "w") as f:
            f.write(content)
        return {"success": True, "error": None}
    except Exception as e:
        return {"success": False, "error": str(e)}


def list_files(path: str = ".") -> dict:
    """
    Lista filer i en mapp.
    Returnerar {success, files, error}
    """
    try:
        full_path = PROJECT_ROOT / path
        files = []
        for item in full_path.iterdir():
            files.append({
                "name": item.name,
                "is_dir": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else 0
            })
        return {"success": True, "files": files, "error": None}
    except Exception as e:
        return {"success": False, "files": [], "error": str(e)}


# Tool-definitioner för Claude API
TOOL_DEFINITIONS = [
    {
        "name": "run_command",
        "description": "Kör ett shell-kommando (bash). Använd för att testa kod, köra git, etc.",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Kommandot att köra"
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
                    "description": "Sökväg relativt projektroten"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "write_file",
        "description": "Skriv innehåll till en fil. Skapar filen om den inte finns.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg relativt projektroten"
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
        "description": "Lista filer i en mapp.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg relativt projektroten (default: .)"
                }
            },
            "required": []
        }
    },
    {
        "name": "task_done",
        "description": "Markera uppgiften som klar. Anropa detta när du har implementerat och testat koden.",
        "input_schema": {
            "type": "object",
            "properties": {
                "summary": {
                    "type": "string",
                    "description": "Kort sammanfattning av vad du gjorde"
                }
            },
            "required": ["summary"]
        }
    },
    {
        "name": "task_failed",
        "description": "Markera uppgiften som misslyckad. Anropa om du inte kan lösa uppgiften.",
        "input_schema": {
            "type": "object",
            "properties": {
                "reason": {
                    "type": "string",
                    "description": "Varför uppgiften misslyckades"
                }
            },
            "required": ["reason"]
        }
    },
    {
        "name": "split_task",
        "description": "Dela upp uppgiften i mindre delar. Anropa om uppgiften är för komplex.",
        "input_schema": {
            "type": "object",
            "properties": {
                "subtasks": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "description": {"type": "string"},
                            "cli_test": {"type": "string"}
                        },
                        "required": ["description", "cli_test"]
                    },
                    "description": "Lista av sub-uppgifter"
                }
            },
            "required": ["subtasks"]
        }
    }
]


def execute_tool(name: str, arguments: dict) -> dict:
    """Exekvera ett tool och returnera resultatet."""
    if name == "run_command":
        return run_command(arguments["command"])
    elif name == "read_file":
        return read_file(arguments["path"])
    elif name == "write_file":
        return write_file(arguments["path"], arguments["content"])
    elif name == "list_files":
        return list_files(arguments.get("path", "."))
    elif name == "task_done":
        return {"success": True, "action": "DONE", "summary": arguments["summary"]}
    elif name == "task_failed":
        return {"success": True, "action": "FAILED", "reason": arguments["reason"]}
    elif name == "split_task":
        return {"success": True, "action": "SPLIT", "subtasks": arguments["subtasks"]}
    else:
        return {"success": False, "error": f"Unknown tool: {name}"}


if __name__ == "__main__":
    # Test
    print("Testing tools.py...")

    # Test run_command
    result = run_command("echo 'Hello World'")
    print(f"run_command: {result}")

    # Test write_file
    result = write_file("test_output.txt", "Test content")
    print(f"write_file: {result}")

    # Test read_file
    result = read_file("test_output.txt")
    print(f"read_file: {result}")

    # Test list_files
    result = list_files(".")
    print(f"list_files: {result}")

    # Cleanup
    run_command("rm test_output.txt")
