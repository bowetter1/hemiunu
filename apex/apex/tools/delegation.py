"""
Delegation tools - assign_* for all roles
assign_ad, assign_architect, assign_backend, assign_frontend, assign_parallel, assign_reviewer, assign_tester, assign_security, assign_devops
"""
import re
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


def _extract_files_from_result(result: str) -> list[str]:
    """Extract file names mentioned in worker result."""
    # Common patterns for file creation/modification
    patterns = [
        r"(?:created?|wrote|updated?|modified?|saved?)\s+[`'\"]?(\S+\.\w{2,4})[`'\"]?",
        r"[`'\"](\S+\.\w{2,4})[`'\"]",  # Files in quotes/backticks
    ]
    files = set()
    for pattern in patterns:
        matches = re.findall(pattern, result, re.IGNORECASE)
        for m in matches:
            # Filter out common false positives
            if not any(x in m.lower() for x in ['http', 'localhost', 'example', '.com', '.org']):
                files.add(m)
    return list(files)[:5]  # Max 5 files


def _extract_feedback_status(result: str) -> tuple[str, str]:
    """Extract feedback status from worker result.

    Returns: (status, message) where status is one of:
    - 'done' - Worker completed successfully
    - 'need_clarification' - Worker needs clarification
    - 'blocked' - Worker is blocked
    - 'unknown' - No status found
    """
    lines = result.strip().split('\n')

    for line in lines:
        line_stripped = line.strip()
        # Check for the three status patterns
        if line_stripped.startswith('✅ DONE:'):
            return ('done', line_stripped[8:].strip())
        elif line_stripped.startswith('⚠️ NEED_CLARIFICATION:'):
            return ('need_clarification', line_stripped[22:].strip())
        elif line_stripped.startswith('🚫 BLOCKED:'):
            return ('blocked', line_stripped[11:].strip())

    return ('unknown', '')


def _summarize_result(result: str, max_len: int = 150) -> str:
    """Create a short summary of worker result."""
    # First check for structured feedback
    status, message = _extract_feedback_status(result)
    if status != 'unknown' and message:
        return message[:max_len]

    # Try to find key phrases
    lines = result.strip().split('\n')

    # Look for conclusion/summary lines
    for line in lines:
        lower = line.lower()
        if any(word in lower for word in ['created', 'done', 'complete', 'approved', 'finished', 'implemented']):
            clean = line.strip()[:max_len]
            if len(clean) > 20:
                return clean

    # Fallback: first non-empty meaningful line
    for line in lines:
        clean = line.strip()
        if len(clean) > 20 and not clean.startswith('#'):
            return clean[:max_len]

    return result[:max_len]


def _log_worker_complete(cwd: str, worker: str, task: str, result: str):
    """Log worker completion with summary and files."""
    emoji = WORKER_EMOJI.get(worker, "👤")
    summary = _summarize_result(result)
    files = _extract_files_from_result(result)
    status, status_msg = _extract_feedback_status(result)

    # Determine status emoji
    if status == 'done':
        status_emoji = "✅"
    elif status == 'need_clarification':
        status_emoji = "⚠️ NEED_CLARIFICATION"
    elif status == 'blocked':
        status_emoji = "🚫 BLOCKED"
    else:
        status_emoji = "✅"  # Default to done

    # Main completion log
    log_to_sprint(cwd, f"{emoji} {worker.upper()}: {task[:40]}... {status_emoji}")

    # Log summary (what they did)
    log_to_sprint(cwd, f"   ↳ {summary}")

    # Log files if any
    if files:
        log_to_sprint(cwd, f"   ↳ Files: {', '.join(files)}")

    # Log special status if not done
    if status == 'need_clarification':
        log_to_sprint(cwd, f"   ⚠️ QUESTION: {status_msg}")
    elif status == 'blocked':
        log_to_sprint(cwd, f"   🚫 BLOCKER: {status_msg}")


def assign_ad(arguments: dict, cwd: str) -> dict:
    """Assign AD (Art Director) a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("ad")

    prompt = load_prompt("ad", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="ad")

    _log_worker_complete(cwd, "ad", task, result)
    return make_response(f"🎨 AD responds:\n\n{result}")


def assign_architect(arguments: dict, cwd: str) -> dict:
    """Assign Architect a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("architect")

    prompt = load_prompt("architect", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="architect")

    _log_worker_complete(cwd, "architect", task, result)
    return make_response(f"🏗️ Architect responds:\n\n{result}")


