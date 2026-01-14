"""
MCP Adapter - Kopplar MCP-servrar till Claude API.

Konverterar FastMCP tools till Claude tool-format och
hanterar tool-execution.
"""
from typing import Callable
from fastmcp import FastMCP


def mcp_to_claude_tools(mcp_server: FastMCP) -> list[dict]:
    """
    Konvertera MCP-server tools till Claude API tool-format.

    Args:
        mcp_server: En FastMCP server-instans

    Returns:
        Lista av tool-definitioner i Claude API format
    """
    claude_tools = []

    for name, tool in mcp_server._tool_manager._tools.items():
        # Hämta tool-schema - kan vara dict eller Pydantic model
        if tool.parameters is None:
            schema = {"type": "object", "properties": {}}
        elif isinstance(tool.parameters, dict):
            schema = tool.parameters.copy()
        else:
            # Pydantic model
            schema = tool.parameters.model_json_schema()

        # Rensa bort interna fält
        if "title" in schema:
            del schema["title"]

        claude_tool = {
            "name": name,
            "description": tool.description or f"Tool: {name}",
            "input_schema": schema
        }
        claude_tools.append(claude_tool)

    return claude_tools


def create_tool_executor(mcp_server: FastMCP) -> Callable:
    """
    Skapa en tool-executor funktion för en MCP-server.

    Args:
        mcp_server: En FastMCP server-instans

    Returns:
        Funktion som tar (name, arguments) och returnerar resultat
    """
    tools = mcp_server._tool_manager._tools

    def execute(name: str, arguments: dict) -> dict:
        if name not in tools:
            return {"success": False, "error": f"Unknown tool: {name}"}

        tool = tools[name]
        try:
            # Anropa tool-funktionen
            result = tool.fn(**arguments)
            return result
        except Exception as e:
            return {"success": False, "error": str(e)}

    return execute


class MCPAdapter:
    """
    Adapter som kopplar en MCP-server till Claude API.

    Användning:
        adapter = MCPAdapter(create_worker_server())
        tools = adapter.get_claude_tools()
        result = adapter.execute("worker_write_file", {"path": "test.py", "content": "..."})
    """

    def __init__(self, mcp_server: FastMCP):
        self.server = mcp_server
        self._tools_cache = None
        self._executor = create_tool_executor(mcp_server)

    def get_claude_tools(self) -> list[dict]:
        """Hämta tools i Claude API format."""
        if self._tools_cache is None:
            self._tools_cache = mcp_to_claude_tools(self.server)
        return self._tools_cache

    def execute(self, name: str, arguments: dict) -> dict:
        """Exekvera ett tool."""
        return self._executor(name, arguments)

    @property
    def name(self) -> str:
        """Server-namn."""
        return self.server.name

    @property
    def instructions(self) -> str:
        """Server-instruktioner (för system prompt)."""
        # FastMCP använder 'instructions' property, inte '_instructions'
        return getattr(self.server, 'instructions', '') or ""
