"""Tools that AI workers can use"""
import shlex
import subprocess
import datetime
from pathlib import Path

from apex_server.config import get_settings

settings = get_settings()
STORAGE = Path(settings.storage_path)
ALLOWED_COMMANDS = {"git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip"}

# Characters that indicate shell injection attempts
SHELL_INJECTION_CHARS = {";", "|", "&", "`", "$", "(", ")", "{", "}", "<", ">", "\n", "\r"}


def _validate_path(base_path: Path, user_path: str) -> tuple[Path, str | None]:
    """Validate that a path stays within the base directory.

    Returns:
        (resolved_path, error_message) - error_message is None if valid
    """
    if not user_path:
        return base_path, None

    try:
        full_path = (base_path / user_path).resolve()
        base_resolved = base_path.resolve()

        try:
            full_path.relative_to(base_resolved)
        except ValueError:
            return None, f"Error: Path traversal blocked"

        return full_path, None
    except Exception as e:
        return None, f"Error: Invalid path: {e}"


def write_file(base_path: Path, path: str, content: str) -> str:
    """Write content to a file"""
    full_path, error = _validate_path(base_path, path)
    if error:
        return error

    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return f"Wrote {len(content)} bytes to {path}"


def read_file(base_path: Path, path: str) -> str:
    """Read a file"""
    full_path, error = _validate_path(base_path, path)
    if error:
        return error

    if not full_path.exists():
        return f"Error: File not found: {path}"
    return full_path.read_text()


def format_size(size: int) -> str:
    """Format file size in human readable format"""
    if size < 1024:
        return f"{size} B"
    elif size < 1024 * 1024:
        return f"{size / 1024:.1f} KB"
    else:
        return f"{size / (1024 * 1024):.1f} MB"


def list_files(base_path: Path, path: str = ".") -> str:
    """List files in directory with sizes"""
    full_path, error = _validate_path(base_path, path)
    if error:
        return error

    if not full_path.exists():
        return f"Error: Directory not found: {path}"

    files = []
    for f in full_path.rglob("*"):
        if f.is_file() and ".git" not in str(f):
            rel_path = str(f.relative_to(base_path))
            size = format_size(f.stat().st_size)
            files.append(f"  {rel_path} ({size})")

    return "\n".join(files[:100]) if files else "(empty)"


def run_command(base_path: Path, command: str) -> str:
    """Run a command safely without shell injection risks."""
    command = command.strip()

    if not command:
        return "Error: No command provided"

    # Check for shell injection characters
    if any(char in command for char in SHELL_INJECTION_CHARS):
        return "Error: Command contains forbidden characters. Shell operators (;|&`$) are not allowed."

    # Parse command safely
    try:
        cmd_parts = shlex.split(command)
    except ValueError as e:
        return f"Error: Invalid command syntax: {e}"

    if not cmd_parts:
        return "Error: Empty command"

    cmd_name = cmd_parts[0]
    if cmd_name not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_name}"

    try:
        result = subprocess.run(
            cmd_parts,  # Pass as list, not string
            cwd=base_path,
            capture_output=True,
            timeout=60,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except FileNotFoundError:
        return f"Error: Command not found: {cmd_name}"
    except Exception as e:
        return f"Error: {e}"


def send_message(base_path: Path, to: str, message: str) -> str:
    """Send message to another worker"""
    messages_dir = base_path / "messages"
    messages_dir.mkdir(parents=True, exist_ok=True)

    msg_file = messages_dir / f"to_{to}.txt"
    timestamp = datetime.datetime.now().isoformat()
    entry = f"\n[{timestamp}]\n{message}\n"

    with open(msg_file, "a") as f:
        f.write(entry)

    return f"Message sent to {to}"


# Tool definitions for LLM
TOOL_DEFINITIONS = [
    {
        "name": "write_file",
        "description": "Write content to a file",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "read_file",
        "description": "Read a file",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path"}
            },
            "required": ["path"]
        }
    },
    {
        "name": "list_files",
        "description": "List files in directory",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Directory path", "default": "."}
            }
        }
    },
    {
        "name": "run_command",
        "description": f"Run shell command. Allowed: {ALLOWED_COMMANDS}",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Command to run"}
            },
            "required": ["command"]
        }
    },
    {
        "name": "send_message",
        "description": "Send a message to another worker (chef, frontend, backend)",
        "input_schema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Worker to send to"},
                "message": {"type": "string", "description": "Message content"}
            },
            "required": ["to", "message"]
        }
    }
]


def execute_tool(base_path: Path, name: str, args: dict) -> str:
    """Execute a tool by name"""
    if name == "write_file":
        return write_file(base_path, args["path"], args["content"])
    elif name == "read_file":
        return read_file(base_path, args["path"])
    elif name == "list_files":
        return list_files(base_path, args.get("path", "."))
    elif name == "run_command":
        return run_command(base_path, args["command"])
    elif name == "send_message":
        return send_message(base_path, args["to"], args["message"])
    else:
        return f"Unknown tool: {name}"
