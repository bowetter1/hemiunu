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
    """Get current project folder."""
    global _current_project_dir
    return _current_project_dir or fallback


def set_project_dir_internal(path: str) -> str:
    """Set project folder internally."""
    global _current_project_dir
    _current_project_dir = path
    return path


TOOLS = [
    {
        "name": "check_needs",
        "description": "Check CONTEXT.md for any NEEDS/blockers from workers. Returns list of blockers if any.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "check_questions",
        "description": "Check CONTEXT.md for any QUESTIONS from workers. Returns unanswered questions if any.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "set_project_dir",
        "description": "Set project folder. RUN THIS FIRST to choose where files should be created.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Path to project folder"},
                "create": {"type": "boolean", "description": "Create folder if it doesn't exist"}
            },
            "required": ["path"]
        }
    },
    {
        "name": "read_file",
        "description": "Read a file in the project.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "Filename"}
            },
            "required": ["file"]
        }
    },
    {
        "name": "list_files",
        "description": "List all files in the project.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "read_playbook",
        "description": "Read the project's playbook.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "update_playbook",
        "description": "Update a section in playbook.",
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


def _parse_needs_table(content: str) -> list[dict]:
    """Parse NEEDS table from CONTEXT.md content."""
    needs = []
    # Look for table rows after NEEDS header
    in_needs = False
    for line in content.split('\n'):
        if '## NEEDS' in line or 'NEEDS (blockers)' in line:
            in_needs = True
            continue
        if in_needs:
            if line.startswith('## ') or line.startswith('# '):
                break  # Next section
            if '|' in line and not line.strip().startswith('|--'):
                parts = [p.strip() for p in line.split('|')]
                parts = [p for p in parts if p]  # Remove empty
                if len(parts) >= 3 and parts[0] not in ['From', 'from']:
                    needs.append({
                        'from': parts[0],
                        'need': parts[1],
                        'from_who': parts[2] if len(parts) > 2 else '',
                        'status': parts[3] if len(parts) > 3 else 'pending'
                    })
    return needs


def _parse_questions_table(content: str) -> list[dict]:
    """Parse QUESTIONS table from CONTEXT.md content."""
    questions = []
    # Look for table rows after QUESTIONS header
    in_questions = False
    for line in content.split('\n'):
        if '## QUESTIONS' in line or 'QUESTIONS (for Chef)' in line:
            in_questions = True
            continue
        if in_questions:
            if line.startswith('## ') or line.startswith('# '):
                break  # Next section
            if '|' in line and not line.strip().startswith('|--'):
                parts = [p.strip() for p in line.split('|')]
                parts = [p for p in parts if p]  # Remove empty
                if len(parts) >= 2 and parts[0] not in ['From', 'from']:
                    answer = parts[2] if len(parts) > 2 else ''
                    questions.append({
                        'from': parts[0],
                        'question': parts[1],
                        'answer': answer,
                        'pending': answer.lower() in ['', '(pending)', 'pending', '-']
                    })
    return questions


def check_needs(arguments: dict, cwd: str) -> dict:
    """Check CONTEXT.md for blockers/needs."""
    context_file = Path(cwd) / "CONTEXT.md"

    if not context_file.exists():
        return make_response("📋 No CONTEXT.md found - no blockers to report")

    content = context_file.read_text()
    needs = _parse_needs_table(content)

    if not needs:
        log_to_sprint(cwd, "📋 NEEDS: None (all clear)")
        return make_response("✅ No blockers in NEEDS section")

    # Filter for pending needs only
    pending_needs = [n for n in needs if n['status'].lower() in ['pending', '', '⏳', '⏳ waiting']]

    if not pending_needs:
        log_to_sprint(cwd, "📋 NEEDS: All resolved")
        return make_response("✅ All blockers resolved")

    # Log each blocker
    log_to_sprint(cwd, f"⚠️ NEEDS: {len(pending_needs)} blocker(s) found!")
    for n in pending_needs:
        log_to_sprint(cwd, f"   🔴 {n['from']} needs {n['need']} from {n['from_who']}")

    needs_text = "\n".join([
        f"- **{n['from']}** needs: {n['need']} (from {n['from_who']})"
        for n in pending_needs
    ])
    return make_response(f"⚠️ **{len(pending_needs)} BLOCKER(S) FOUND:**\n\n{needs_text}")


def check_questions(arguments: dict, cwd: str) -> dict:
    """Check CONTEXT.md for unanswered questions."""
    context_file = Path(cwd) / "CONTEXT.md"

    if not context_file.exists():
        return make_response("📋 No CONTEXT.md found - no questions to report")

    content = context_file.read_text()
    questions = _parse_questions_table(content)

    if not questions:
        log_to_sprint(cwd, "❓ QUESTIONS: None")
        return make_response("✅ No questions in QUESTIONS section")

    # Filter for pending questions only
    pending = [q for q in questions if q['pending']]

    if not pending:
        log_to_sprint(cwd, "❓ QUESTIONS: All answered")
        return make_response("✅ All questions answered")

    # Log each question
    log_to_sprint(cwd, f"❓ QUESTIONS: {len(pending)} unanswered!")
    for q in pending:
        log_to_sprint(cwd, f"   ❓ {q['from']}: {q['question']}")

    questions_text = "\n".join([
        f"- **{q['from']}** asks: {q['question']}"
        for q in pending
    ])
    return make_response(f"❓ **{len(pending)} QUESTION(S) NEED ANSWERS:**\n\n{questions_text}")


def read_file(arguments: dict, cwd: str) -> dict:
    """Read a file."""
    file = arguments.get("file", "")
    file_path = Path(cwd) / file

    if file_path.exists() and file_path.is_file():
        try:
            content = file_path.read_text()

            # Auto-detect NEEDS when reading CONTEXT.md
            if file.upper() == "CONTEXT.MD":
                needs = _parse_needs_table(content)
                if needs:
                    log_to_sprint(cwd, f"⚠️ CONTEXT.md has {len(needs)} NEEDS entry/entries!")
                    for n in needs:
                        log_to_sprint(cwd, f"   → {n['from']} needs: {n['need']}")

            if len(content) > 5000:
                content = content[:5000] + f"\n\n... (truncated, {len(content)} chars total)"
            log_to_sprint(cwd, f"📄 Read: {file}")
            return make_response(f"📄 {file}:\n\n```\n{content}\n```")
        except Exception as e:
            return make_response(f"❌ Could not read {file}: {e}")
    else:
        available = [
            str(f.relative_to(cwd)) for f in Path(cwd).rglob("*")
            if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f)
        ]
        return make_response(
            f"❌ File '{file}' does not exist.\n\nAvailable files:\n" +
            "\n".join(f"  - {f}" for f in available[:20])
        )


