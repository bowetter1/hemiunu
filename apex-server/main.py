"""
Apex Server - POC med Memory + Multi-Agent
Test av LLM + CLI tools + Mem0 + Agent koordinering på Railway
"""

import os
import subprocess
import json
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from anthropic import Anthropic
from mem0 import Memory

app = FastAPI(title="Apex Server POC")

# === WORKER PROMPTS ===
WORKER_PROMPTS = {
    "chef": """Du är CHEF - projektledare för ett utvecklingsteam.

Ditt jobb:
1. Analysera uppgiften och bryt ner den i delar
2. Delegera till Frontend och Backend workers via send_message
3. Koordinera arbetet och se till att allt hänger ihop
4. Sammanfatta resultatet när alla är klara

Du har två workers:
- "frontend": Bygger UI och klient-kod
- "backend": Bygger API och server-kod

Använd send_message för att ge instruktioner och få svar.
Läs filer som workers skapar för att verifiera arbetet.""",

    "frontend": """Du är FRONTEND WORKER - expert på UI och klient-kod.

Ditt jobb:
1. Läs meddelanden från Chef via read_file("messages/to_frontend.txt")
2. Skapa frontend-filer i frontend/ mappen
3. Svara Chef via send_message("chef", "ditt svar")
4. Koordinera med Backend om du behöver API-info

Skriv ren, modern kod. Använd TypeScript/React om inget annat anges.""",

    "backend": """Du är BACKEND WORKER - expert på API och server-kod.

Ditt jobb:
1. Läs meddelanden från Chef via read_file("messages/to_backend.txt")
2. Skapa backend-filer i backend/ mappen
3. Svara Chef via send_message("chef", "ditt svar")
4. Dokumentera API endpoints så Frontend vet hur de ska användas

Skriv ren, effektiv kod. Använd Python/FastAPI om inget annat anges."""
}

# === CONFIG ===
WORKSPACE = Path("/app/storage")
ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip"]

# === MEM0 CONFIG ===
QDRANT_HOST = os.environ.get("QDRANT_HOST", "qdrant.railway.internal")
QDRANT_PORT = int(os.environ.get("QDRANT_PORT", "6333"))

mem0_config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "host": QDRANT_HOST,
            "port": QDRANT_PORT,
            "collection_name": "apex_memories_v2",
        }
    },
    "embedder": {
        "provider": "openai",
        "config": {
            "model": "text-embedding-3-small"
        }
    }
}

# Initialize memory (lazy)
_memory = None

def get_memory():
    global _memory
    if _memory is None:
        try:
            print(f"Initializing memory with config: {mem0_config}")
            _memory = Memory.from_config(mem0_config)
            print("Memory initialized successfully!")
        except Exception as e:
            import traceback
            print(f"Memory init failed: {e}")
            print(traceback.format_exc())
            return None
    return _memory


# === TOOLS ===

def write_file(path: str, content: str) -> str:
    full_path = WORKSPACE / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return f"Wrote {len(content)} bytes to {path}"


def read_file(path: str) -> str:
    full_path = WORKSPACE / path
    if not full_path.exists():
        return f"Error: File not found: {path}"
    return full_path.read_text()


def run_command(command: str) -> str:
    cmd_start = command.split()[0] if command.split() else ""
    if cmd_start not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_start}"

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=WORKSPACE,
            capture_output=True,
            timeout=60,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return f"Error: Command timed out"
    except Exception as e:
        return f"Error: {e}"


def list_files(path: str = ".") -> str:
    full_path = WORKSPACE / path
    if not full_path.exists():
        return f"Error: Directory not found: {path}"

    files = []
    for f in full_path.rglob("*"):
        if f.is_file() and ".git" not in str(f):
            files.append(str(f.relative_to(WORKSPACE)))

    return "\n".join(files[:100]) if files else "(empty)"


def send_message(to: str, message: str) -> str:
    """Skicka meddelande till en annan worker"""
    messages_dir = WORKSPACE / "messages"
    messages_dir.mkdir(parents=True, exist_ok=True)

    msg_file = messages_dir / f"to_{to}.txt"

    # Append message with timestamp
    import datetime
    timestamp = datetime.datetime.now().isoformat()
    entry = f"\n[{timestamp}]\n{message}\n"

    with open(msg_file, "a") as f:
        f.write(entry)

    return f"Message sent to {to}"


# === TOOL DEFINITIONS ===

TOOLS = [
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
        "name": "send_message",
        "description": "Send a message to another worker (chef, frontend, backend)",
        "input_schema": {
            "type": "object",
            "properties": {
                "to": {"type": "string", "description": "Worker to send to: chef, frontend, or backend"},
                "message": {"type": "string", "description": "Message content"}
            },
            "required": ["to", "message"]
        }
    }
]


def execute_tool(name: str, args: dict) -> str:
    tools_map = {
        "write_file": write_file,
        "read_file": read_file,
        "run_command": run_command,
        "list_files": list_files,
        "send_message": send_message,
    }
    if name not in tools_map:
        return f"Unknown tool: {name}"

    if name == "list_files" and "path" not in args:
        args["path"] = "."

    return tools_map[name](**args)


