"""Tools that AI workers can use"""
import subprocess
import datetime
from pathlib import Path

from apex_server.config import get_settings

settings = get_settings()
STORAGE = Path(settings.storage_path)
ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip"]


def write_file(base_path: Path, path: str, content: str) -> str:
    """Write content to a file"""
    full_path = base_path / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return f"Wrote {len(content)} bytes to {path}"


def read_file(base_path: Path, path: str) -> str:
    """Read a file"""
    full_path = base_path / path
    if not full_path.exists():
        return f"Error: File not found: {path}"
    return full_path.read_text()


def list_files(base_path: Path, path: str = ".") -> str:
    """List files in directory"""
    full_path = base_path / path
    if not full_path.exists():
        return f"Error: Directory not found: {path}"

    files = []
    for f in full_path.rglob("*"):
        if f.is_file() and ".git" not in str(f):
            files.append(str(f.relative_to(base_path)))

    return "\n".join(files[:100]) if files else "(empty)"


def run_command(base_path: Path, command: str) -> str:
    """Run a shell command"""
    cmd_start = command.split()[0] if command.split() else ""
    if cmd_start not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_start}"

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
