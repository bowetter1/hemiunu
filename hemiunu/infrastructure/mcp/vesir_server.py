"""
Vesir MCP Server - Verktyg för Vesir-agenten (strategisk planering).

Vesir kan:
- Läsa filer (read_file) - för att förstå kodbasen
- Lista filer (list_files) - för att utforska strukturen
- Skapa subtasks (create_subtask)
- Avvisa uppdrag (reject_request)
- Slutföra nedbrytning (complete_breakdown)

Vesir kan INTE:
- Skriva kod (write_file) - Vesir planerar bara, skriver aldrig kod
- Köra kommandon (run_command) - ingen exekvering
"""
from fastmcp import FastMCP
from .base import read_file, list_files

# Import för att skapa tasks i databasen
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from infrastructure.db import TaskRepository

MAX_TEST_CASES = 7  # Max testfall för full täckning


def create_vesir_server() -> FastMCP:
    """Skapa Vesir MCP-server."""

    mcp = FastMCP(
        name="hemiunu-vesir",
        instructions=f"""Du är en VESIR (strategisk rådgivare) i Hemiunu-systemet.

Din uppgift är att bryta ner stora uppdrag till ATOMÄRA TASKS.
Du skriver INGEN kod - du planerar bara.

VERIFIERBARHETSPRINCIPEN:
Vi mäter VERIFIERBARHET, inte storlek. En task är atomär om den kan
fullständigt testas med max {MAX_TEST_CASES} testfall.

REGLER FÖR VARJE TASK:
1. Max {MAX_TEST_CASES} testfall för full täckning (estimated_test_cases)
2. MÅSTE ha CLI-test som kan verifiera implementation
3. Tydlig input/output-specifikation
4. Oberoende eller tydliga dependencies

STRATEGI:
1. Analysera kodbasen med list_files och read_file
2. Förstå vad som redan finns
3. Bryt ner uppdraget i logiska steg
4. Skapa tasks med create_subtask
5. Avsluta med complete_breakdown
"""
    )

    @mcp.tool()
    def vesir_read_file(path: str) -> dict:
        """
        Läs en fil för att förstå existerande kod.

        Args:
            path: Sökväg relativt projektroten
        """
        return read_file(path)

    @mcp.tool()
    def vesir_list_files(path: str = ".") -> dict:
        """
        Lista filer i en katalog för att förstå kodbasen.

        Args:
            path: Sökväg relativt projektroten
        """
        return list_files(path)

    @mcp.tool()
    def create_subtask(
        description: str,
        cli_test: str,
        estimated_test_cases: int,
        input_schema: str = None,
        output_schema: str = None,
        dependencies: list[str] = None
    ) -> dict:
        """
        Skapa en atomär subtask. Varje task måste ha CLI-test och vara verifierbar med max 7 testfall.

        Args:
            description: Tydlig beskrivning av vad som ska implementeras
            cli_test: CLI-kommando för att verifiera implementation
            estimated_test_cases: Antal testfall för full täckning (max 7)
            input_schema: Beskrivning av input (valfritt)
            output_schema: Beskrivning av förväntad output (valfritt)
            dependencies: Lista på task-beskrivningar som måste vara klara först (valfritt)

        Example:
            create_subtask(
                description="Implementera is_prime(n) som returnerar True om n är primtal",
                cli_test="python3 -c 'from src.prime import is_prime; print(is_prime(7))'",
                estimated_test_cases=5,
                input_schema="Ett heltal n >= 2",
                output_schema="True om n är primtal, annars False"
            )
        """
        # Validera verifierbarhet
        if estimated_test_cases > MAX_TEST_CASES:
            return {
                "success": False,
                "error": f"Task är för komplex ({estimated_test_cases} testfall). Max är {MAX_TEST_CASES}. Bryt ner ytterligare."
            }

        if estimated_test_cases == 0:
            return {
                "success": False,
                "error": "Du måste uppskatta antal testfall (estimated_test_cases)."
            }

        # Skapa task i databasen
        task_id = TaskRepository.create(
            description=description,
            cli_test=cli_test
        )

        return {
            "success": True,
            "task_id": task_id,
            "message": f"Task skapad: {task_id} (verifierbar med {estimated_test_cases} testfall)",
            "task": {
                "id": task_id,
                "description": description,
                "cli_test": cli_test,
                "estimated_test_cases": estimated_test_cases,
                "input_schema": input_schema,
                "output_schema": output_schema,
                "dependencies": dependencies or []
            }
        }

    @mcp.tool()
    def reject_request(reason: str) -> dict:
        """
        Avvisa uppdraget om det inte kan brytas ner till atomära tasks.

        Args:
            reason: Varför uppdraget inte kan genomföras
        """
        return {
            "success": True,
            "action": "REJECT",
            "reason": reason
        }

    @mcp.tool()
    def complete_breakdown(summary: str, total_tasks: int) -> dict:
        """
        Markera att nedbrytningen är klar. Använd när alla subtasks är skapade.

        Args:
            summary: Sammanfattning av planen
            total_tasks: Totalt antal tasks skapade
        """
        return {
            "success": True,
            "action": "COMPLETE",
            "summary": summary,
            "total_tasks": total_tasks
        }

    return mcp


if __name__ == "__main__":
    server = create_vesir_server()
    server.run()
