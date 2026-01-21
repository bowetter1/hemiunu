"""
Boss tools - log_decision, get_decisions, summarize_progress, thinking
För att dokumentera beslut och spåra progress.
"""
import json
from pathlib import Path
from datetime import datetime

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "thinking",
        "description": "Logga vad du tänker/planerar just nu. Använd ofta för att ge synlighet!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "thought": {"type": "string", "description": "Vad tänker/planerar du?"}
            },
            "required": ["thought"]
        }
    },
    {
        "name": "log_decision",
        "description": "Dokumentera ett viktigt beslut för framtida referens.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "decision": {"type": "string", "description": "Vad beslutades?"},
                "reason": {"type": "string", "description": "Varför?"}
            },
            "required": ["decision", "reason"]
        }
    },
    {
        "name": "get_decisions",
        "description": "Hämta loggade beslut för projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "description": "Max antal beslut att visa"}
            },
            "required": []
        }
    },
    {
        "name": "summarize_progress",
        "description": "Sammanfatta projektets progress.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
]


def get_decisions_file(cwd: str) -> Path:
    """Hämta path till decisions-fil."""
    return Path(cwd) / ".apex_decisions.json"


def load_decisions(cwd: str) -> list:
    """Ladda beslut från fil."""
    decisions_file = get_decisions_file(cwd)
    if decisions_file.exists():
        try:
            return json.load(open(decisions_file))
        except:
            return []
    return []


def save_decisions(cwd: str, decisions: list):
    """Spara beslut till fil."""
    with open(get_decisions_file(cwd), "w") as f:
        json.dump(decisions, f, indent=2, ensure_ascii=False)


def log_decision(arguments: dict, cwd: str) -> dict:
    """Logga ett beslut."""
    decision = arguments.get("decision", "")
    reason = arguments.get("reason", "")
    timestamp = datetime.now().isoformat()

    decisions = load_decisions(cwd)
    decisions.append({"timestamp": timestamp, "decision": decision, "reason": reason})
    save_decisions(cwd, decisions)

    log_to_sprint(cwd, f"📝 BESLUT: {decision[:50]}...")
    return make_response(f"📝 Beslut loggat: {decision}\nAnledning: {reason}")


def get_decisions(arguments: dict, cwd: str) -> dict:
    """Hämta loggade beslut."""
    limit = arguments.get("limit", 10)
    decisions = load_decisions(cwd)

    if not decisions:
        return make_response("Inga beslut loggade ännu.")

    recent = decisions[-limit:][::-1]
    lines = [f"📝 Beslut ({len(recent)} av {len(decisions)}):\n"]
    for d in recent:
        lines.append(f"• [{d['timestamp'][:10]}] {d['decision']}")

    return make_response("\n".join(lines))


def summarize_progress(arguments: dict, cwd: str) -> dict:
    """Sammanfatta progress."""
    from .files import list_files

    files_result = list_files({}, cwd)
    decisions = load_decisions(cwd)

    summary = [
        f"📊 Progress:",
        f"• Filer: {files_result['content'][0]['text'][:300]}",
        f"• Beslut: {len(decisions)} st"
    ]

    if decisions:
        summary.append("• Senaste beslut:")
        for d in decisions[-3:]:
            summary.append(f"  - {d['decision'][:50]}")

    return make_response("\n".join(summary))


def thinking(arguments: dict, cwd: str) -> dict:
    """Logga en tanke/plan till sprint.log."""
    thought = arguments.get("thought", "")
    log_to_sprint(cwd, f"💭 CHEF: {thought}")
    return make_response(f"💭 {thought}")


HANDLERS = {
    "thinking": thinking,
    "log_decision": log_decision,
    "get_decisions": get_decisions,
    "summarize_progress": summarize_progress,
}
