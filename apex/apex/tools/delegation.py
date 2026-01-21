"""
Delegation tools - assign_* för alla roller
assign_ad, assign_architect, assign_backend, assign_frontend, assign_parallel, assign_reviewer, assign_tester, assign_devops
"""
from concurrent.futures import ThreadPoolExecutor, as_completed

from core.config import get_worker_cli
from prompts import load_prompt
from .base import run_cli, make_response, log_to_sprint


TOOLS = [
    {
        "name": "assign_ad",
        "description": "Ge AD (Art Director) ett uppdrag. Bra för design-riktlinjer, UX, färger, typografi.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Design-uppdraget"},
                "context": {"type": "string", "description": "Extra kontext om projektet"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_architect",
        "description": "Ge Architect ett uppdrag. Bra för planering, struktur, design.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Uppdraget"},
                "context": {"type": "string", "description": "Extra kontext"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_backend",
        "description": "Ge Backend-utvecklare ett uppdrag. Bygger API:et som frontend sedan använder. KÖR FÖRST!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Vad ska byggas?"},
                "file": {"type": "string", "description": "Vilken fil? (t.ex. main.py)"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_frontend",
        "description": "Ge Frontend-utvecklare ett uppdrag. Bygger mot EXISTERANDE API. Kör EFTER backend!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Vad ska byggas?"},
                "file": {"type": "string", "description": "Vilken fil? (t.ex. index.html, app.js)"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_parallel",
        "description": "Kör FLERA workers SAMTIDIGT. Perfekt för oberoende uppgifter som AD + Architect.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "assignments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "worker": {"type": "string", "enum": ["ad", "architect", "backend", "frontend", "tester", "reviewer", "devops"], "description": "Vilken worker"},
                            "task": {"type": "string", "description": "Uppgiften"},
                            "context": {"type": "string", "description": "Extra kontext (valfritt)"},
                            "file": {"type": "string", "description": "Fil att jobba med (valfritt)"},
                            "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI (valfritt)"}
                        },
                        "required": ["worker", "task"]
                    },
                    "description": "Lista med uppdrag [{worker, task, context?, file?, ai?}]"
                }
            },
            "required": ["assignments"]
        }
    },
    {
        "name": "assign_reviewer",
        "description": "Be Reviewer granska kod.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "files_to_review": {"type": "array", "items": {"type": "string"}, "description": "Filer att granska"},
                "focus": {"type": "string", "description": "Vad ska fokuseras på?"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["files_to_review"]
        }
    },
    {
        "name": "assign_tester",
        "description": "Tester SKRIVER testfiler (test_*.py). Kör INNAN run_tests()! Tester skapar filer, run_tests() kör dem.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Vad ska testas? T.ex. 'Skriv tester för API endpoints'"},
                "context": {"type": "string", "description": "Extra kontext"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_devops",
        "description": "Ge DevOps ett uppdrag. Bra för infra, CI/CD, config, monitoring.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "DevOps-uppdraget"},
                "context": {"type": "string", "description": "Extra kontext"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"], "description": "Vilken AI"}
            },
            "required": ["task"]
        }
    },
]


def assign_ad(arguments: dict, cwd: str) -> dict:
    """Ge AD (Art Director) ett uppdrag."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("ad", ai)

    prompt = load_prompt("ad", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="ad")

    log_to_sprint(cwd, f"🎨 AD: {task[:50]}...")
    return make_response(f"🎨 AD svarar:\n\n{result}")


def assign_architect(arguments: dict, cwd: str) -> dict:
    """Ge Architect ett uppdrag."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("architect", ai)

    prompt = load_prompt("architect", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="architect")

    log_to_sprint(cwd, f"🏗️ Architect: {task[:50]}...")
    return make_response(f"🏗️ Architect svarar:\n\n{result}")


def assign_backend(arguments: dict, cwd: str) -> dict:
    """Ge Backend-utvecklare ett uppdrag."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("backend", ai)

    prompt = load_prompt("backend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="backend")

    log_to_sprint(cwd, f"⚙️ Backend: {task[:50]}...")
    return make_response(f"⚙️ Backend svarar:\n\n{result}")


def assign_frontend(arguments: dict, cwd: str) -> dict:
    """Ge Frontend-utvecklare ett uppdrag."""
    task = arguments.get("task", "")
    file = arguments.get("file", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("frontend", ai)

    prompt = load_prompt("frontend", task=task, file=file, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="frontend")

    log_to_sprint(cwd, f"🖼️ Frontend: {task[:50]}...")
    return make_response(f"🖼️ Frontend svarar:\n\n{result}")


def assign_parallel(arguments: dict, cwd: str) -> dict:
    """Kör flera workers parallellt."""
    assignments = arguments.get("assignments", [])
    if not assignments:
        return make_response("Inga uppdrag givna")

    # Worker emoji mapping
    WORKER_EMOJI = {
        "ad": "🎨",
        "architect": "🏗️",
        "backend": "⚙️",
        "frontend": "🖼️",
        "tester": "🧪",
        "reviewer": "🔍",
        "devops": "🚀",
    }

    results = []
    log_to_sprint(cwd, f"⚡ STARTAR {len(assignments)} PARALLELLA UPPGIFTER...")

    with ThreadPoolExecutor(max_workers=len(assignments)) as executor:
        futures = {}
        for a in assignments:
            worker = a.get("worker", "backend")
            task = a.get("task", "")
            context = a.get("context", "")
            file = a.get("file", "")
            ai = a.get("ai")
            cli = get_worker_cli(worker, ai)

            # Ladda rätt prompt för worker-typen
            try:
                if worker in ["backend", "frontend"]:
                    prompt = load_prompt(worker, task=task, file=file, project_dir=cwd)
                elif worker == "reviewer":
                    prompt = load_prompt(worker, files=file, focus=context, project_dir=cwd)
                else:
                    prompt = load_prompt(worker, task=task, context=context, project_dir=cwd)
            except ValueError:
                # Fallback om prompt saknas
                prompt = f"Du är {worker.upper()}. Uppgift: {task}"

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

    log_to_sprint(cwd, f"⚡ PARALLELLT ARBETE KLART ({len(assignments)} workers)")
    return make_response(f"⚡ PARALLELLT ARBETE KLART\n\n" + "\n\n---\n\n".join(results))


def assign_reviewer(arguments: dict, cwd: str) -> dict:
    """Be Reviewer granska kod."""
    files = arguments.get("files_to_review", [])
    focus = arguments.get("focus", "allmän kvalitet")
    ai = arguments.get("ai")
    cli = get_worker_cli("reviewer", ai)

    files_str = ", ".join(files)
    prompt = load_prompt("reviewer", files=files_str, focus=focus, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="reviewer")

    log_to_sprint(cwd, f"🔍 Reviewer: {files_str[:50]}...")
    return make_response(f"🔍 Reviewer svarar:\n\n{result}")


def assign_tester(arguments: dict, cwd: str) -> dict:
    """Ge Tester ett uppdrag."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("tester", ai)

    prompt = load_prompt("tester", task=task, context=context, project_dir=cwd)
    result = run_cli(cli, prompt, cwd, worker="tester")

    log_to_sprint(cwd, f"🧪 Tester: {task[:50]}...")
    return make_response(f"🧪 Tester svarar:\n\n{result}")


def assign_devops(arguments: dict, cwd: str) -> dict:
    """Ge DevOps ett uppdrag."""
    task = arguments.get("task", "")
    context = arguments.get("context", "")
    ai = arguments.get("ai")
    cli = get_worker_cli("devops", ai)

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
    "assign_devops": assign_devops,
}
