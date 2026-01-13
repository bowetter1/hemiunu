"""
Hemiunu Tester Agent - Skriver oberoende tester och validerar Worker's kod.

Tester:
- Får en uppgift med beskrivning + Worker's CLI-test
- Skriver EGNA tester UTAN att se Worker's kod först
- Kör både Worker's CLI-test och egna tester
- Markerar med approve eller reject
"""
from .base import BaseAgent
from core.tools import run_command, read_file, write_file, list_files


# Tester-specifika tools
TESTER_TOOLS = [
    {
        "name": "run_command",
        "description": "Kör ett shell-kommando för att testa kod.",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Kommandot att köra"
                }
            },
            "required": ["command"]
        }
    },
    {
        "name": "read_file",
        "description": "Läs innehållet i en fil.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg relativt projektroten"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "write_file",
        "description": "Skriv tester till en fil.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg relativt projektroten"
                },
                "content": {
                    "type": "string",
                    "description": "Testinnehållet"
                }
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "list_files",
        "description": "Lista filer i en mapp.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg relativt projektroten"
                }
            },
            "required": []
        }
    },
    {
        "name": "approve",
        "description": "Godkänn Worker's implementation. Alla tester passerade.",
        "input_schema": {
            "type": "object",
            "properties": {
                "summary": {
                    "type": "string",
                    "description": "Kort sammanfattning av vad som testades"
                },
                "tests_passed": {
                    "type": "integer",
                    "description": "Antal tester som passerade"
                }
            },
            "required": ["summary", "tests_passed"]
        }
    },
    {
        "name": "reject",
        "description": "Avvisa Worker's implementation. Tester misslyckades.",
        "input_schema": {
            "type": "object",
            "properties": {
                "reason": {
                    "type": "string",
                    "description": "Varför testerna misslyckades"
                },
                "failed_tests": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista av misslyckade tester"
                }
            },
            "required": ["reason", "failed_tests"]
        }
    }
]


class TesterAgent(BaseAgent):
    """
    Tester-agent som validerar Worker's kod oberoende.

    VIKTIGT: Testaren ska skriva egna tester INNAN den ser Worker's kod.
    Detta säkerställer oberoende validering.
    """

    role = "tester"

    def __init__(self, task: dict, context: dict = None):
        super().__init__(task, context)
        # Spåra testfasen
        self.phase = "write_tests"  # write_tests -> run_tests -> verdict
        self.own_tests_path = None

    def get_tools(self) -> list:
        """Tester har specifika tools för testning."""
        return TESTER_TOOLS

    def get_system_prompt(self) -> str:
        """Bygg system-prompten för Tester."""
        vision = self.context.get("vision", "Inget projekt definierat")

        return f"""Du är en TESTER i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

DIN ROLL:
Du är en OBEROENDE testare. Din uppgift är att:
1. Skriva EGNA tester baserat på uppgiftsbeskrivningen
2. Köra Worker's CLI-test
3. Köra dina egna tester
4. Godkänna (approve) eller avvisa (reject) implementationen

VIKTIGT - OBEROENDE:
- Du ska skriva dina egna tester INNAN du tittar på Worker's kod
- Dina tester baseras på KONTRAKTET (vad koden SKA göra), inte implementationen
- Detta säkerställer att Worker inte bara testar sitt eget bias

ARBETSFLÖDE:
1. Läs uppgiftsbeskrivningen och förstå kontraktet
2. Skriv egna tester till tests/ mappen
3. Kör Worker's CLI-test
4. Kör dina egna tester
5. Om ALLA tester passerar: approve
6. Om NÅGOT test misslyckas: reject med feedback

Du är den sista kontrollen innan kod godkänns. Var noggrann!"""

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        cli_test = self.task.get("cli_test", "Inget Worker CLI-test")
        code_path = self.context.get("code_path", "Okänd sökväg")

        return f"""UPPGIFT ATT VALIDERA: {self.task['description']}

WORKER's CLI-TEST: {cli_test}

WORKER's KOD FINNS I: {code_path}

DIN UPPGIFT:
1. Skriv EGNA tester först (utan att läsa Worker's kod)
2. Kör Worker's CLI-test
3. Kör dina tester
4. Godkänn eller avvisa

Börja med att skriva dina egna tester baserat på uppgiftsbeskrivningen."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett Tester-tool."""
        if name == "run_command":
            return run_command(arguments["command"])
        elif name == "read_file":
            return read_file(arguments["path"])
        elif name == "write_file":
            result = write_file(arguments["path"], arguments["content"])
            # Spåra om det är en testfil
            if "test" in arguments["path"].lower():
                self.own_tests_path = arguments["path"]
            return result
        elif name == "list_files":
            return list_files(arguments.get("path", "."))
        elif name == "approve":
            return {
                "success": True,
                "action": "APPROVE",
                "summary": arguments["summary"],
                "tests_passed": arguments["tests_passed"]
            }
        elif name == "reject":
            return {
                "success": True,
                "action": "REJECT",
                "reason": arguments["reason"],
                "failed_tests": arguments["failed_tests"]
            }
        else:
            return {"success": False, "error": f"Unknown tool: {name}"}

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


if __name__ == "__main__":
    # Test
    print("Tester agent redo för Twin-Spawn.")
    print("Kör via orchestrator.py för full funktionalitet.")
