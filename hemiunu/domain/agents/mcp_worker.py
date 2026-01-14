"""
MCP Worker Agent - Worker som använder MCP-server för tools.

Har tillgång till:
- worker_write_file, worker_read_file, worker_run_command, worker_list_files
- task_done, task_failed, split_task

Har INTE tillgång till:
- approve, reject (Testers tools)
"""
from .mcp_base import MCPAgent
from infrastructure.mcp.worker_server import create_worker_server


class MCPWorkerAgent(MCPAgent):
    """
    Worker-agent som använder MCP-server för rollseparation.
    """

    role = "worker"

    def create_mcp_server(self):
        """Skapa Worker MCP-server."""
        return create_worker_server()

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        cli_test = self.task.get("cli_test", "Inget specifikt test")

        return f"""UPPGIFT: {self.task['description']}

CLI-TEST: {cli_test}

Implementera denna uppgift. Skriv kod, testa den, och markera som klar med task_done."""

    def handle_completion(self, result: dict):
        """Hantera avslutande actions."""
        action = result.get("action")

        if action == "DONE":
            return {
                "status": "done",
                "result": result.get("summary"),
                "error": None
            }
        elif action == "FAILED":
            return {
                "status": "failed",
                "result": None,
                "error": result.get("reason")
            }
        elif action == "SPLIT":
            return {
                "status": "split",
                "result": result.get("subtasks"),
                "error": None
            }

        return None  # Fortsätt