# === LLM ORCHESTRATOR ===

def run_llm_task(task: str, user_id: str = "default", max_iterations: int = 15) -> dict:
    """Kör LLM med tool loop och memory"""

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return {"error": "ANTHROPIC_API_KEY not set"}

    client = Anthropic(api_key=api_key)
    memory = get_memory()

    WORKSPACE.mkdir(parents=True, exist_ok=True)

    # Hämta relevant kontext från minne
    context = ""
    if memory:
        try:
            result = memory.search(task, user_id=user_id, limit=5)
            # Handle both list and dict responses
            memories = result.get("results", result) if isinstance(result, dict) else result
            if memories and len(memories) > 0:
                context = "\n\n## Relevant memories about this user:\n"
                for m in memories:
                    if isinstance(m, dict) and "memory" in m:
                        context += f"- {m['memory']}\n"
                print(f"Found {len(memories)} memories: {context}")
        except Exception as e:
            print(f"Memory search failed: {e}")
            context = ""

    system_prompt = f"""Du är en utvecklare. Använd tools för att utföra uppgifter. Var effektiv och kortfattad.
{context}"""

    messages = [{"role": "user", "content": task}]
    log = []

    for i in range(max_iterations):
        log.append(f"--- Iteration {i+1} ---")

        response = client.messages.create(
            model="claude-opus-4-20250514",
            max_tokens=4096,
            system=system_prompt,
            tools=TOOLS,
            messages=messages
        )

        assistant_content = []
        has_tool_use = False
        final_text = ""

        for block in response.content:
            if block.type == "text":
                log.append(f"LLM: {block.text}")
                final_text = block.text
                assistant_content.append(block)

            elif block.type == "tool_use":
                has_tool_use = True
                tool_name = block.name
                tool_args = block.input
                tool_id = block.id

                log.append(f"TOOL: {tool_name}({json.dumps(tool_args)})")

                result = execute_tool(tool_name, tool_args)
                log.append(f"RESULT: {result[:500]}")

                assistant_content.append(block)
                messages.append({"role": "assistant", "content": assistant_content})
                messages.append({
                    "role": "user",
                    "content": [{"type": "tool_result", "tool_use_id": tool_id, "content": result}]
                })
                assistant_content = []

        if not has_tool_use:
            if assistant_content:
                messages.append({"role": "assistant", "content": assistant_content})

            # Spara till minne
            if memory and final_text:
                try:
                    memory.add(
                        f"Task: {task}\nResult: {final_text}",
                        user_id=user_id,
                        metadata={"type": "task_completion"}
                    )
                    log.append("(Saved to memory)")
                except Exception as e:
                    log.append(f"(Memory save failed: {e})")

            break

    return {
        "log": log,
        "files": list_files(),
        "iterations": i + 1,
        "user_id": user_id
    }


# === API ENDPOINTS ===

@app.get("/health")
def health():
    return {"status": "ok", "workspace": str(WORKSPACE)}


@app.get("/cli-check")
def cli_check():
    tools = {}
    for cmd in ["git", "gh", "railway", "node", "npm", "python"]:
        result = subprocess.run(f"which {cmd}", shell=True, capture_output=True, text=True)
        tools[cmd] = result.stdout.strip() if result.returncode == 0 else "not found"
    return tools


