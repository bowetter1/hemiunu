"""
Vesir Agent - Strategisk nedbrytning av stora uppgifter.

Vesir:
- Tar emot stort uppdrag från användare
- Analyserar kodbasen för att förstå kontext
- Bryter ner till atomära tasks med kontrakt
- Varje task måste ha CLI-test och max 7 testfall för full täckning

Regel: Vesir skriver INGEN kod, bara planerar.

Filosofi: Vi mäter verifierbarhet, inte storlek.
"""
from .base import BaseAgent
from infrastructure.db import TaskRepository, get_master
from infrastructure.llm.tools import read_file, list_files

# Verifierbarhetsgräns: max testfall för full täckning
MAX_TEST_CASES = 7
# Mjuk varning för storlek
LOC_WARNING = 150

# Vesir-specifika tools
VESIR_TOOLS = [
    {
        "name": "list_files",
        "description": "Lista filer i en katalog för att förstå kodbasen.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg till katalog (relativ till projekt-root)"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "read_file",
        "description": "Läs en fil för att förstå existerande kod.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Sökväg till fil (relativ till projekt-root)"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "create_subtask",
        "description": "Skapa en atomär subtask. Varje task måste ha CLI-test och vara verifierbar med max 7 testfall.",
        "input_schema": {
            "type": "object",
            "properties": {
                "description": {
                    "type": "string",
                    "description": "Tydlig beskrivning av vad som ska implementeras"
                },
                "cli_test": {
                    "type": "string",
                    "description": "CLI-kommando för att verifiera implementation (t.ex. 'python -m cli add 2 3')"
                },
                "input_schema": {
                    "type": "string",
                    "description": "Beskrivning av input (t.ex. 'Två heltal a, b')"
                },
                "output_schema": {
                    "type": "string",
                    "description": "Beskrivning av förväntad output (t.ex. 'Summan av a och b')"
                },
                "estimated_test_cases": {
                    "type": "integer",
                    "description": "Antal testfall för full täckning (max 7). Räkna: normalfall + edge cases + felhantering"
                },
                "dependencies": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista på tidigare task-beskrivningar som måste vara klara först"
                }
            },
            "required": ["description", "cli_test", "estimated_test_cases"]
        }
    },
    {
        "name": "reject_request",
        "description": "Avvisa uppdraget om det inte kan brytas ner till atomära tasks.",
        "input_schema": {
            "type": "object",
            "properties": {
                "reason": {
                    "type": "string",
                    "description": "Varför uppdraget inte kan genomföras"
                }
            },
            "required": ["reason"]
        }
    },
    {
        "name": "complete_breakdown",
        "description": "Markera att nedbrytningen är klar. Använd när alla subtasks är skapade.",
        "input_schema": {
            "type": "object",
            "properties": {
                "summary": {
                    "type": "string",
                    "description": "Sammanfattning av planen"
                },
                "total_tasks": {
                    "type": "integer",
                    "description": "Totalt antal tasks skapade"
                }
            },
            "required": ["summary", "total_tasks"]
        }
    }
]


