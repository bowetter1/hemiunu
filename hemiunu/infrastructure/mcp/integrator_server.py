"""
Integrator MCP Server - Verktyg för Integrator-agenten (merge-konflikter).

Integrator kan:
- Läsa konfliktfiler (read_conflict)
- Läsa fil från specifik branch (read_branch_version)
- Lösa konflikt (resolve_conflict)
- Välja vår version (use_ours)
- Välja deras version (use_theirs)
- Slutföra merge (complete_resolution)
- Avbryta merge (abort_resolution)

Integrator kan INTE:
- Skriva godtyckliga filer
- Köra kommandon
- Skapa tasks
"""
from fastmcp import FastMCP

# Import git-funktioner
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
from infrastructure.git import (
    get_conflict_content,
    get_file_from_branch,
    resolve_file_conflict,
    abort_merge,
    complete_merge
)


def create_integrator_server() -> FastMCP:
    """Skapa Integrator MCP-server."""

    mcp = FastMCP(
        name="hemiunu-integrator",
        instructions="""Du är en INTEGRATÖR i Hemiunu-systemet.

Din uppgift är att lösa merge-konflikter mellan branches.

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
- Om osäker, prioritera feature-branchen (nyare kod)
- Skriv aldrig sönder existerande tester
"""
    )

    @mcp.tool()
    def read_conflict(file_path: str) -> dict:
        """
        Läs en fil med konfliktmarkörer. Visar båda sidorna.

        Args:
            file_path: Sökväg till konfliktfilen
        """
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

    @mcp.tool()
    def read_branch_version(branch: str, file_path: str) -> dict:
        """
        Läs en fils innehåll från en specifik branch.

        Args:
            branch: Branch-namn (t.ex. 'main' eller 'feature/task-xxx')
            file_path: Sökväg till filen
        """
        return get_file_from_branch(branch, file_path)

    @mcp.tool()
    def resolve_conflict(file_path: str, resolved_content: str) -> dict:
        """
        Lös konflikten genom att skriva det sammanslagna innehållet.

        Args:
            file_path: Sökväg till konfliktfilen
            resolved_content: Det lösta innehållet (utan konfliktmarkörer)
        """
        return resolve_file_conflict(file_path, resolved_content)

    @mcp.tool()
    def use_ours(file_path: str, branch_a: str = "main") -> dict:
        """
        Behåll vår version (main) av filen.

        Args:
            file_path: Sökväg till konfliktfilen
            branch_a: Vår branch (default: main)
        """
        result = get_file_from_branch(branch_a, file_path)
        if not result["success"]:
            return result
        return resolve_file_conflict(file_path, result["content"])

    @mcp.tool()
    def use_theirs(file_path: str, branch_b: str) -> dict:
        """
        Använd deras version (feature-branch) av filen.

        Args:
            file_path: Sökväg till konfliktfilen
            branch_b: Deras branch (feature-branch)
        """
        result = get_file_from_branch(branch_b, file_path)
        if not result["success"]:
            return result
        return resolve_file_conflict(file_path, result["content"])

    @mcp.tool()
    def complete_resolution(summary: str) -> dict:
        """
        Markera att alla konflikter är lösta. Committar mergen.

        Args:
            summary: Sammanfattning av hur konflikterna löstes
        """
        message = f"merge: Resolve conflict - {summary}"
        result = complete_merge(message)
        return {
            "success": result["success"],
            "action": "COMPLETE" if result["success"] else None,
            "commit_hash": result.get("commit_hash"),
            "summary": summary,
            "error": result.get("error")
        }

    @mcp.tool()
    def abort_resolution(reason: str) -> dict:
        """
        Avbryt merge. Använd om konflikten inte kan lösas automatiskt.

        Args:
            reason: Varför konflikten inte kunde lösas
        """
        abort_merge()
        return {
            "success": True,
            "action": "ABORT",
            "reason": reason
        }

    return mcp


if __name__ == "__main__":
    server = create_integrator_server()
    server.run()
