"""
MCP Vesir Agent - Strategisk planering med MCP-server.

Har tillgång till:
- vesir_read_file, vesir_list_files (läsa kodbasen)
- create_subtask, reject_request, complete_breakdown (planering)

Har INTE tillgång till:
- write_file (Vesir skriver ALDRIG kod)
- run_command (ingen exekvering)
"""
from .mcp_base import MCPAgent
from infrastructure.mcp.vesir_server import create_vesir_server


class MCPVesirAgent(MCPAgent):
    """
    Vesir-agent som bryter ner stora uppdrag till atomära tasks.

    REGEL: Vesir skriver INGEN kod, bara planerar.
    """

    role = "vesir"

    def __init__(self, request: str, context: dict = None):
        """
        Args:
            request: Användarens stora uppdrag
            context: Extra kontext
        """
        # Skapa en pseudo-task för MCPAgent
        task = {
            "id": "vesir",
            "description": f"Bryt ner: {request[:100]}"
        }
        super().__init__(task, context)
        self.request = request
        self.created_tasks = []

    def create_mcp_server(self):
        """Skapa Vesir MCP-server."""
        return create_vesir_server()

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        return f"""UPPDRAG ATT BRYTA NER:

{self.request}

Börja med att analysera kodbasen med vesir_list_files och vesir_read_file.
Skapa sedan atomära tasks med create_subtask.
Avsluta med complete_breakdown när alla tasks är skapade."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera tool och spåra skapade tasks."""
        result = super().execute_tool(name, arguments)

        # Spåra skapade tasks
        if name == "create_subtask" and result.get("success"):
            self.created_tasks.append(result.get("task"))

        return result

    def handle_completion(self, result: dict):
        """Hantera complete/reject."""
        action = result.get("action")

        if action == "COMPLETE":
            return {
                "status": "completed",
                "result": {
                    "summary": result.get("summary"),
                    "total_tasks": result.get("total_tasks"),
                    "tasks": self.created_tasks
                },
                "error": None
            }
        elif action == "REJECT":
            return {
                "status": "rejected",
                "result": None,
                "error": result.get("reason")
            }

        return None


def break_down_request(request: str) -> dict:
    """
    Hjälpfunktion för att bryta ner ett stort uppdrag.

    Args:
        request: Användarens uppdrag

    Returns:
        dict med {status, tasks, error}
    """
    from infrastructure.db import get_master

    vision = get_master() or "Inget projekt definierat"

    vesir = MCPVesirAgent(request, context={"vision": vision})
    result = vesir.run()

    return result
