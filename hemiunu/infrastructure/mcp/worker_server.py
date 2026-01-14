"""
Worker MCP Server - Verktyg för Worker-agenten.

Worker kan:
- Skriva kod (write_file)
- Läsa filer (read_file)
- Köra kommandon (run_command)
- Lista filer (list_files)
- Markera klart (task_done)
- Markera misslyckat (task_failed)
- Dela upp task (split_task)

Worker kan INTE:
- Godkänna kod (approve) - det är Testers jobb
- Avvisa kod (reject) - det är Testers jobb
"""
from fastmcp import FastMCP
from .base import run_command, read_file, write_file, list_files

def create_worker_server() -> FastMCP:
    """Skapa Worker MCP-server."""

    mcp = FastMCP(
        name="hemiunu-worker",
        instructions="""Du är en Worker i Hemiunu-systemet.

Din uppgift är att skriva kod och testa den via CLI.
Du har tillgång till filsystem och kommandorad.

VERIFIERBARHETSPRINCIPEN:
Uppgiften ska kunna verifieras med max 7 testfall.

REGLER:
1. Om uppgiften kräver >7 testfall för full täckning: split_task
2. Testa alltid din kod med run_command innan task_done
3. Om för komplext, använd split_task
"""
    )

    @mcp.tool()
    def worker_write_file(path: str, content: str) -> dict:
        """
        Skriv innehåll till en fil. Skapar mappar om de saknas.

        Args:
            path: Sökväg relativt projektroten (t.ex. 'src/math.py')
            content: Innehållet att skriva
        """
        return write_file(path, content)

    @mcp.tool()
    def worker_read_file(path: str) -> dict:
        """
        Läs innehållet i en fil.

        Args:
            path: Sökväg relativt projektroten
        """
        return read_file(path)

    @mcp.tool()
    def worker_run_command(command: str, timeout: int = 60) -> dict:
        """
        Kör ett shell-kommando för att testa kod.

        Args:
            command: Kommandot att köra (t.ex. 'python3 src/test.py')
            timeout: Max antal sekunder (default 60)
        """
        return run_command(command, timeout)

    @mcp.tool()
    def worker_list_files(path: str = ".") -> dict:
        """
        Lista filer i en katalog.

        Args:
            path: Sökväg relativt projektroten (default: rot)
        """
        return list_files(path)

    @mcp.tool()
    def task_done(summary: str) -> dict:
        """
        Markera uppgiften som KLAR. Använd när koden är skriven och testad.

        Args:
            summary: Kort sammanfattning av vad du implementerade
        """
        return {
            "success": True,
            "action": "DONE",
            "summary": summary
        }

    @mcp.tool()
    def task_failed(reason: str) -> dict:
        """
        Markera uppgiften som MISSLYCKAD. Använd om du inte kan lösa uppgiften.

        Args:
            reason: Varför uppgiften inte kunde lösas
        """
        return {
            "success": True,
            "action": "FAILED",
            "reason": reason
        }

    @mcp.tool()
    def split_task(subtasks: list[dict]) -> dict:
        """
        Dela upp uppgiften i mindre delar. Använd om uppgiften är för komplex.

        Args:
            subtasks: Lista av subtasks, varje med 'description' och 'cli_test'

        Example:
            split_task([
                {"description": "Implementera add()", "cli_test": "python -c 'from calc import add; print(add(2,3))'"},
                {"description": "Implementera sub()", "cli_test": "python -c 'from calc import sub; print(sub(5,2))'"}
            ])
        """
        return {
            "success": True,
            "action": "SPLIT",
            "subtasks": subtasks
        }

    return mcp


# För att köra servern direkt
if __name__ == "__main__":
    server = create_worker_server()
    server.run()
