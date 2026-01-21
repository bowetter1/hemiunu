"""
Meeting tools - team_kickoff, team_demo, team_retrospective
"""
from pathlib import Path

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "team_kickoff",
        "description": "Kickoff-möte: PRESENTERA planen för teamet. Kör EFTER assign_architect har skapat planen.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "vision": {"type": "string", "description": "Vad bygger vi? Varför?"},
                "goals": {"type": "array", "items": {"type": "string"}, "description": "Sprint-mål"},
                "plan_summary": {"type": "string", "description": "Sammanfattning av arkitektens plan"}
            },
            "required": ["vision", "goals"]
        }
    },
    {
        "name": "team_demo",
        "description": "Demo-möte: Visa vad som byggts. Kör EFTER utveckling är klar, FÖRE retrospective.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "what_was_built": {"type": "string", "description": "Kort beskrivning av vad som byggts"},
                "files_created": {"type": "array", "items": {"type": "string"}, "description": "Lista över skapade filer"}
            },
            "required": ["what_was_built"]
        }
    },
    {
        "name": "team_retrospective",
        "description": "Retrospective: Reflektera över sprinten. Vad gick bra? Vad kan förbättras?",
        "inputSchema": {
            "type": "object",
            "properties": {
                "went_well": {"type": "array", "items": {"type": "string"}, "description": "Vad gick bra?"},
                "could_improve": {"type": "array", "items": {"type": "string"}, "description": "Vad kan förbättras?"},
                "learnings": {"type": "string", "description": "Vad lärde vi oss?"},
                "live_url": {"type": "string", "description": "URL till live-appen (om deployad)"}
            },
            "required": ["went_well", "could_improve"]
        }
    },
]


def team_kickoff(arguments: dict, cwd: str) -> dict:
    """Kickoff-möte."""
    vision = arguments.get("vision", "")
    goals = arguments.get("goals", [])

    # Läs PLAN.md om den finns
    plan_file = Path(cwd) / "PLAN.md"
    plan = plan_file.read_text()[:500] if plan_file.exists() else ""

    goals_str = "\n".join(f"  {i+1}. {g}" for i, g in enumerate(goals))
    log_to_sprint(cwd, f"📋 KICKOFF: {vision}")

    return make_response(f"""🚀 KICKOFF

Vision: {vision}

Mål:
{goals_str}

{f'Plan: {plan}...' if plan else ''}

Teamet är informerat och redo!""")


def team_demo(arguments: dict, cwd: str) -> dict:
    """Demo-möte."""
    what_was_built = arguments.get("what_was_built", "")

    # Lista filer
    files = [str(f.relative_to(cwd)) for f in Path(cwd).rglob("*")
             if f.is_file() and not f.name.startswith(".")
             and "__pycache__" not in str(f) and "node_modules" not in str(f)
             and "venv" not in str(f)][:15]

    log_to_sprint(cwd, f"🎯 DEMO: {what_was_built}")

    return make_response(f"""🎯 DEMO

Byggt: {what_was_built}

Filer ({len(files)} st):
{chr(10).join(f'  • {f}' for f in files)}""")


def team_retrospective(arguments: dict, cwd: str) -> dict:
    """Retrospective-möte."""
    went_well = arguments.get("went_well", [])
    could_improve = arguments.get("could_improve", [])
    learnings = arguments.get("learnings", "")
    live_url = arguments.get("live_url", "")

    well_str = "\n".join(f"  ✅ {item}" for item in went_well)
    improve_str = "\n".join(f"  🔧 {item}" for item in could_improve)

    log_to_sprint(cwd, f"🔄 RETRO: {len(went_well)} bra, {len(could_improve)} förbättringar")

    result = f"""🔄 RETROSPECTIVE

Vad gick bra:
{well_str}

Vad kan förbättras:
{improve_str}
"""
    if learnings:
        result += f"\nLärdom: {learnings}\n"
    if live_url:
        result += f"\n🌐 Live: {live_url}\n"

    # Spara till fil för framtida sprints
    retro_file = Path(cwd) / "RETROSPECTIVE.md"
    retro_file.write_text(result)

    return make_response(result + "\n✅ Sparad till RETROSPECTIVE.md")


HANDLERS = {
    "team_kickoff": team_kickoff,
    "team_demo": team_demo,
    "team_retrospective": team_retrospective,
}
