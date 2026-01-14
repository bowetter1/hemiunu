"""
Tester MCP Server - Verktyg för Tester-agenten.

Tester kan:
- Läsa filer (read_file)
- Köra kommandon/tester (run_command)
- Lista filer (list_files)
- Skriva TESTFILER (write_test_file) - endast i tests/
- Godkänna (approve)
- Avvisa (reject)

Tester kan INTE:
- Skriva produktionskod (write_file till src/)
- Markera task_done - det är Workers jobb
"""
from fastmcp import FastMCP
from .base import run_command, read_file, write_file, list_files

def create_tester_server() -> FastMCP:
    """Skapa Tester MCP-server."""

    mcp = FastMCP(
        name="hemiunu-tester",
        instructions="""Du är en Tester i Hemiunu-systemet.

Din uppgift är att OBEROENDE validera Worker's kod.

VIKTIGT:
1. Skriv egna tester INNAN du läser Worker's kod
2. Dina tester baseras på KONTRAKTET, inte implementationen
3. Kör både Worker's CLI-test och dina egna tester
4. Godkänn endast om ALLA tester passerar
"""
    )

    @mcp.tool()
    def tester_read_file(path: str) -> dict:
        """
        Läs innehållet i en fil.

        Args:
            path: Sökväg relativt projektroten
        """
        return read_file(path)

    @mcp.tool()
    def tester_run_command(command: str, timeout: int = 60) -> dict:
        """
        Kör ett shell-kommando för att testa kod.

        Args:
            command: Kommandot att köra
            timeout: Max antal sekunder (default 60)
        """
        return run_command(command, timeout)

    @mcp.tool()
    def tester_list_files(path: str = ".") -> dict:
        """
        Lista filer i en katalog.

        Args:
            path: Sökväg relativt projektroten
        """
        return list_files(path)

    @mcp.tool()
    def write_test_file(path: str, content: str) -> dict:
        """
        Skriv en testfil. Kan ENDAST skriva till tests/-mappen.

        Args:
            path: Sökväg som måste börja med 'tests/' (t.ex. 'tests/test_math.py')
            content: Testinnehållet
        """
        # Säkerhetskontroll - endast tests/
        if not path.startswith("tests/"):
            return {
                "success": False,
                "error": "Tester kan endast skriva till tests/-mappen. Använd path som börjar med 'tests/'"
            }
        return write_file(path, content)

    @mcp.tool()
    def approve(summary: str, tests_passed: int) -> dict:
        """
        Godkänn Worker's implementation. Alla tester passerade.

        Args:
            summary: Kort sammanfattning av vad som testades
            tests_passed: Antal tester som passerade
        """
        return {
            "success": True,
            "action": "APPROVE",
            "summary": summary,
            "tests_passed": tests_passed
        }

    @mcp.tool()
    def reject(reason: str, failed_tests: list[str]) -> dict:
        """
        Avvisa Worker's implementation. Tester misslyckades.

        Args:
            reason: Varför testerna misslyckades
            failed_tests: Lista av misslyckade tester
        """
        return {
            "success": True,
            "action": "REJECT",
            "reason": reason,
            "failed_tests": failed_tests
        }

    return mcp


if __name__ == "__main__":
    server = create_tester_server()
    server.run()
