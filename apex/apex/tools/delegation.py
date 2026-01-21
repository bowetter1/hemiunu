"""
Delegation tools - assign_* for all roles
assign_ad, assign_architect, assign_backend, assign_frontend, assign_parallel, assign_reviewer, assign_tester, assign_security, assign_devops
"""
from concurrent.futures import ThreadPoolExecutor, as_completed

from core.config import get_worker_cli
from prompts import load_prompt
from .base import run_cli, make_response, log_to_sprint


TOOLS = [
    {
        "name": "assign_ad",
        "description": "Assign AD (Art Director) a task. Good for design guidelines, UX, colors, typography.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "The design task"},
                "context": {"type": "string", "description": "Extra context about the project"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_architect",
        "description": "Assign Architect a task. Good for planning, structure, technical design.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "The task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_backend",
        "description": "Assign Backend developer a task. Builds API that frontend uses. RUN FIRST!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. main.py)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_frontend",
        "description": "Assign Frontend developer a task. Builds against EXISTING API. Run AFTER backend!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. index.html, app.js)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_parallel",
        "description": "Run MULTIPLE workers AT ONCE. Perfect for independent tasks like AD + Architect.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "assignments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "worker": {"type": "string", "enum": ["ad", "architect", "backend", "frontend", "tester", "reviewer", "security", "devops"], "description": "Which worker"},
                            "task": {"type": "string", "description": "The task"},
                            "context": {"type": "string", "description": "Extra context (optional)"},
                            "file": {"type": "string", "description": "File to work with (optional)"}
                        },
                        "required": ["worker", "task"]
                    },
                    "description": "List of assignments [{worker, task, context?, file?}]"
                }
            },
            "required": ["assignments"]
        }
    },
    {
        "name": "assign_reviewer",
        "description": "Ask Reviewer to review code.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "files_to_review": {"type": "array", "items": {"type": "string"}, "description": "Files to review"},
                "focus": {"type": "string", "description": "What to focus on?"}
            },
            "required": ["files_to_review"]
        }
    },
    {
        "name": "assign_tester",
        "description": "Tester WRITES test files (test_*.py). Run BEFORE run_tests()! Tester creates files, run_tests() runs them.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to test? E.g. 'Write tests for API endpoints'"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_security",
        "description": "Security audit - OWASP vulnerabilities, auth, input validation, secrets exposure.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Security audit task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_devops",
        "description": "Assign DevOps a task. Good for infra, CI/CD, config, monitoring, deploy.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "The DevOps task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
]


def assign_ad(arguments: dict, cwd: str) -> dict:
    """Assign AD (Art Director) a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("ad")  # Use config.py default

    prompt = load_prompt("ad", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="ad")

    log_to_sprint(cwd, f"🎨 AD: {task[:50]}...")
    return make_response(f"🎨 AD svarar:\n\n{result}")


def assign_architect(arguments: dict, cwd: str) -> dict:
    """Assign Architect a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("architect")  # Use config.py default

    prompt = load_prompt("architect", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="architect")

    log_to_sprint(cwd, f"🏗️ Architect: {task[:50]}...")
    return make_response(f"🏗️ Architect svarar:\n\n{result}")


