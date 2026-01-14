"""
Worker Agent - Skriver kod och testar via CLI.

Worker:
- Får en uppgift med beskrivning + CLI-test
- Skriver kod
- Testar via run_command
- Markerar med task_done, task_failed, eller split_task
"""
from .base import BaseAgent
from infrastructure.llm.tools import (
    run_command,
    read_file,
    write_file,
    list_files,
    STANDARD_TOOL_DEFINITIONS
)

# Worker-specifika tools (standard + action tools)
WORKER_TOOLS = STANDARD_TOOL_DEFINITIONS + [
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


class WorkerAgent(BaseAgent):
    """
    Worker-agent som skriver och testar kod.
    """

    role = "worker"

    def get_tools(self) -> list:
        """Worker har standard tools + action tools."""
        return WORKER_TOOLS

    def get_system_prompt(self) -> str:
        """Bygg system-prompten för Worker."""
        vision = self.context.get("vision", "Inget projekt definierat")

        return f"""Du är en WORKER i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

DIN ROLL:
Du skriver KOD och TESTAR den via CLI innan du markerar dig som klar.

VERIFIERBARHETSPRINCIPEN:
Uppgiften ska kunna verifieras med max 7 testfall. Om du märker att
fler testfall behövs för full täckning, använd split_task.

REGLER:
1. Om uppgiften kräver >7 testfall för full täckning: split_task
2. Använd run_command för att köra och testa din kod
3. När koden funkar, använd task_done
4. Om du inte kan lösa uppgiften, använd task_failed

ARBETSFLÖDE:
1. Läs uppgiftsbeskrivningen
2. Skriv koden med write_file
3. Testa med run_command (kör CLI-testet)
4. Om det funkar: task_done
5. Om det inte funkar: fixa och testa igen
6. Om för komplext (>7 testfall behövs): split_task

Du har tillgång till hela projektmappen. Skriv riktig, fungerande kod."""

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        cli_test = self.task.get("cli_test", "Inget specifikt test")

        return f"""UPPGIFT: {self.task['description']}

CLI-TEST: {cli_test}

Implementera denna uppgift. Skriv kod, testa den, och markera som klar."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett Worker-tool."""
        if name == "run_command":
            return run_command(arguments)
        elif name == "read_file":
            return read_file(arguments)
        elif name == "write_file":
            return write_file(arguments)
        elif name == "list_files":
            return list_files(arguments)
        elif name == "task_done":
            return {
                "success": True,
                "action": "DONE",
                "summary": arguments["summary"]
            }
        elif name == "task_failed":
            return {
                "success": True,
                "action": "FAILED",
                "reason": arguments["reason"]
            }
        elif name == "split_task":
            return {
                "success": True,
                "action": "SPLIT",
                "subtasks": arguments["subtasks"]
            }
        else:
            return {"success": False, "error": f"Unknown tool: {name}"}

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
