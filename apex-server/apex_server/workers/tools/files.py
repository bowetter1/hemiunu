"""File operation tools - read, write, list, run_command"""
import subprocess
from pathlib import Path

ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip", "pytest", "curl", "railway"]

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

    full_path = base_path / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)

    return f"Wrote {len(content)} bytes to {path}"


def read_file(base_path: Path, args: dict) -> str:
    """Read a file."""
    file = args.get("file", "")
    full_path = base_path / file

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
    target = base_path / path

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


def run_command(base_path: Path, args: dict) -> str:
    """Run a shell command."""
    command = args.get("command", "")
    cmd_start = command.split()[0] if command.split() else ""

    if cmd_start not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_start}. Allowed: {ALLOWED_COMMANDS}"

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=base_path,
            capture_output=True,
            timeout=60,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except Exception as e:
        return f"Error: {e}"