def assign_backend(arguments: dict, cwd: str) -> dict:
    """Assign Backend developer a task."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    cli = get_worker_cli("backend")

    prompt = load_prompt("backend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="backend")

    _log_worker_complete(cwd, "backend", task, result)
    return make_response(f"⚙️ Backend responds:\n\n{result}")


def assign_frontend(arguments: dict, cwd: str) -> dict:
    """Assign Frontend developer a task."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    cli = get_worker_cli("frontend")

    prompt = load_prompt("frontend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="frontend")

    _log_worker_complete(cwd, "frontend", task, result)
    return make_response(f"🖼️ Frontend responds:\n\n{result}")


def assign_parallel(arguments: dict, cwd: str) -> dict:
    """Run multiple workers in parallel."""
    assignments = arguments.get("assignments", [])
    if not assignments:
        return make_response("No assignments given")

    results = []
    worker_summaries = []  # For final summary

    log_to_sprint(cwd, f"⚡ STARTING {len(assignments)} PARALLEL TASKS...")

    with ThreadPoolExecutor(max_workers=len(assignments)) as executor:
        futures = {}
        for a in assignments:
            worker = a.get("worker", "backend")
            task = a.get("task", "")
            context = a.get("context", "")
            file = a.get("file", "")
            cli = get_worker_cli(worker)

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

                # Log with summary
                _log_worker_complete(cwd, worker, task, result)

                # Collect for final summary
                summary = _summarize_result(result, 80)
                files = _extract_files_from_result(result)
                worker_summaries.append({
                    "worker": worker,
                    "summary": summary,
                    "files": files
                })

            except Exception as e:
                results.append(f"**{worker.upper()}**: ERROR - {e}")
                log_to_sprint(cwd, f"{emoji} {worker.upper()}: ERROR - {e}")

    # Log final summary
    log_to_sprint(cwd, f"⚡ PARALLEL WORK COMPLETE ({len(assignments)} workers)")
    log_to_sprint(cwd, "─" * 40)
    log_to_sprint(cwd, "📋 SUMMARY:")
    for ws in worker_summaries:
        emoji = WORKER_EMOJI.get(ws["worker"], "👤")
        files_str = f" → {', '.join(ws['files'])}" if ws['files'] else ""
        log_to_sprint(cwd, f"   {emoji} {ws['worker'].upper()}: {ws['summary'][:60]}{files_str}")
    log_to_sprint(cwd, "─" * 40)

    return make_response(f"⚡ PARALLEL WORK COMPLETE\n\n" + "\n\n---\n\n".join(results))


def assign_reviewer(arguments: dict, cwd: str) -> dict:
    """Ask Reviewer to review code."""
    files = arguments.get("files_to_review", [])
    focus = arguments.get("focus", "general quality")
    cli = get_worker_cli("reviewer")

    files_str = ", ".join(files)
    prompt = load_prompt("reviewer", files=files_str, focus=focus, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="reviewer")

    _log_worker_complete(cwd, "reviewer", f"Review {files_str}", result)
    return make_response(f"🔍 Reviewer responds:\n\n{result}")


def assign_tester(arguments: dict, cwd: str) -> dict:
    """Assign Tester a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("tester")

    prompt = load_prompt("tester", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="tester")

    _log_worker_complete(cwd, "tester", task, result)
    return make_response(f"🧪 Tester responds:\n\n{result}")


def assign_security(arguments: dict, cwd: str) -> dict:
    """Security audit."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("security")

    prompt = load_prompt("security", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="security")

    _log_worker_complete(cwd, "security", task, result)
    return make_response(f"🔐 Security responds:\n\n{result}")


def assign_devops(arguments: dict, cwd: str) -> dict:
    """Assign DevOps a task."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    cli = get_worker_cli("devops")

    prompt = load_prompt("devops", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="devops")

    _log_worker_complete(cwd, "devops", task, result)
    return make_response(f"🚀 DevOps responds:\n\n{result}")


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
