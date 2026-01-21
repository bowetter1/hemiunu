"""
Meeting tools - team_kickoff, team_demo, team_retrospective
"""
from pathlib import Path

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "team_kickoff",
        "description": "Kickoff meeting: PRESENT the plan to the team. Run AFTER assign_architect has created the plan.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "vision": {"type": "string", "description": "What are we building? Why?"},
                "goals": {"type": "array", "items": {"type": "string"}, "description": "Sprint goals"},
                "plan_summary": {"type": "string", "description": "Summary of architect's plan"}
            },
            "required": ["vision", "goals"]
        }
    },
    {
        "name": "team_demo",
        "description": "Demo meeting: Show what was built. Run AFTER development is done, BEFORE retrospective.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "what_was_built": {"type": "string", "description": "Short description of what was built"},
                "files_created": {"type": "array", "items": {"type": "string"}, "description": "List of created files"}
            },
            "required": ["what_was_built"]
        }
    },
    {
        "name": "team_retrospective",
        "description": "Retrospective: Reflect on the build. What worked? What was slow? What tools are missing?",
        "inputSchema": {
            "type": "object",
            "properties": {
                "went_well": {"type": "array", "items": {"type": "string"}, "description": "What worked well?"},
                "bottlenecks": {"type": "array", "items": {"type": "string"}, "description": "What was slow or blocked?"},
                "missing_tools": {"type": "array", "items": {"type": "string"}, "description": "Tools/features that would have helped"},
                "worker_feedback": {"type": "object", "description": "Feedback per worker: {worker: 'feedback'}"},
                "suggested_improvements": {"type": "array", "items": {"type": "string"}, "description": "Concrete improvements for next time"},
                "live_url": {"type": "string", "description": "URL to deployed app"}
            },
            "required": ["went_well", "bottlenecks"]
        }
    },
]


def team_kickoff(arguments: dict, cwd: str) -> dict:
    """Kickoff meeting - writes to CONTEXT.md so workers can see it."""
    vision = arguments.get("vision", "")
    goals = arguments.get("goals", [])

    goals_str = "\n".join(f"- {g}" for g in goals)

    # Write to CONTEXT.md so workers actually see vision/goals
    context_file = Path(cwd) / "CONTEXT.md"
    kickoff_section = f"""# PROJECT CONTEXT

## Vision
{vision}

## Sprint Goals
{goals_str}

## NEEDS (blockers)
| From | Need | From who | Status |
|------|------|----------|--------|

"""
    # Write or prepend to CONTEXT.md
    if context_file.exists():
        existing = context_file.read_text()
        # If Vision section already exists, don't update
        if "## Vision" not in existing:
            context_file.write_text(kickoff_section + existing)
    else:
        context_file.write_text(kickoff_section)

    log_to_sprint(cwd, f"📋 KICKOFF: {vision}")

    return make_response(f"""🚀 KICKOFF

Vision: {vision}

Goals:
{goals_str}

✅ Written to CONTEXT.md - all workers will see this!""")


def team_demo(arguments: dict, cwd: str) -> dict:
    """Demo meeting."""
    what_was_built = arguments.get("what_was_built", "")

    # List files
    files = [str(f.relative_to(cwd)) for f in Path(cwd).rglob("*")
             if f.is_file() and not f.name.startswith(".")
             and "__pycache__" not in str(f) and "node_modules" not in str(f)
             and "venv" not in str(f)][:15]

    log_to_sprint(cwd, f"🎯 DEMO: {what_was_built}")

    return make_response(f"""🎯 DEMO

Built: {what_was_built}

Files ({len(files)}):
{chr(10).join(f'  • {f}' for f in files)}""")


def team_retrospective(arguments: dict, cwd: str) -> dict:
    """Retrospective - Chef's feedback on the build process."""
    went_well = arguments.get("went_well", [])
    bottlenecks = arguments.get("bottlenecks", [])
    missing_tools = arguments.get("missing_tools", [])
    worker_feedback = arguments.get("worker_feedback", {})
    suggested_improvements = arguments.get("suggested_improvements", [])
    live_url = arguments.get("live_url", "")

    well_str = "\n".join(f"- {item}" for item in went_well)
    bottleneck_str = "\n".join(f"- {item}" for item in bottlenecks)
    missing_str = "\n".join(f"- {item}" for item in missing_tools) if missing_tools else "None"
    improve_str = "\n".join(f"- {item}" for item in suggested_improvements) if suggested_improvements else "None"

    worker_str = ""
    if worker_feedback:
        worker_str = "\n".join(f"- **{k}**: {v}" for k, v in worker_feedback.items())

    log_to_sprint(cwd, f"🔄 RETRO: {len(went_well)} good, {len(bottlenecks)} bottlenecks")

    result = f"""# Retrospective

## What Worked Well
{well_str}

## Bottlenecks / Slow Points
{bottleneck_str}

## Missing Tools / Features
{missing_str}

## Worker Feedback
{worker_str if worker_str else "No specific feedback"}

## Suggested Improvements
{improve_str}
"""
    if live_url:
        result += f"\n## Deployed\n🌐 {live_url}\n"

    # Save to file
    retro_file = Path(cwd) / "RETROSPECTIVE.md"
    retro_file.write_text(result)

    return make_response(result + "\n✅ Saved to RETROSPECTIVE.md")


HANDLERS = {
    "team_kickoff": team_kickoff,
    "team_demo": team_demo,
    "team_retrospective": team_retrospective,
}
