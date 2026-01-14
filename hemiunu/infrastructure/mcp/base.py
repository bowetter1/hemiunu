"""
Bas-funktionalitet för MCP-servrar.

Gemensamma verktyg och konfiguration.
"""
import subprocess
from pathlib import Path
from typing import Optional

# Projektrot för alla filoperationer
PROJECT_ROOT = Path(__file__).parent.parent.parent


def run_command(command: str, timeout: int = 60) -> dict:
    """
    Kör ett shell-kommando.

    Returns:
        dict med {success, stdout, stderr, returncode}
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
        return {"success": False, "error": f"Command timed out after {timeout}s"}
    except Exception as e:
        return {"success": False, "error": str(e)}


def read_file(path: str) -> dict:
    """
    Läs en fil.

    Returns:
        dict med {success, content, error}
    """
    try:
        full_path = PROJECT_ROOT / path
        if not full_path.exists():
            return {"success": False, "error": f"File not found: {path}"}
        content = full_path.read_text()
        return {"success": True, "content": content}
    except Exception as e:
        return {"success": False, "error": str(e)}


def write_file(path: str, content: str) -> dict:
    """
    Skriv till en fil.

    Returns:
        dict med {success, error}
    """
    try:
        full_path = PROJECT_ROOT / path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(content)
        return {"success": True, "path": path}
    except Exception as e:
        return {"success": False, "error": str(e)}


def list_files(path: str = ".") -> dict:
    """
    Lista filer i en katalog.

    Returns:
        dict med {success, files, error}
    """
    try:
        full_path = PROJECT_ROOT / path
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
