"""
Communication tools - talk_to, checkin_worker, reassign_with_feedback, new_session

Dessa verktyg använder worker-sessions för att behålla minne.
"""
from core.config import get_worker_cli, ROLE_NAMES
from .base import run_cli, make_response, log_to_sprint, clear_sessions


WORKER_ENUM = ["ad", "architect", "backend", "frontend", "tester", "reviewer", "devops"]

TOOLS = [
    {
        "name": "talk_to",
        "description": "Prata fritt med en worker. Har MINNE - fortsätter tidigare session!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "message": {"type": "string"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"]}
            },
            "required": ["worker", "message"]
        }
    },
    {
        "name": "checkin_worker",
        "description": "Check-in med en specifik worker. Har MINNE!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "question": {"type": "string", "description": "Fråga"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"]}
            },
            "required": ["worker", "question"]
        }
    },
    {
        "name": "reassign_with_feedback",
        "description": "Skicka tillbaka uppgift med feedback. Har MINNE - workern kommer ihåg vad den gjorde!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "task": {"type": "string"},
                "feedback": {"type": "string"},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"]}
            },
            "required": ["worker", "task", "feedback"]
        }
    },
    {
        "name": "new_session",
        "description": "Starta ny session med en worker (rensar minnet för den workern).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "ai": {"type": "string", "enum": ["claude", "sonnet", "gemini"]}
            },
            "required": ["worker"]
        }
    },
    {
        "name": "clear_all_sessions",
        "description": "Rensa alla worker-sessions (ny sprint).",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
]


def talk_to(arguments: dict, cwd: str) -> dict:
    """Prata fritt med en worker (med minne via session-tracking)."""
    worker = arguments.get("worker", "backend")
    message = arguments.get("message", "")
    ai = arguments.get("ai")
    cli = get_worker_cli(worker, ai)
    role_name = ROLE_NAMES.get(worker, worker)

    log_to_sprint(cwd, f"💬 {role_name}: {message[:50]}...")
    result = run_cli(cli, message, cwd, worker=worker)
    return make_response(f"💬 {role_name}: {result}")


def checkin_worker(arguments: dict, cwd: str) -> dict:
    """Check-in med en worker (med minne)."""
    worker = arguments.get("worker", "")
    question = arguments.get("question", "Hur går det?")
    ai = arguments.get("ai")
    cli = get_worker_cli(worker, ai)
    role_name = ROLE_NAMES.get(worker, worker)

    result = run_cli(cli, question, cwd, worker=worker)
    return make_response(f"💬 {role_name}: {result}")


def reassign_with_feedback(arguments: dict, cwd: str) -> dict:
    """Skicka tillbaka uppgift med feedback (med minne)."""
    worker = arguments.get("worker", "backend")
    task = arguments.get("task", "")
    feedback = arguments.get("feedback", "")
    ai = arguments.get("ai")
    cli = get_worker_cli(worker, ai)
    role_name = ROLE_NAMES.get(worker, worker)

    prompt = f"Uppgift: {task}\n\nFeedback: {feedback}\n\nGör justeringarna!"
    log_to_sprint(cwd, f"🔄 REASSIGN {role_name}")
    result = run_cli(cli, prompt, cwd, worker=worker)
    return make_response(f"🔄 {role_name}: {result}")


def new_session(arguments: dict, cwd: str) -> dict:
    """Starta ny session för en worker (rensa minne)."""
    from .base import set_session
    worker = arguments.get("worker", "backend")
    ai = arguments.get("ai")
    cli = get_worker_cli(worker, ai)
    role_name = ROLE_NAMES.get(worker, worker)

    # Rensa session för denna worker
    set_session(worker, None)

    log_to_sprint(cwd, f"🆕 NY SESSION: {role_name}")
    result = run_cli(cli, f"Du är {role_name}. Ny session - redo för uppdrag!", cwd, worker=worker)
    return make_response(f"🆕 Ny session med {role_name}: {result[:200]}")


def clear_all_sessions(arguments: dict, cwd: str) -> dict:
    """Rensa alla worker-sessions."""
    clear_sessions()
    log_to_sprint(cwd, "🧹 Alla worker-sessions rensade")
    return make_response("🧹 Alla worker-sessions rensade - redo för ny sprint!")


HANDLERS = {
    "talk_to": talk_to,
    "checkin_worker": checkin_worker,
    "reassign_with_feedback": reassign_with_feedback,
    "new_session": new_session,
    "clear_all_sessions": clear_all_sessions,
}
