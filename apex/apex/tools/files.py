"""
File tools - read_file, list_files, playbook, set_project_dir
"""
import os
import re
from pathlib import Path

from core.config import WORKER_CLI, AVAILABLE_AIS
from .base import make_response, log_to_sprint

# Global project directory - can be updated dynamically
_current_project_dir = None


def get_project_dir(fallback: str) -> str:
    """Hämta aktuell projektmapp."""
    global _current_project_dir
    return _current_project_dir or fallback


def set_project_dir_internal(path: str) -> str:
    """Sätt projektmapp internt."""
    global _current_project_dir
    _current_project_dir = path
    return path


TOOLS = [
    {
        "name": "set_project_dir",
        "description": "Sätt projektmapp. KÖR DETTA FÖRST för att välja var filer ska skapas.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Sökväg till projektmappen"},
                "create": {"type": "boolean", "description": "Skapa mappen om den inte finns"}
            },
            "required": ["path"]
        }
    },
    {
        "name": "read_file",
        "description": "Läs en fil i projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "Filnamn"}
            },
            "required": ["file"]
        }
    },
    {
        "name": "list_files",
        "description": "Lista alla filer i projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "read_playbook",
        "description": "Läs projektets playbook.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "update_playbook",
        "description": "Uppdatera en sektion i playbook.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "section": {"type": "string", "enum": ["vision", "team", "sprints", "current", "notes"]},
                "content": {"type": "string"}
            },
            "required": ["section", "content"]
        }
    },
]


def read_file(arguments: dict, cwd: str) -> dict:
    """Läs en fil."""
    file = arguments.get("file", "")
    file_path = Path(cwd) / file

    if file_path.exists() and file_path.is_file():
        try:
            content = file_path.read_text()
            if len(content) > 5000:
                content = content[:5000] + f"\n\n... (trunkerad, {len(content)} tecken totalt)"
            log_to_sprint(cwd, f"📄 Läste: {file}")
            return make_response(f"📄 {file}:\n\n```\n{content}\n```")
        except Exception as e:
            return make_response(f"❌ Kunde inte läsa {file}: {e}")
    else:
        available = [
            str(f.relative_to(cwd)) for f in Path(cwd).rglob("*")
            if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f)
        ]
        return make_response(
            f"❌ Filen '{file}' finns inte.\n\nTillgängliga filer:\n" +
            "\n".join(f"  - {f}" for f in available[:20])
        )


def list_files(arguments: dict, cwd: str) -> dict:
    """Lista alla filer i projektmappen."""
    # Mappar att ignorera
    IGNORE_DIRS = {
        "__pycache__", "node_modules", ".git", ".venv", "venv",
        ".pytest_cache", ".mypy_cache", ".ruff_cache",
        "build", "dist", ".egg-info", ".tox", ".nox",
        ".idea", ".vscode", ".DS_Store"
    }

    files = []
    max_files = 100  # Begränsa för att undvika överflöd

    for f in Path(cwd).rglob("*"):
        # Skippa ignorerade mappar
        if any(ignored in f.parts for ignored in IGNORE_DIRS):
            continue

        if (f.is_file() and not f.name.startswith(".")):
            rel_path = str(f.relative_to(cwd))
            size = f.stat().st_size
            size_str = f"{size} B" if size < 1024 else f"{size//1024} KB"
            files.append((rel_path, size_str, size))

            if len(files) >= max_files:
                break

    if files:
        # Sortera efter sökväg
        files.sort(key=lambda x: x[0])
        file_list = "\n".join(f"  {f[0]} ({f[1]})" for f in files)

        truncated = ""
        if len(files) >= max_files:
            truncated = f"\n\n⚠️ Visar max {max_files} filer. Använd read_file() för specifika filer."

        log_to_sprint(cwd, f"📁 Listade {len(files)} filer")
        return make_response(f"📁 Filer ({len(files)} st):\n\n{file_list}{truncated}")
    else:
        return make_response("📁 Inga filer i projektet ännu.")


def _get_playbook_path() -> Path:
    """Returnera sökväg till playbook."""
    docs_dir = Path(__file__).parent.parent.parent / "docs"
    docs_dir.mkdir(exist_ok=True)
    return docs_dir / "PLAYBOOK.md"


def _get_playbook_template() -> str:
    """Generera playbook-mall från config."""
    team_lines = []
    for role, ai in WORKER_CLI.items():
        if role != "chef":
            team_lines.append(f"- {role.capitalize()}: {ai}")

    return f"""# Playbook

## Vision
_Vad bygger vi? Varför?_

## Team
_Vem gör vad?_
{chr(10).join(team_lines)}

Tillgängliga AI:er: {', '.join(AVAILABLE_AIS)}

## Sprints
_Hur delar vi upp arbetet?_

### Sprint 1
- [ ]

## Nu
_Vad händer just nu?_

## Anteckningar
_Fritt utrymme för tankar_

"""


def read_playbook(arguments: dict, cwd: str) -> dict:
    """Läs playbook."""
    playbook_path = _get_playbook_path()

    if not playbook_path.exists():
        template = _get_playbook_template()
        playbook_path.write_text(template)
        log_to_sprint(cwd, "📓 Skapade ny PLAYBOOK.md")

    content = playbook_path.read_text()
    return make_response(f"📓 PLAYBOOK:\n\n{content}")


def update_playbook(arguments: dict, cwd: str) -> dict:
    """Uppdatera en sektion i playbook."""
    section = arguments.get("section", "notes")
    new_content = arguments.get("content", "")

    section_titles = {
        "vision": "## Vision",
        "team": "## Team",
        "sprints": "## Sprints",
        "current": "## Nu",
        "notes": "## Anteckningar"
    }

    playbook_path = _get_playbook_path()

    if playbook_path.exists():
        content = playbook_path.read_text()
    else:
        content = _get_playbook_template()

    title = section_titles.get(section, "## Anteckningar")
    pattern = f"({re.escape(title)})\n(.*?)(?=\n## |$)"
    replacement = f"{title}\n{new_content}\n"

    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    else:
        content += f"\n{title}\n{new_content}\n"

    playbook_path.write_text(content)
    log_to_sprint(cwd, f"📓 Uppdaterade PLAYBOOK [{section}]")

    return make_response(f"📓 Uppdaterade '{section}':\n\n{new_content[:200]}...")


def set_project_dir(arguments: dict, cwd: str) -> dict:
    """Sätt projektmapp."""
    path = arguments.get("path", "")
    create = arguments.get("create", True)

    if not path:
        return make_response("❌ Ange en sökväg!")

    project_path = Path(path)

    # Skapa om den inte finns
    if not project_path.exists() and create:
        project_path.mkdir(parents=True, exist_ok=True)

    if not project_path.exists():
        return make_response(f"❌ Mappen '{path}' finns inte. Sätt create=true för att skapa den.")

    # Uppdatera global variabel
    set_project_dir_internal(str(project_path.absolute()))

    return make_response(f"📁 Projektmapp satt till: {project_path.absolute()}\n\nAlla filer kommer nu skapas här.")


HANDLERS = {
    "set_project_dir": set_project_dir,
    "read_file": read_file,
    "list_files": list_files,
    "read_playbook": read_playbook,
    "update_playbook": update_playbook,
}