def list_files(arguments: dict, cwd: str) -> dict:
    """List all files in the project folder."""
    # Folders to ignore
    IGNORE_DIRS = {
        "__pycache__", "node_modules", ".git", ".venv", "venv",
        ".pytest_cache", ".mypy_cache", ".ruff_cache",
        "build", "dist", ".egg-info", ".tox", ".nox",
        ".idea", ".vscode", ".DS_Store"
    }

    files = []
    max_files = 100  # Limit to avoid overflow

    for f in Path(cwd).rglob("*"):
        # Skip ignored folders
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
        # Sort by path
        files.sort(key=lambda x: x[0])
        file_list = "\n".join(f"  {f[0]} ({f[1]})" for f in files)

        truncated = ""
        if len(files) >= max_files:
            truncated = f"\n\n⚠️ Showing max {max_files} files. Use read_file() for specific files."

        log_to_sprint(cwd, f"📁 Listed {len(files)} files")
        return make_response(f"📁 Files ({len(files)}):\n\n{file_list}{truncated}")
    else:
        return make_response("📁 No files in the project yet.")


def _get_playbook_path() -> Path:
    """Return path to playbook."""
    docs_dir = Path(__file__).parent.parent.parent / "docs"
    docs_dir.mkdir(exist_ok=True)
    return docs_dir / "PLAYBOOK.md"


def _get_playbook_template() -> str:
    """Generate playbook template from config."""
    team_lines = []
    for role, ai in WORKER_CLI.items():
        if role != "chef":
            team_lines.append(f"- {role.capitalize()}: {ai}")

    return f"""# Playbook

## Vision
_What are we building? Why?_

## Team
_Who does what?_
{chr(10).join(team_lines)}

Available AIs: {', '.join(AVAILABLE_AIS)}

## Sprints
_How do we break down the work?_

### Sprint 1
- [ ]

## Now
_What's happening right now?_

## Notes
_Free space for thoughts_

"""


def read_playbook(arguments: dict, cwd: str) -> dict:
    """Read playbook."""
    playbook_path = _get_playbook_path()

    if not playbook_path.exists():
        template = _get_playbook_template()
        playbook_path.write_text(template)
        log_to_sprint(cwd, "📓 Created new PLAYBOOK.md")

    content = playbook_path.read_text()
    return make_response(f"📓 PLAYBOOK:\n\n{content}")


def update_playbook(arguments: dict, cwd: str) -> dict:
    """Update a section in playbook."""
    section = arguments.get("section", "notes")
    new_content = arguments.get("content", "")

    section_titles = {
        "vision": "## Vision",
        "team": "## Team",
        "sprints": "## Sprints",
        "current": "## Now",
        "notes": "## Notes"
    }

    playbook_path = _get_playbook_path()

    if playbook_path.exists():
        content = playbook_path.read_text()
    else:
        content = _get_playbook_template()

    title = section_titles.get(section, "## Notes")
    pattern = f"({re.escape(title)})\n(.*?)(?=\n## |$)"
    replacement = f"{title}\n{new_content}\n"

    if re.search(pattern, content, re.DOTALL):
        content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    else:
        content += f"\n{title}\n{new_content}\n"

    playbook_path.write_text(content)
    log_to_sprint(cwd, f"📓 Updated PLAYBOOK [{section}]")

    return make_response(f"📓 Updated '{section}':\n\n{new_content[:200]}...")


def set_project_dir(arguments: dict, cwd: str) -> dict:
    """Set project folder."""
    path = arguments.get("path", "")
    create = arguments.get("create", True)

    if not path:
        return make_response("❌ Please provide a path!")

    project_path = Path(path)

    # Create if it doesn't exist
    if not project_path.exists() and create:
        project_path.mkdir(parents=True, exist_ok=True)

    if not project_path.exists():
        return make_response(f"❌ Folder '{path}' does not exist. Set create=true to create it.")

    # Update global variable
    set_project_dir_internal(str(project_path.absolute()))

    return make_response(f"📁 Project folder set to: {project_path.absolute()}\n\nAll files will now be created here.")


HANDLERS = {
    "check_needs": check_needs,
    "check_questions": check_questions,
    "set_project_dir": set_project_dir,
    "read_file": read_file,
    "list_files": list_files,
    "read_playbook": read_playbook,
    "update_playbook": update_playbook,
}
