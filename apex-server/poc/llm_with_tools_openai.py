"""
Proof of Concept: LLM API med CLI Tools (OpenAI/Qwen version)

Testar att:
1. Anropa LLM API (OpenAI eller Qwen via OpenAI-compatible API)
2. LLM får tools (write_file, run_command, read_file)
3. LLM använder git via tools

Kör:
  # Med OpenAI:
  export OPENAI_API_KEY=sk-xxx
  python poc/llm_with_tools_openai.py

  # Med Qwen (Alibaba):
  export OPENAI_API_KEY=sk-xxx
  export OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
  python poc/llm_with_tools_openai.py --model qwen-plus
"""

import os
import subprocess
import json
import argparse
from pathlib import Path
from openai import OpenAI

# === CONFIGURATION ===
WORK_DIR = Path(__file__).parent / "workspace"
ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch"]


# === TOOLS ===

def write_file(path: str, content: str) -> str:
    """Write content to a file"""
    full_path = WORK_DIR / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return f"Wrote {len(content)} bytes to {path}"


def read_file(path: str) -> str:
    """Read a file"""
    full_path = WORK_DIR / path
    if not full_path.exists():
        return f"Error: File not found: {path}"
    return full_path.read_text()


def run_command(command: str) -> str:
    """Run a shell command"""
    cmd_start = command.split()[0] if command.split() else ""
    if cmd_start not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_start}. Allowed: {ALLOWED_COMMANDS}"

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
        return f"Error: Command timed out: {command}"
    except Exception as e:
        return f"Error: {e}"


def list_files(path: str = ".") -> str:
    """List files in directory"""
    full_path = WORK_DIR / path
    if not full_path.exists():
        return f"Error: Directory not found: {path}"

    files = []
    for f in full_path.rglob("*"):
        if f.is_file():
            files.append(str(f.relative_to(WORK_DIR)))

    return "\n".join(files[:50]) if files else "(empty directory)"


# === TOOL DEFINITIONS (OpenAI format) ===

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file. Creates directories if needed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "File path relative to workspace"},
                    "content": {"type": "string", "description": "Content to write"}
                },
                "required": ["path", "content"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read content from a file",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "File path relative to workspace"}
                },
                "required": ["path"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": f"Run a shell command. Allowed commands: {ALLOWED_COMMANDS}",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "The command to run"}
                },
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "List all files in a directory",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Directory path (default: current)"}
                }
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
        return f"Error: Unknown tool: {name}"

    # Handle missing optional args
    if name == "list_files" and "path" not in args:
        args["path"] = "."

    return tools_map[name](**args)


# === LLM ORCHESTRATOR ===

def run_with_tools(task: str, model: str = "gpt-4o", max_iterations: int = 10):
    """Kör LLM med tool loop"""

    client = OpenAI()

    # Skapa workspace
    WORK_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n{'='*60}")
    print(f"TASK: {task}")
    print(f"MODEL: {model}")
    print(f"WORKSPACE: {WORK_DIR}")
    print(f"{'='*60}\n")

    messages = [
        {
            "role": "system",
            "content": "Du är en utvecklare som använder tools för att utföra uppgifter. Använd tools för att skriva filer och köra kommandon. Var kortfattad."
        },
        {"role": "user", "content": task}
    ]

    for i in range(max_iterations):
        print(f"\n--- Iteration {i+1} ---")

        # Anropa LLM
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            tools=TOOLS,
            tool_choice="auto"
        )

        message = response.choices[0].message

        # Visa text-svar
        if message.content:
            print(f"\nLLM: {message.content}")

        # Kolla om det finns tool calls
        if not message.tool_calls:
            messages.append({"role": "assistant", "content": message.content or ""})
            break

        # Hantera tool calls
        messages.append(message)  # Lägg till assistant message med tool_calls

        for tool_call in message.tool_calls:
            tool_name = tool_call.function.name
            tool_args = json.loads(tool_call.function.arguments)

            print(f"\nTOOL CALL: {tool_name}")
            print(f"  Args: {json.dumps(tool_args, indent=2)}")

            # Kör tool
            result = execute_tool(tool_name, tool_args)
            print(f"  Result: {result[:300]}{'...' if len(result) > 300 else ''}")

            # Lägg till tool result
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": result
            })

        # Check finish reason
        if response.choices[0].finish_reason == "stop":
            break

    print(f"\n{'='*60}")
    print("DONE!")
    print(f"{'='*60}\n")

    # Visa workspace-innehåll
    print("Workspace files:")
    print(list_files())


# === MAIN ===

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="gpt-4o", help="Model to use (gpt-4o, qwen-plus, etc)")
    parser.add_argument("--task", default=None, help="Task to run")
    args = parser.parse_args()

    # Default test task
    task = args.task or """
    Skapa en enkel Python-fil som heter hello.py med en hello world funktion.
    Sen initiera git, gör en commit med meddelandet "Initial commit".
    Visa git log när du är klar.
    """

    run_with_tools(task, model=args.model)
