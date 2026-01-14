"""
MCP Integrator Agent - Merge-konfliktlösning med MCP-server.

Har tillgång till:
- read_conflict, read_branch_version
- resolve_conflict, use_ours, use_theirs
- complete_resolution, abort_resolution

Har INTE tillgång till:
- write_file (kan inte skriva godtyckliga filer)
- run_command (ingen exekvering)
"""
from .mcp_base import MCPAgent
from infrastructure.mcp.integrator_server import create_integrator_server


class MCPIntegratorAgent(MCPAgent):
    """
    Integratör-agent som löser merge-konflikter.
    """

    role = "integrator"

    def __init__(self, conflict: dict, context: dict = None):
        """
        Args:
            conflict: Konfliktinfo med {branch_a, branch_b, conflict_files}
            context: Extra kontext
        """
        # Skapa en pseudo-task för MCPAgent
        task = {
            "id": conflict.get("id", "unknown"),
            "description": f"Lös konflikt mellan {conflict['branch_a']} och {conflict['branch_b']}"
        }
        super().__init__(task, context)
        self.conflict = conflict
        self.resolved_files = []

    def create_mcp_server(self):
        """Skapa Integrator MCP-server."""
        return create_integrator_server()

    def get_system_prompt(self) -> str:
        """Bygg system-prompt med konfliktinfo."""
        base_prompt = super().get_system_prompt()

        conflict_info = f"""
KONFLIKT ATT LÖSA:
- Branch A (main): {self.conflict['branch_a']}
- Branch B (feature): {self.conflict['branch_b']}
- Filer med konflikt: {', '.join(self.conflict.get('conflict_files', []))}
"""
        return base_prompt + conflict_info

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        files = self.conflict.get("conflict_files", [])

        return f"""MERGE-KONFLIKT att lösa:

Branch A (main): {self.conflict['branch_a']}
Branch B (feature): {self.conflict['branch_b']}

Filer med konflikt ({len(files)} st):
{chr(10).join(f'  - {f}' for f in files)}

Analysera konfliktfilerna med read_conflict och lös dem en i taget.
Avsluta med complete_resolution när alla är lösta."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera tool och spåra lösta filer."""
        result = super().execute_tool(name, arguments)

        # Spåra lösta filer
        if name in ["resolve_conflict", "use_ours", "use_theirs"]:
            if result.get("success"):
                file_path = arguments.get("file_path")
                if file_path and file_path not in self.resolved_files:
                    self.resolved_files.append(file_path)

        return result

    def handle_completion(self, result: dict):
        """Hantera complete/abort."""
        action = result.get("action")

        if action == "COMPLETE":
            return {
                "status": "resolved",
                "result": {
                    "summary": result.get("summary"),
                    "commit_hash": result.get("commit_hash"),
                    "resolved_files": self.resolved_files
                },
                "error": None
            }
        elif action == "ABORT":
            return {
                "status": "aborted",
                "result": None,
                "error": result.get("reason")
            }

        return None
