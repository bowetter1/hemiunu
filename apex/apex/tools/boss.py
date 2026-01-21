"""
Boss tools - log_decision, get_decisions, summarize_progress, thinking
For documenting decisions and tracking progress.
"""
import json
from pathlib import Path
from datetime import datetime

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "thinking",
        "description": "Log what you're thinking/planning right now. Use often to give visibility!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "thought": {"type": "string", "description": "What are you thinking/planning?"}
            },
            "required": ["thought"]
        }
    },
    {
        "name": "log_decision",
        "description": "Document an important decision for future reference.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "decision": {"type": "string", "description": "What was decided?"},
                "reason": {"type": "string", "description": "Why?"}
            },
            "required": ["decision", "reason"]
        }
    },
    {
        "name": "get_decisions",
        "description": "Get logged decisions for the project.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "description": "Max number of decisions to show"}
            },
            "required": []
        }
    },
    {
        "name": "summarize_progress",
        "description": "Summarize the project's progress.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
]


def get_decisions_file(cwd: str) -> Path:
    """Get path to decisions file."""
    return Path(cwd) / ".apex_decisions.json"


def load_decisions(cwd: str) -> list:
    """Load decisions from file."""
    decisions_file = get_decisions_file(cwd)
    if decisions_file.exists():
        try:
            return json.load(open(decisions_file))
        except:
            return []
    return []


def save_decisions(cwd: str, decisions: list):
    """Save decisions to file."""
    with open(get_decisions_file(cwd), "w") as f:
        json.dump(decisions, f, indent=2, ensure_ascii=False)


def log_decision(arguments: dict, cwd: str) -> dict:
    """Log a decision."""
    decision = arguments.get("decision", "")
    reason = arguments.get("reason", "")
    timestamp = datetime.now().isoformat()

    decisions = load_decisions(cwd)
    decisions.append({"timestamp": timestamp, "decision": decision, "reason": reason})
    save_decisions(cwd, decisions)

    log_to_sprint(cwd, f"📝 DECISION: {decision[:50]}...")
    return make_response(f"📝 Decision logged: {decision}\nReason: {reason}")


def get_decisions(arguments: dict, cwd: str) -> dict:
    """Get logged decisions."""
    limit = arguments.get("limit", 10)
    decisions = load_decisions(cwd)

    if not decisions:
        return make_response("No decisions logged yet.")

    recent = decisions[-limit:][::-1]
    lines = [f"📝 Decisions ({len(recent)} of {len(decisions)}):\n"]
    for d in recent:
        lines.append(f"• [{d['timestamp'][:10]}] {d['decision']}")

    return make_response("\n".join(lines))


def summarize_progress(arguments: dict, cwd: str) -> dict:
    """Summarize progress."""
    from .files import list_files

    files_result = list_files({}, cwd)
    decisions = load_decisions(cwd)

    summary = [
        f"📊 Progress:",
        f"• Files: {files_result['content'][0]['text'][:300]}",
        f"• Decisions: {len(decisions)}"
    ]

    if decisions:
        summary.append("• Recent decisions:")
        for d in decisions[-3:]:
            summary.append(f"  - {d['decision'][:50]}")

    return make_response("\n".join(summary))


def thinking(arguments: dict, cwd: str) -> dict:
    """Log a thought/plan to sprint.log."""
    thought = arguments.get("thought", "")
    log_to_sprint(cwd, f"💭 CHEF: {thought}")
    return make_response(f"💭 {thought}")


HANDLERS = {
    "thinking": thinking,
    "log_decision": log_decision,
    "get_decisions": get_decisions,
    "summarize_progress": summarize_progress,
}