def assign_backend(arguments: dict, cwd: str) -> dict:
    """Assign Backend developer a task."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    cli = get_worker_cli("backend")  # Use config.py default (gemini)

    prompt = load_prompt("backend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="backend")

    log_to_sprint(cwd, f"⚙️ Backend: {task[:50]}...")
    return make_response(f"⚙️ Backend svarar:\n\n{result}")


def assign_frontend(arguments: dict, cwd: str) -> dict:
    """Assign Frontend developer a task."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    cli = get_worker_cli("frontend")  # Use config.py default

    prompt = load_prompt("frontend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="frontend")

    log_to_sprint(cwd, f"🖼️ Frontend: {task[:50]}...")
    return make_response(f"🖼️ Frontend svarar:\n\n{result}")


def assign_parallel(arguments: dict, cwd: str) -> dict:
    """Run multiple workers in parallel."""
    assignments = arguments.get("assignments", [])
    if not assignments:
        return make_response("No assignments given")

    # Worker emoji mapping
    WORKER_EMOJI = {
        "ad": "🎨",
        "architect": "🏗️",
        "backend": "⚙️",
        "frontend": "🖼️",
        "tester": "🧪",
        "reviewer": "🔍",
        "security": "🔐",
        "devops": "🚀",
    }

    results = []
    log_to_sprint(cwd, f"⚡ STARTING {len(assignments)} PARALLEL TASKS...")

    with ThreadPoolExecutor(max_workers=len(assignments)) as executor:
        futures = {}
        for a in assignments:
            worker = a.get("worker", "backend")
            task = a.get("task", "")
            context = a.get("context", "")
            file = a.get("file", "")
            cli = get_worker_cli(worker)  # Use config.py default

            # Load correct prompt for worker type
            try:
                if worker in ["backend", "frontend"]:
                    prompt = load_prompt(worker, task=task, file=file, project_dir=cwd)
                elif worker == "reviewer":
                    prompt = load_prompt(worker, files=file, focus=context, project_dir=cwd)
                else:
                    prompt = load_prompt(worker, task=task, context=context, project_dir=cwd)
            except ValueError:
                # Fallback if prompt is missing
                prompt = f"You are {worker.upper()}. Task: {task}"

            future = executor.submit(run_cli, cli, prompt, cwd, worker)
            futures[future] = (worker, cli, task)

        for future in as_completed(futures):
            worker, cli, task = futures[future]
            emoji = WORKER_EMOJI.get(worker, "👤")
            try:
                result = future.result()
                results.append(f"**{worker.upper()}** ({cli}):\n{result[:500]}...")
                log_to_sprint(cwd, f"{emoji} {worker.upper()}: {task[:30]}... ✅")
            except Exception as e:
                results.append(f"**{worker.upper()}**: ERROR - {e}")
                log_to_sprint(cwd, f"{emoji} {worker.upper()}: ERROR - {e}")

    log_to_sprint(cwd, f"⚡ PARALLEL WORK COMPLETE ({len(assignments)} workers)")
    return make_response(f"⚡ PARALLEL WORK COMPLETE\n\n" + "\n\n---\n\n".join(results))


def assign_reviewer(arguments: dict, cwd: str) -> dict:
    """Ask Reviewer to review code."""
    files = arguments.get("files_to_review", [])
    focus = arguments.get("focus", "allmän kvalitet")
    cli = get_worker_cli("reviewer")  # Use config.py default (gemini)

    files_str = ", ".join(files)
    prompt = load_prompt("reviewer", files=files_str, focus=focus, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="reviewer")

    log_to_sprint(cwd, f"🔍 Reviewer: {files_str[:50]}...")
    return make_response(f"🔍 Reviewer svarar:\n\n{result}")


def assign_tester(arguments: dict, cwd: str) -> dict:
    """Assign Tester a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("tester")  # Use config.py default

    prompt = load_prompt("tester", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="tester")

    log_to_sprint(cwd, f"🧪 Tester: {task[:50]}...")
    return make_response(f"🧪 Tester svarar:\n\n{result}")


def assign_security(arguments: dict, cwd: str) -> dict:
    """Security audit."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("security")  # Use config.py default (gemini)

    prompt = load_prompt("security", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="security")

    log_to_sprint(cwd, f"🔐 Security: {task[:50]}...")
    return make_response(f"🔐 Security svarar:\n\n{result}")


def assign_devops(arguments: dict, cwd: str) -> dict:
    """Assign DevOps a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("devops")  # Use config.py default

    prompt = load_prompt("devops", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="devops")

    log_to_sprint(cwd, f"🚀 DevOps: {task[:50]}...")
    return make_response(f"🚀 DevOps svarar:\n\n{result}")


HANDLERS = {
    "assign_ad": assign_ad,
    "assign_architect": assign_architect,
    "assign_backend": assign_backend,
    "assign_frontend": assign_frontend,
    "assign_parallel": assign_parallel,
    "assign_reviewer": assign_reviewer,
    "assign_tester": assign_tester,
    "assign_security": assign_security,
    "assign_devops": assign_devops,
}
