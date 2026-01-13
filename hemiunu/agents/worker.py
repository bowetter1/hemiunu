"""
Hemiunu Worker Agent - Skriver kod och testar via CLI.

Worker:
- Får en uppgift med beskrivning + CLI-test
- Skriver kod
- Testar via run_command
- Markerar med task_done, task_failed, eller split_task
"""
from .base import BaseAgent
from core.tools import (
    run_command,
    read_file,
    write_file,
    list_files,
    TOOL_DEFINITIONS
)


class WorkerAgent(BaseAgent):
    """
    Worker-agent som skriver och testar kod.
    """

    role = "worker"

    def get_tools(self) -> list:
        """Worker har alla bas-tools."""
        return TOOL_DEFINITIONS

    def get_system_prompt(self) -> str:
        """Bygg system-prompten för Worker."""
        vision = self.context.get("vision", "Inget projekt definierat")

        return f"""Du är en WORKER i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

DIN ROLL:
Du skriver KOD och TESTAR den via CLI innan du markerar dig som klar.

REGLER:
1. Varje modul ska vara max 150 rader
2. Om uppgiften är för komplex, använd split_task för att dela upp den
3. Använd run_command för att köra och testa din kod
4. När koden funkar, använd task_done
5. Om du inte kan lösa uppgiften, använd task_failed

ARBETSFLÖDE:
1. Läs uppgiftsbeskrivningen
2. Skriv koden med write_file
3. Testa med run_command (kör CLI-testet)
4. Om det funkar: task_done
5. Om det inte funkar: fixa och testa igen
6. Om för komplext: split_task

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
            return run_command(arguments["command"])
        elif name == "read_file":
            return read_file(arguments["path"])
        elif name == "write_file":
            return write_file(arguments["path"], arguments["content"])
        elif name == "list_files":
            return list_files(arguments.get("path", "."))
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


if __name__ == "__main__":
    # Test
    from substrate.db import get_master, get_next_todo

    task = get_next_todo()
    if task:
        print(f"Testar Worker på: {task['description']}")
        vision = get_master() or "Testprojekt"
        worker = WorkerAgent(task, context={"vision": vision})
        result = worker.run()
        print(f"Resultat: {result}")
    else:
        print("Inga uppgifter att testa.")