class VesirAgent(BaseAgent):
    """
    Vesir-agent som bryter ner stora uppdrag till atomära tasks.
    """

    role = "vesir"

    def __init__(self, request: str, context: dict = None):
        """
        Args:
            request: Användarens stora uppdrag
            context: Extra kontext
        """
        # Skapa en pseudo-task för BaseAgent
        task = {
            "id": "vesir",
            "description": f"Bryt ner: {request[:100]}"
        }
        super().__init__(task, context)
        self.request = request
        self.created_tasks = []

    def get_tools(self) -> list:
        """Vesir har planerings-specifika tools."""
        return VESIR_TOOLS

    def get_system_prompt(self) -> str:
        """Bygg system-prompten för Vesir."""
        vision = self.context.get("vision", "Inget projekt definierat")
        existing_tasks = TaskRepository.get_all()

        existing_summary = "Inga existerande tasks."
        if existing_tasks:
            existing_summary = "\n".join([
                f"  - [{t['status']}] {t['description'][:50]}"
                for t in existing_tasks[:10]
            ])

        return f"""Du är en VESIR (strategisk rådgivare) i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

EXISTERANDE TASKS:
{existing_summary}

DIN ROLL:
Du tar emot stora uppdrag och bryter ner dem till ATOMÄRA TASKS.
Du skriver INGEN kod - du planerar bara.

VERIFIERBARHETSPRINCIPEN:
Vi mäter VERIFIERBARHET, inte storlek. En task är atomär om den kan
fullständigt testas med max {MAX_TEST_CASES} testfall.

REGLER FÖR VARJE TASK:
1. Max {MAX_TEST_CASES} testfall för full täckning (estimated_test_cases)
2. MÅSTE ha CLI-test som kan verifiera implementation
3. Tydlig input/output-specifikation
4. Oberoende eller tydliga dependencies

HUR RÄKNA TESTFALL:
- Normalfall (happy path): 1-2 testfall
- Edge cases (gränsvärden, tomma inputs): 1-3 testfall
- Felhantering (ogiltig input): 1-2 testfall
- Om summan > {MAX_TEST_CASES}: bryt ner ytterligare

STRATEGI:
1. Analysera kodbasen med list_files och read_file
2. Förstå vad som redan finns
3. Bryt ner uppdraget i logiska steg
4. Skapa tasks med create_subtask
5. Avsluta med complete_breakdown

EXEMPEL PÅ BRA TASK:
- Description: "Implementera is_prime(n) som returnerar True om n är primtal"
- CLI-test: "python -m cli prime 7" -> "True"
- Input: "Ett heltal n >= 2"
- Output: "True om n är primtal, annars False"
- Estimated test cases: 5 (normalfall: 2, edge: 2, fel: 1)

EXEMPEL PÅ DÅLIG TASK:
- "Bygg en webbserver med autentisering" (>20 testfall behövs)
- "Fixa buggen" (otydligt, kan inte räkna testfall)"""

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        return f"""UPPDRAG ATT BRYTA NER:

{self.request}

Börja med att analysera kodbasen för att förstå kontexten.
Skapa sedan atomära tasks med tydliga kontrakt."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett Vesir-tool."""

        if name == "list_files":
            return list_files(arguments)

        elif name == "read_file":
            return read_file(arguments)

        elif name == "create_subtask":
            # Validera estimated_test_cases (verifierbarhet)
            test_cases = arguments.get("estimated_test_cases", 0)
            if test_cases > MAX_TEST_CASES:
                return {
                    "success": False,
                    "error": f"Task är för komplex ({test_cases} testfall). Max är {MAX_TEST_CASES}. Bryt ner ytterligare."
                }

            if test_cases == 0:
                return {
                    "success": False,
                    "error": "Du måste uppskatta antal testfall (estimated_test_cases)."
                }

            # Skapa task i databasen
            task_id = TaskRepository.create(
                description=arguments["description"],
                cli_test=arguments["cli_test"]
            )

            task_info = {
                "id": task_id,
                "description": arguments["description"],
                "cli_test": arguments["cli_test"],
                "input_schema": arguments.get("input_schema"),
                "output_schema": arguments.get("output_schema"),
                "estimated_test_cases": test_cases,
                "dependencies": arguments.get("dependencies", [])
            }

            self.created_tasks.append(task_info)

            return {
                "success": True,
                "task_id": task_id,
                "message": f"Task skapad: {task_id} (verifierbar med {test_cases} testfall)"
            }

        elif name == "reject_request":
            return {
                "success": True,
                "action": "REJECT",
                "reason": arguments["reason"]
            }

        elif name == "complete_breakdown":
            return {
                "success": True,
                "action": "COMPLETE",
                "summary": arguments["summary"],
                "total_tasks": arguments["total_tasks"],
                "created_task_ids": [t["id"] for t in self.created_tasks]
            }

        else:
            return {"success": False, "error": f"Unknown tool: {name}"}

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
    vision = get_master() or "Inget projekt definierat"

    vesir = VesirAgent(request, context={"vision": vision})
    result = vesir.run()

    return result