@app.get("/memory-check")
def memory_check():
    """Kolla om Mem0/Qdrant fungerar"""
    memory = get_memory()
    if memory is None:
        return {"status": "error", "message": "Memory not initialized"}

    try:
        # Test add and search
        memory.add("Test memory entry", user_id="test")
        results = memory.search("test", user_id="test", limit=1)
        return {
            "status": "ok",
            "qdrant_host": QDRANT_HOST,
            "qdrant_port": QDRANT_PORT,
            "test_results": len(results) if results else 0
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


class TaskRequest(BaseModel):
    task: str
    user_id: str = "default"


@app.post("/run")
def run_task(req: TaskRequest):
    try:
        result = run_llm_task(req.task, user_id=req.user_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


class MemoryRequest(BaseModel):
    content: str
    user_id: str = "default"


@app.post("/memory/add")
def add_memory(req: MemoryRequest):
    """Lägg till manuellt minne"""
    memory = get_memory()
    if memory is None:
        raise HTTPException(status_code=500, detail="Memory not available")

    try:
        memory.add(req.content, user_id=req.user_id)
        return {"status": "ok", "message": "Memory added"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/memory/search")
def search_memory(query: str, user_id: str = "default"):
    """Sök i minnet"""
    memory = get_memory()
    if memory is None:
        raise HTTPException(status_code=500, detail="Memory not available")

    try:
        results = memory.search(query, user_id=user_id, limit=10)
        return {"results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/memory/all")
def get_all_memories(user_id: str = "default"):
    """Hämta alla minnen för en user"""
    memory = get_memory()
    if memory is None:
        raise HTTPException(status_code=500, detail="Memory not available")

    try:
        results = memory.get_all(user_id=user_id)
        return {"memories": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/files")
def get_files():
    return {"files": list_files()}


@app.get("/files/{path:path}")
def get_file(path: str):
    content = read_file(path)
    if content.startswith("Error:"):
        raise HTTPException(status_code=404, detail=content)
    return {"path": path, "content": content}


# === MULTI-AGENT SPRINT ===

def run_worker(worker_name: str, task: str, max_iterations: int = 10) -> dict:
    """Kör en specifik worker med sin prompt"""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return {"error": "ANTHROPIC_API_KEY not set"}

    client = Anthropic(api_key=api_key)
    WORKSPACE.mkdir(parents=True, exist_ok=True)

    system_prompt = WORKER_PROMPTS.get(worker_name, "Du är en utvecklare.")
    messages = [{"role": "user", "content": task}]
    log = []

    for i in range(max_iterations):
        log.append(f"--- {worker_name.upper()} Iteration {i+1} ---")

        response = client.messages.create(
            model="claude-opus-4-20250514",
            max_tokens=4096,
            system=system_prompt,
            tools=TOOLS,
            messages=messages
        )

        assistant_content = []
        has_tool_use = False
        final_text = ""

        for block in response.content:
            if block.type == "text":
                log.append(f"{worker_name.upper()}: {block.text}")
                final_text = block.text
                assistant_content.append(block)

            elif block.type == "tool_use":
                has_tool_use = True
                tool_name = block.name
                tool_args = block.input
                tool_id = block.id

                log.append(f"TOOL: {tool_name}({json.dumps(tool_args)[:200]})")

                result = execute_tool(tool_name, tool_args)
                log.append(f"RESULT: {result[:300]}")

                assistant_content.append(block)
                messages.append({"role": "assistant", "content": assistant_content})
                messages.append({
                    "role": "user",
                    "content": [{"type": "tool_result", "tool_use_id": tool_id, "content": result}]
                })
                assistant_content = []

        if not has_tool_use:
            if assistant_content:
                messages.append({"role": "assistant", "content": assistant_content})
            break

    return {
        "worker": worker_name,
        "log": log,
        "iterations": i + 1,
        "final_response": final_text
    }


class SprintRequest(BaseModel):
    task: str


@app.post("/sprint")
def run_sprint(req: SprintRequest):
    """Kör en multi-agent sprint med Chef, Frontend och Backend"""
    try:
        # Rensa gamla meddelanden
        messages_dir = WORKSPACE / "messages"
        if messages_dir.exists():
            for f in messages_dir.glob("*.txt"):
                f.unlink()

        all_logs = []

        # 1. Chef analyserar och delegerar
        all_logs.append("=" * 50)
        all_logs.append("PHASE 1: CHEF PLANNING")
        all_logs.append("=" * 50)

        chef_result = run_worker(
            "chef",
            f"""Uppgift från användaren: {req.task}

Gör följande:
1. Analysera uppgiften
2. Skicka instruktioner till frontend via send_message("frontend", "dina instruktioner")
3. Skicka instruktioner till backend via send_message("backend", "dina instruktioner")
4. Berätta vad du delegerat""",
            max_iterations=8
        )
        all_logs.extend(chef_result["log"])

        # 2. Backend worker
        all_logs.append("")
        all_logs.append("=" * 50)
        all_logs.append("PHASE 2: BACKEND WORKER")
        all_logs.append("=" * 50)

        backend_task = read_file("messages/to_backend.txt")
        backend_result = run_worker(
            "backend",
            f"""Du har fått följande instruktioner från Chef:

{backend_task}

Utför uppgiften:
1. Skapa backend-filer i backend/ mappen
2. Svara Chef via send_message("chef", "din rapport")""",
            max_iterations=8
        )
        all_logs.extend(backend_result["log"])

        # 3. Frontend worker
        all_logs.append("")
        all_logs.append("=" * 50)
        all_logs.append("PHASE 3: FRONTEND WORKER")
        all_logs.append("=" * 50)

        frontend_task = read_file("messages/to_frontend.txt")
        frontend_result = run_worker(
            "frontend",
            f"""Du har fått följande instruktioner från Chef:

{frontend_task}

Utför uppgiften:
1. Läs backend/api.py för att se vilka endpoints som finns (om det finns)
2. Skapa frontend-filer i frontend/ mappen
3. Svara Chef via send_message("chef", "din rapport")""",
            max_iterations=8
        )
        all_logs.extend(frontend_result["log"])

        # 4. Chef sammanfattar
        all_logs.append("")
        all_logs.append("=" * 50)
        all_logs.append("PHASE 4: CHEF SUMMARY")
        all_logs.append("=" * 50)

        chef_messages = read_file("messages/to_chef.txt")
        summary_result = run_worker(
            "chef",
            f"""Workers har rapporterat tillbaka:

{chef_messages}

Läs filerna som skapades (list_files, read_file) och ge en sammanfattning av vad som byggdes.""",
            max_iterations=5
        )
        all_logs.extend(summary_result["log"])

        return {
            "status": "completed",
            "log": all_logs,
            "files": list_files(),
            "summary": summary_result.get("final_response", "")
        }

    except Exception as e:
        import traceback
        return {
            "status": "error",
            "error": str(e),
            "traceback": traceback.format_exc()
        }
