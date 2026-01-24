"""Decision tracking tools - log_decision, get_decisions, summarize_progress"""
import json
from datetime import datetime
from pathlib import Path

from .files import IGNORE_DIRS


def _get_decisions_file(base_path: Path) -> Path:
    """Get path to decisions file."""
    return base_path / ".apex_decisions.json"


def _load_decisions(base_path: Path) -> list:
    """Load decisions from file."""
    decisions_file = _get_decisions_file(base_path)
    if decisions_file.exists():
        try:
            with open(decisions_file) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return []
    return []


def _save_decisions(base_path: Path, decisions: list):
    """Save decisions to file."""
    with open(_get_decisions_file(base_path), "w") as f:
        json.dump(decisions, f, indent=2, ensure_ascii=False)


def log_decision(base_path: Path, args: dict) -> str:
    """Log a decision."""
    decision = args.get("decision", "")
    reason = args.get("reason", "")
    timestamp = datetime.now().isoformat()

    decisions = _load_decisions(base_path)
    decisions.append({"timestamp": timestamp, "decision": decision, "reason": reason})
    _save_decisions(base_path, decisions)

    return f"📝 Decision logged: {decision}\nReason: {reason}"


def get_decisions(base_path: Path, args: dict) -> str:
    """Get logged decisions."""
    limit = args.get("limit", 10)
    decisions = _load_decisions(base_path)

    if not decisions:
        return "No decisions logged yet."

    recent = decisions[-limit:][::-1]
    lines = [f"📝 Decisions ({len(recent)} of {len(decisions)}):\n"]
    for d in recent:
        lines.append(f"• [{d['timestamp'][:10]}] {d['decision']}")

    return "\n".join(lines)


def summarize_progress(base_path: Path, args: dict) -> str:
    """Summarize progress."""
    # Count files
    files = [f for f in base_path.rglob("*") if f.is_file()
             and not any(x in f.parts for x in IGNORE_DIRS)
             and not f.name.startswith(".")]

    decisions = _load_decisions(base_path)

    summary = [
        f"📊 Progress Summary:",
        f"• Files: {len(files)}",
        f"• Decisions: {len(decisions)}"
    ]

    # Recent decisions
    if decisions:
        summary.append("• Recent decisions:")
        for d in decisions[-3:]:
            summary.append(f"  - {d['decision'][:50]}")

    # Key files
    key_files = ["main.py", "index.html", "app.js", "style.css", "requirements.txt"]
    existing = [f for f in key_files if (base_path / f).exists()]
    if existing:
        summary.append(f"• Key files: {', '.join(existing)}")

    return "\n".join(summary)
