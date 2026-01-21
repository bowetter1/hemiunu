"""
Proof of Concept: LLM API med CLI Tools

Testar att:
1. Anropa LLM API (Anthropic Claude)
2. LLM får tools (write_file, run_command, read_file)
3. LLM använder git via tools

Kör: python poc/llm_with_tools.py
"""

import os
import subprocess
import json
from pathlib import Path
from anthropic import Anthropic

# === CONFIGURATION ===
WORK_DIR = Path(__file__).parent / "workspace"
ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch"]


# === TOOLS ===

def write_file(path: str, content: str) -> str:
    """Write content to a file"""
    full_path = WORK_DIR / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return f"✓ Wrote {len(content)} bytes to {path}"


def read_file(path: str) -> str:
    """Read a file"""
    full_path = WORK_DIR / path
    if not full_path.exists():
        return f"✗ File not found: {path}"
    return full_path.read_text()


def run_command(command: str) -> str:
    """Run a shell command"""
    cmd_start = command.split()[0] if command.split() else ""
    if cmd_start not in ALLOWED_COMMANDS:
        return f"✗ Command not allowed: {cmd_start}. Allowed: {ALLOWED_COMMANDS}"

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=WORK_DIR,
            capture_output=True,
            timeout=30,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return f"✗ Command timed out: {command}"
    except Exception as e:
        return f"✗ Error: {e}"


def list_files(path: str = ".") -> str:
    """List files in directory"""
    full_path = WORK_DIR / path
    if not full_path.exists():
        return f"✗ Directory not found: {path}"

    files = []
    for f in full_path.rglob("*"):
        if f.is_file():
            files.append(str(f.relative_to(WORK_DIR)))

    return "\n".join(files[:50]) if files else "(empty directory)"


# === TOOL DEFINITIONS (för Claude API) ===

TOOLS = [
    {
        "name": "write_file",
        "description": "Write content to a file. Creates directories if needed.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path relative to workspace"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "read_file",
        "description": "Read content from a file",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path relative to workspace"}
            },
            "required": ["path"]
        }
    },
    {
        "name": "run_command",
        "description": f"Run a shell command. Allowed commands: {ALLOWED_COMMANDS}",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "The command to run"}
            },
            "required": ["command"]
        }
    },
    {
        "name": "list_files",
        "description": "List all files in a directory",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Directory path (default: current)", "default": "."}
            }
        }
    }
]

# === TOOL EXECUTION ===

def execute_tool(name: str, args: dict) -> str:
    """Execute a tool by name"""
    tools_map = {
        "write_file": write_file,
        "read_file": read_file,
        "run_command": run_command,
        "list_files": list_files,
    }

    if name not in tools_map:
        return f"✗ Unknown tool: {name}"

    return tools_map[name](**args)


# === LLM ORCHESTRATOR ===

def run_with_tools(task: str, max_iterations: int = 10):
    """Kör LLM med tool loop"""

    client = Anthropic()

    # Skapa workspace
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"TASK: {task}")
    print(f"WORKSPACE: {WORK_DIR}")
    print(f"{'='*60}\n")

    messages = [{"role": "user", "content": task}]

    for i in range(max_iterations):
        print(f"\n--- Iteration {i+1} ---")

        # Anropa Claude
        response = client.messages.create(
            model="claude-opus-4-20250514",
            max_tokens=4096,
            system="Du är en utvecklare som använder tools för att utföra uppgifter. Använd tools för att skriva filer och köra kommandon. Var kortfattad.",
            tools=TOOLS,
            messages=messages
        )

        # Hantera response
        assistant_content = []
        has_tool_use = False

        for block in response.content:
            if block.type == "text":
                print(f"\nCLAUDE: {block.text}")
                assistant_content.append(block)

            elif block.type == "tool_use":
                has_tool_use = True
                tool_name = block.name
                tool_args = block.input
                tool_id = block.id

                print(f"\nTOOL CALL: {tool_name}")
                print(f"  Args: {json.dumps(tool_args, indent=2)}")

                # Kör tool
                result = execute_tool(tool_name, tool_args)
                print(f"  Result: {result[:200]}{'...' if len(result) > 200 else ''}")

                assistant_content.append(block)

                # Lägg till tool result
                messages.append({"role": "assistant", "content": assistant_content})
                messages.append({
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": tool_id,
                        "content": result
                    }]
                })
                assistant_content = []

        # Om inget tool use, är vi klara
        if not has_tool_use:
            if assistant_content:
                messages.append({"role": "assistant", "content": assistant_content})
            break

        # Check stop reason
        if response.stop_reason == "end_turn" and not has_tool_use:
            break

    print(f"\n{'='*60}")
    print("DONE!")
    print(f"{'='*60}\n")

    # Visa workspace-innehåll
    print("Workspace files:")
    print(list_files())


# === MAIN ===

if __name__ == "__main__":
    # Test: Skapa ett projekt och initiera git
    task = """
    Skapa en enkel Python-fil som heter hello.py med en hello world funktion.
    Sen initiera git, gör en commit med meddelandet "Initial commit".
    Visa git log när du är klar.
    """

    run_with_tools(task)
