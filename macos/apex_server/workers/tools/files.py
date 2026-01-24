"""File operation tools - read, write, list, run_command"""
import shlex
import subprocess
from pathlib import Path

ALLOWED_COMMANDS = {"git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip", "pytest", "curl", "railway"}

# Characters that indicate shell injection attempts
SHELL_INJECTION_CHARS = {";", "|", "&", "`", "$", "(", ")", "{", "}", "<", ">", "\n", "\r"}


def _validate_path(base_path: Path, user_path: str) -> tuple[Path, str | None]:
    """Validate that a path stays within the base directory.

    Returns:
        (resolved_path, error_message) - error_message is None if valid
    """
    if not user_path:
        return base_path, None

    # Normalize and resolve the path
    try:
        # Join with base and resolve to absolute path
        full_path = (base_path / user_path).resolve()

        # Ensure the resolved path is under base_path
        base_resolved = base_path.resolve()

        # Check if full_path is under base_resolved
        try:
            full_path.relative_to(base_resolved)
        except ValueError:
            return None, f"Error: Path '{user_path}' would escape project directory (path traversal blocked)"

        return full_path, None

    except Exception as e:
        return None, f"Error: Invalid path '{user_path}': {e}"

IGNORE_DIRS = {
    "__pycache__", "node_modules", ".git", ".venv", "venv",
    ".pytest_cache", ".mypy_cache", ".ruff_cache",
    "build", "dist", ".egg-info", ".tox", ".nox",
    ".idea", ".vscode", ".DS_Store"
}


def write_file(base_path: Path, args: dict) -> str:
    """Write content to a file."""
    path = args.get("path", "")
    content = args.get("content", "")

    if not path:
        return "Error: No path provided"

    # Validate path to prevent traversal attacks
    full_path, error = _validate_path(base_path, path)
    if error:
        return error

    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)

    return f"Wrote {len(content)} bytes to {path}"


def read_file(base_path: Path, args: dict) -> str:
    """Read a file."""
    file = args.get("file", "")

    if not file:
        return "Error: No file path provided"

    # Validate path to prevent traversal attacks
    full_path, error = _validate_path(base_path, file)
    if error:
        return error

    if full_path.exists() and full_path.is_file():
        try:
            content = full_path.read_text()
            if len(content) > 5000:
                content = content[:5000] + f"\n\n... (truncated, {len(content)} chars total)"
            return f"📄 {file}:\n\n```\n{content}\n```"
        except Exception as e:
            return f"Error reading {file}: {e}"
    else:
        available = [
            str(f.relative_to(base_path)) for f in base_path.rglob("*")
            if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f)
        ]
        return f"Error: File '{file}' not found.\n\nAvailable files:\n" + "\n".join(f"  - {f}" for f in available[:20])


def list_files(base_path: Path, args: dict) -> str:
    """List files in project directory."""
    path = args.get("path", ".")

    # Validate path to prevent traversal attacks
    target, error = _validate_path(base_path, path)
    if error:
        return error

    if not target.exists():
        return f"Error: Directory not found: {path}"

    files = []
    max_files = 100

    for f in target.rglob("*"):
        if any(ignored in f.parts for ignored in IGNORE_DIRS):
            continue

        if f.is_file() and not f.name.startswith("."):
            rel_path = str(f.relative_to(base_path))
            size = f.stat().st_size
            size_str = f"{size} B" if size < 1024 else f"{size//1024} KB"
            files.append((rel_path, size_str))

            if len(files) >= max_files:
                break

    if files:
        files.sort(key=lambda x: x[0])
        file_list = "\n".join(f"  {f[0]} ({f[1]})" for f in files)
        truncated = f"\n\n⚠️ Showing max {max_files} files." if len(files) >= max_files else ""
        return f"📁 Files ({len(files)}):\n\n{file_list}{truncated}"
    else:
        return "📁 No files in project yet."


def check_needs(base_path: Path, args: dict) -> str:
    """Check CONTEXT.md for pending NEEDS (blockers) from workers."""
    context_file = base_path / "CONTEXT.md"

    if not context_file.exists():
        return "No CONTEXT.md file found."

    content = context_file.read_text()

    # Find NEEDS section
    needs_section = None
    in_needs = False
    lines = content.split("\n")

    for i, line in enumerate(lines):
        if "## NEEDS" in line or "## Needs" in line:
            in_needs = True
            needs_section = []
            continue
        if in_needs:
            if line.startswith("## ") and "NEEDS" not in line.upper():
                break  # End of NEEDS section
            needs_section.append(line)

    if not needs_section:
        return "No NEEDS section found in CONTEXT.md."

    # Parse table rows for pending items
    pending = []
    for line in needs_section:
        if "|" in line and "PENDING" in line.upper():
            parts = [p.strip() for p in line.split("|")]
            # Expected format: | Worker | Need | Status |
            if len(parts) >= 4:  # Empty first/last from split
                worker = parts[1] if len(parts) > 1 else ""
                need = parts[2] if len(parts) > 2 else ""
                if worker and need:
                    pending.append(f"- {worker}: {need}")

    if pending:
        return f"⚠️ Pending NEEDS ({len(pending)}):\n" + "\n".join(pending)
    else:
        return "✅ No pending NEEDS. All blockers resolved."


def run_command(base_path: Path, args: dict) -> str:
    """Run a command safely without shell injection risks."""
    command = args.get("command", "").strip()

    if not command:
        return "Error: No command provided"

    # Check for shell injection characters
    if any(char in command for char in SHELL_INJECTION_CHARS):
        return f"Error: Command contains forbidden characters. Shell operators (;|&`$) are not allowed for security reasons."

    # Parse command safely
    try:
        cmd_parts = shlex.split(command)
    except ValueError as e:
        return f"Error: Invalid command syntax: {e}"

    if not cmd_parts:
        return "Error: Empty command"

    cmd_name = cmd_parts[0]

    # Validate command is in allowlist
    if cmd_name not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_name}. Allowed: {sorted(ALLOWED_COMMANDS)}"

    try:
        result = subprocess.run(
            cmd_parts,  # Pass as list, not string - avoids shell=True
            cwd=base_path,
            capture_output=True,
            timeout=60,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Command timed out (60s limit)"
    except FileNotFoundError:
        return f"Error: Command not found: {cmd_name}"
    except Exception as e:
        return f"Error: {e}"
