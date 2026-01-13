"""
Hemiunu Integrator Agent - Löser merge-konflikter.

Integratör:
- Får information om två branches med konflikt
- Ser innehållet från båda sidor
- Beslutar hur konflikten ska lösas
- Kan välja: ours, theirs, eller manuell merge
"""
from .base import BaseAgent
from core.git import (
    get_conflict_content,
    get_file_from_branch,
    resolve_file_conflict,
    abort_merge,
    complete_merge
)
from core.tools import read_file


# Integrator-specifika tools
INTEGRATOR_TOOLS = [
    {
        "name": "read_conflict",
        "description": "Läs en fil med konfliktmarkörer. Visar båda sidorna.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "Sökväg till konfliktfilen"
                }
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "read_branch_version",
        "description": "Läs en fils innehåll från en specifik branch.",
        "input_schema": {
            "type": "object",
            "properties": {
                "branch": {
                    "type": "string",
                    "description": "Branch-namn (t.ex. 'main' eller 'feature/task-xxx')"
                },
                "file_path": {
                    "type": "string",
                    "description": "Sökväg till filen"
                }
            },
            "required": ["branch", "file_path"]
        }
    },
    {
        "name": "resolve_conflict",
        "description": "Lös konflikten genom att skriva det sammanslagna innehållet.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "Sökväg till konfliktfilen"
                },
                "resolved_content": {
                    "type": "string",
                    "description": "Det lösta innehållet (utan konfliktmarkörer)"
                }
            },
            "required": ["file_path", "resolved_content"]
        }
    },
    {
        "name": "use_ours",
        "description": "Behåll vår version (main) av filen.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "Sökväg till konfliktfilen"
                }
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "use_theirs",
        "description": "Använd deras version (feature-branch) av filen.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file_path": {
                    "type": "string",
                    "description": "Sökväg till konfliktfilen"
                }
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "complete_resolution",
        "description": "Markera att alla konflikter är lösta. Committar mergen.",
        "input_schema": {
            "type": "object",
            "properties": {
                "summary": {
                    "type": "string",
                    "description": "Sammanfattning av hur konflikterna löstes"
                }
            },
            "required": ["summary"]
        }
    },
    {
        "name": "abort_resolution",
        "description": "Avbryt merge. Använd om konflikten inte kan lösas automatiskt.",
        "input_schema": {
            "type": "object",
            "properties": {
                "reason": {
                    "type": "string",
                    "description": "Varför konflikten inte kunde lösas"
                }
            },
            "required": ["reason"]
        }
    }
]


class IntegratorAgent(BaseAgent):
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
        # Skapa en pseudo-task för BaseAgent
        task = {
            "id": conflict.get("id", "unknown"),
            "description": f"Lös konflikt mellan {conflict['branch_a']} och {conflict['branch_b']}"
        }
        super().__init__(task, context)
        self.conflict = conflict
        self.resolved_files = []

    def get_tools(self) -> list:
        """Integratör har konflikt-specifika tools."""
        return INTEGRATOR_TOOLS

    def get_system_prompt(self) -> str:
        """Bygg system-prompten för Integratör."""
        vision = self.context.get("vision", "Inget projekt definierat")

        return f"""Du är en INTEGRATÖR i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

DIN ROLL:
Du löser merge-konflikter mellan branches. Din uppgift är att:
1. Läsa och förstå båda versionerna av koden
2. Besluta vilken version som ska användas, eller kombinera dem
3. Säkerställa att den sammanslagna koden fungerar

KONFLIKT:
- Branch A (main): {self.conflict['branch_a']}
- Branch B (feature): {self.conflict['branch_b']}
- Filer med konflikt: {', '.join(self.conflict.get('conflict_files', []))}

STRATEGI:
1. Läs konfliktfilerna med read_conflict
2. Förstå vad varje sida försöker göra
3. Välj strategi:
   - use_ours: Behåll main-versionen
   - use_theirs: Använd feature-versionen
   - resolve_conflict: Kombinera båda (manuell merge)
4. När alla konflikter är lösta: complete_resolution
5. Om det inte går: abort_resolution

REGLER:
- Behåll funktionalitet från båda sidor om möjligt
- Om osäker, prioritera feature-branchen (den har nyare kod)
- Skriv aldrig sönder existerande tester"""

    def get_initial_message(self) -> str:
        """Bygg första meddelandet."""
        files = self.conflict.get("conflict_files", [])

        return f"""MERGE-KONFLIKT att lösa:

Branch A (main): {self.conflict['branch_a']}
Branch B (feature): {self.conflict['branch_b']}

Filer med konflikt ({len(files)} st):
{chr(10).join(f'  - {f}' for f in files)}

Analysera konfliktfilerna och lös dem en i taget."""

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett Integratör-tool."""

        if name == "read_conflict":
            file_path = arguments["file_path"]
            result = get_conflict_content(file_path)
            if "error" in result:
                return {"success": False, "error": result["error"]}
            return {
                "success": True,
                "file_path": file_path,
                "ours_content": result["ours"],
                "theirs_content": result["theirs"],
                "full_content": result["full_content"]
            }

        elif name == "read_branch_version":
            result = get_file_from_branch(arguments["branch"], arguments["file_path"])
            return result

        elif name == "resolve_conflict":
            file_path = arguments["file_path"]
            result = resolve_file_conflict(file_path, arguments["resolved_content"])
            if result["success"]:
                self.resolved_files.append(file_path)
            return result

        elif name == "use_ours":
            file_path = arguments["file_path"]
            # Hämta main-versionen
            result = get_file_from_branch(self.conflict["branch_a"], file_path)
            if not result["success"]:
                return result
            # Skriv den
            resolve_result = resolve_file_conflict(file_path, result["content"])
            if resolve_result["success"]:
                self.resolved_files.append(file_path)
            return resolve_result

        elif name == "use_theirs":
            file_path = arguments["file_path"]
            # Hämta feature-versionen
            result = get_file_from_branch(self.conflict["branch_b"], file_path)
            if not result["success"]:
                return result
            # Skriv den
            resolve_result = resolve_file_conflict(file_path, result["content"])
            if resolve_result["success"]:
                self.resolved_files.append(file_path)
            return resolve_result

        elif name == "complete_resolution":
            message = f"merge: Resolve conflict - {arguments['summary']}"
            result = complete_merge(message)
            return {
                "success": result["success"],
                "action": "COMPLETE" if result["success"] else None,
                "commit_hash": result.get("commit_hash"),
                "summary": arguments["summary"],
                "error": result.get("error")
            }

        elif name == "abort_resolution":
            result = abort_merge()
            return {
                "success": True,
                "action": "ABORT",
                "reason": arguments["reason"]
            }

        else:
            return {"success": False, "error": f"Unknown tool: {name}"}

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


if __name__ == "__main__":
    print("Integrator agent redo.")
    print("Körs via deploy_cycle.py när konflikter uppstår.")
