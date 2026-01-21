"""
Communication tools - talk_to, checkin_worker, reassign_with_feedback, new_session

These tools use worker-sessions to maintain memory.
"""
from core.config import get_worker_cli, ROLE_NAMES
from .base import run_cli, make_response, log_to_sprint, clear_sessions


WORKER_ENUM = ["ad", "architect", "backend", "frontend", "tester", "reviewer", "security", "devops"]

TOOLS = [
    {
        "name": "talk_to",
        "description": "Talk freely with a worker. Has MEMORY - continues previous session!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "message": {"type": "string"}
            },
            "required": ["worker", "message"]
        }
    },
    {
        "name": "checkin_worker",
        "description": "Check-in with a specific worker. Has MEMORY!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "question": {"type": "string", "description": "Question"}
            },
            "required": ["worker", "question"]
        }
    },
    {
        "name": "reassign_with_feedback",
        "description": "Send back task with feedback. Has MEMORY - worker remembers what they did!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "task": {"type": "string"},
                "feedback": {"type": "string"}
            },
            "required": ["worker", "task", "feedback"]
        }
    },
    {
        "name": "new_session",
        "description": "Start new session with a worker (clears memory for that worker).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM}
            },
            "required": ["worker"]
        }
    },
    {
        "name": "clear_all_sessions",
        "description": "Clear all worker-sessions (new sprint).",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
]


def talk_to(arguments: dict, cwd: str) -> dict:
    """Talk freely with a worker (with memory via session-tracking)."""
    worker = arguments.get("worker", "backend")
    message = arguments.get("message", "")
    cli = get_worker_cli(worker)  # Use config.py default
    role_name = ROLE_NAMES.get(worker, worker)

    log_to_sprint(cwd, f"💬 {role_name}: {message[:50]}...")
    result = run_cli(cli, message, cwd, worker=worker)
    return make_response(f"💬 {role_name}: {result}")


def checkin_worker(arguments: dict, cwd: str) -> dict:
    """Check-in with a worker (with memory)."""
    worker = arguments.get("worker", "")
    question = arguments.get("question", "How's it going?")
    cli = get_worker_cli(worker)  # Use config.py default
    role_name = ROLE_NAMES.get(worker, worker)

    result = run_cli(cli, question, cwd, worker=worker)
    return make_response(f"💬 {role_name}: {result}")


def reassign_with_feedback(arguments: dict, cwd: str) -> dict:
    """Send back task with feedback (with memory)."""
    worker = arguments.get("worker", "backend")
    task = arguments.get("task", "")
    feedback = arguments.get("feedback", "")
    cli = get_worker_cli(worker)  # Use config.py default
    role_name = ROLE_NAMES.get(worker, worker)

    prompt = f"Task: {task}\n\nFeedback: {feedback}\n\nMake the adjustments!"
    log_to_sprint(cwd, f"🔄 REASSIGN {role_name}")
    result = run_cli(cli, prompt, cwd, worker=worker)
    return make_response(f"🔄 {role_name}: {result}")


def new_session(arguments: dict, cwd: str) -> dict:
    """Start new session for a worker (clear memory)."""
    from .base import set_session
    worker = arguments.get("worker", "backend")
    cli = get_worker_cli(worker)  # Use config.py default
    role_name = ROLE_NAMES.get(worker, worker)

    # Clear session for this worker
    set_session(worker, None)

    log_to_sprint(cwd, f"🆕 NEW SESSION: {role_name}")
    result = run_cli(cli, f"You are {role_name}. New session - ready for assignments!", cwd, worker=worker)
    return make_response(f"🆕 New session with {role_name}: {result[:200]}")


def clear_all_sessions(arguments: dict, cwd: str) -> dict:
    """Clear all worker-sessions."""
    clear_sessions()
    log_to_sprint(cwd, "🧹 All worker-sessions cleared")
    return make_response("🧹 All worker-sessions cleared - ready for new sprint!")


HANDLERS = {
    "talk_to": talk_to,
    "checkin_worker": checkin_worker,
    "reassign_with_feedback": reassign_with_feedback,
    "new_session": new_session,
    "clear_all_sessions": clear_all_sessions,
}
