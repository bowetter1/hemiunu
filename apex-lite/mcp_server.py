#!/usr/bin/env python3
"""
Apex Lite - MCP Server

Enkel MCP-server som exponerar tools till Boss (Claude).
"""
import json
import sys
import os

from tools import TOOLS, HANDLERS


def handle_request(request: dict, cwd: str) -> dict | None:
    """Hantera en MCP-request."""
    method = request.get("method")
    req_id = request.get("id")
    params = request.get("params", {})

    # Notifications (inget svar)
    if method in ["notifications/initialized", "notifications/cancelled"]:
        return None

    # Initialize
    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "apex-lite", "version": "1.0.0"}
            }
        }

    # List tools
    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS}
        }

    # Call tool
    if method == "tools/call":
        name = params.get("name")
        arguments = params.get("arguments", {})

        handler = HANDLERS.get(name)
        if handler:
            result = handler(arguments, cwd)
        else:
            result = {"content": [{"type": "text", "text": f"Okänt tool: {name}"}]}

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": result
        }

    # Okänd metod
    return {
        "jsonrpc": "2.0",
        "id": req_id,
        "error": {"code": -32601, "message": f"Okänd metod: {method}"}
    }


def get_project_dir() -> str:
    """Hämta projektmappen från .current_project eller env."""
    from pathlib import Path
    marker = Path(__file__).parent / ".current_project"
    if marker.exists():
        return marker.read_text().strip()
    return os.environ.get("PROJECT_DIR", os.getcwd())


def ensure_log_file(cwd: str):
    """Skapa loggfil om den inte finns."""
    from pathlib import Path
    log_path = Path(cwd) / "sprint.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if not log_path.exists():
        log_path.touch()
    # Skriv startup-meddelande
    from datetime import datetime
    timestamp = datetime.now().strftime("%H:%M:%S")
    with open(log_path, "a") as f:
        f.write(f"[{timestamp}] [STARTUP] MCP Server startad - cwd: {cwd}\n")


def main():
    """MCP server main loop."""
    cwd = get_project_dir()
    ensure_log_file(cwd)
    sys.stderr.write(f"[APEX-LITE] Project: {cwd}\n")
    sys.stderr.flush()

    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break

            line = line.strip()
            if not line:
                continue

            request = json.loads(line)
            response = handle_request(request, cwd)

            if response:
                print(json.dumps(response), flush=True)

        except json.JSONDecodeError as e:
            sys.stderr.write(f"JSON error: {e}\n")
            sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"Error: {e}\n")
            sys.stderr.flush()


if __name__ == "__main__":
    main()
