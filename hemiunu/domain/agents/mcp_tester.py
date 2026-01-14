"""
MCP Tester Agent - Tester som använder MCP-server för tools.

Har tillgång till:
- tester_read_file, tester_run_command, tester_list_files
- write_test_file (endast tests/-mappen)
- approve, reject

Har INTE tillgång till:
- worker_write_file (kan inte skriva produktionskod)
- task_done, task_failed, split_task (Workers tools)
"""
from .mcp_base import MCPAgent
from infrastructure.mcp.tester_server import create_tester_server


class MCPTesterAgent(MCPAgent):
    """
    Tester-agent som använder MCP-server för rollseparation.

    VIKTIGT: Testaren ska skriva egna tester INNAN den ser Worker's kod.
    """

    role = "tester"

    def __init__(self, task: dict, context: dict = None):
        super().__init__(task, context)
        self.own_tests_path = None

    def create_mcp_server(self):
        """Skapa Tester MCP-server."""
        return create_tester_server()

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        cli_test = self.task.get("cli_test", "Inget Worker CLI-test")
        code_path = self.context.get("code_path", "src/")

        return f"""UPPGIFT ATT VALIDERA: {self.task['description']}

WORKER's CLI-TEST: {cli_test}

WORKER's KOD FINNS I: {code_path}

DIN UPPGIFT:
1. Skriv EGNA tester först med write_test_file (utan att läsa Worker's kod)
2. Kör Worker's CLI-test med tester_run_command
3. Kör dina egna tester
4. Godkänn med approve eller avvisa med reject

Börja med att skriva dina egna tester baserat på uppgiftsbeskrivningen."""

    def handle_completion(self, result: dict):
        """Hantera approve/reject."""
        action = result.get("action")

        if action == "APPROVE":
            return {
                "status": "approved",
                "result": {
                    "summary": result.get("summary"),
                    "tests_passed": result.get("tests_passed"),
                    "test_path": self.own_tests_path
                },
                "error": None
            }
        elif action == "REJECT":
            return {
                "status": "rejected",
                "result": {
                    "reason": result.get("reason"),
                    "failed_tests": result.get("failed_tests"),
                    "test_path": self.own_tests_path
                },
                "error": result.get("reason")
            }

        return None  # Fortsätt
