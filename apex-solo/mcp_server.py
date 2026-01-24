#!/usr/bin/env python3
"""
Apex Solo - MCP Server

Minimal MCP server för Driver.
"""
import sys
import json
from tools import TOOLS, HANDLERS


def send(msg: dict):
    """Skicka JSON-RPC response."""
    print(json.dumps(msg), flush=True)


def main():
    """MCP server main loop."""
    for line in sys.stdin:
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue

        method = msg.get("method")
        msg_id = msg.get("id")
        params = msg.get("params", {})

        # Initialize
        if method == "initialize":
            send({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {"name": "apex-solo", "version": "1.0.0"},
                    "capabilities": {"tools": {}}
                }
            })

        # List tools
        elif method == "tools/list":
            send({
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"tools": TOOLS}
            })

        # Call tool
        elif method == "tools/call":
            name = params.get("name")
            args = params.get("arguments", {})

            if name in HANDLERS:
                try:
                    result = HANDLERS[name](args)
                    send({
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "result": {
                            "content": [{"type": "text", "text": str(result)}]
                        }
                    })
                except Exception as e:
                    send({
                        "jsonrpc": "2.0",
                        "id": msg_id,
                        "result": {
                            "content": [{"type": "text", "text": f"Error: {e}"}],
                            "isError": True
                        }
                    })
            else:
                send({
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {name}"}
                })

        # Notifications (no response needed)
        elif method in ("notifications/initialized", "notifications/cancelled"):
            pass

        # Unknown method
        elif msg_id is not None:
            send({
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Unknown method: {method}"}
            })


if __name__ == "__main__":
    main()
