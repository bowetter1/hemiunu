#!/usr/bin/env python3
"""
MCP Server - AI Team för Opus (Chef Edition)

Tunn wrapper som hanterar MCP-protokollet.
All tool-logik finns i tools/-modulerna.
"""
import json
import sys
import os

# Lägg till apex-katalogen i path för tools-import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from tools import ALL_TOOLS, ALL_HANDLERS
from tools.files import get_project_dir
from tools.base import log_to_sprint


def handle_list_tools() -> dict:
    """Returnera alla tillgängliga tools."""
    return {"tools": ALL_TOOLS}


def handle_call_tool(name: str, arguments: dict, cwd: str) -> dict:
    """Kör ett tool."""
    # Använd dynamisk projektmapp om satt
    actual_cwd = get_project_dir(cwd)
    log_to_sprint(actual_cwd, f"🔧 {name} anropat med {arguments}")

    handler = ALL_HANDLERS.get(name)
    if handler:
        return handler(arguments, actual_cwd)
    else:
        return {"content": [{"type": "text", "text": f"Okänt tool: {name}"}]}


def main():
    """MCP server main loop."""
    cwd = os.environ.get("PROJECT_DIR", os.getcwd())

    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break

            line = line.strip()
            if not line:
                continue

            request = json.loads(line)
            method = request.get("method")
            req_id = request.get("id")
            params = request.get("params", {})

            # Notifications (no response)
            if method in ["notifications/initialized", "notifications/cancelled"]:
                continue

            # Handle requests
            if method == "initialize":
                result = {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {"listChanged": False}},
                    "serverInfo": {"name": "apex-agents", "version": "2.0.0"}
                }
            elif method == "tools/list":
                result = handle_list_tools()
            elif method == "tools/call":
                result = handle_call_tool(
                    params.get("name"),
                    params.get("arguments", {}),
                    cwd
                )
            else:
                error = {"code": -32601, "message": f"Method not found: {method}"}
                response = {"jsonrpc": "2.0", "id": req_id, "error": error}
                print(json.dumps(response), flush=True)
                continue

            response = {"jsonrpc": "2.0", "id": req_id, "result": result}
            print(json.dumps(response), flush=True)

        except json.JSONDecodeError as e:
            sys.stderr.write(f"JSON decode error: {e}\n")
            sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"Error: {e}\n")
            sys.stderr.flush()
            if 'req_id' in locals():
                error = {"code": -32000, "message": str(e)}
                response = {"jsonrpc": "2.0", "id": req_id, "error": error}
                print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
