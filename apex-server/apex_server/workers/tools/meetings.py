"""Meeting tools - kickoff, planning, demo, retrospective, thinking"""
from pathlib import Path


def thinking(base_path: Path, args: dict) -> str:
    """Log a thought."""
    thought = args.get("thought", "")
    return f"💭 {thought}"


def team_kickoff(base_path: Path, args: dict) -> str:
    """Team kickoff meeting."""
    vision = args.get("vision", "")
    goals = args.get("goals", [])
    plan_summary = args.get("plan_summary", "")

    # Read PLAN.md if exists
    plan_file = base_path / "PLAN.md"
    plan = plan_file.read_text()[:500] if plan_file.exists() else plan_summary

    goals_str = "\n".join(f"  {i+1}. {g}" for i, g in enumerate(goals))

    return f"""🚀 KICKOFF

Vision: {vision}

Goals:
{goals_str}

{f'Plan: {plan}...' if plan else ''}

Team is informed and ready!"""


def sprint_planning(base_path: Path, args: dict) -> str:
    """Sprint planning meeting."""
    sprint_name = args.get("sprint_name", "Sprint 1")
    features = args.get("features", [])

    features_str = "\n".join(f"  - {f}" for f in features)

    return f"""📋 SPRINT PLANNING: {sprint_name}

Features:
{features_str}

Let's build this!"""


def team_demo(base_path: Path, args: dict) -> str:
    """Team demo meeting."""
    what_was_built = args.get("what_was_built", "")
    files_created = args.get("files_created", [])

    # List actual files if not provided
    if not files_created:
        files_created = [
            str(f.relative_to(base_path)) for f in base_path.rglob("*")
            if f.is_file() and not f.name.startswith(".")
            and "__pycache__" not in str(f) and "node_modules" not in str(f)
            and "venv" not in str(f)
        ][:15]

    return f"""🎯 DEMO

Built: {what_was_built}

Files ({len(files_created)}):
{chr(10).join(f'  • {f}' for f in files_created)}"""


def team_retrospective(base_path: Path, args: dict) -> str:
    """Team retrospective."""
    went_well = args.get("went_well", [])
    could_improve = args.get("could_improve", [])
    learnings = args.get("learnings", "")
    live_url = args.get("live_url", "")

    well_str = "\n".join(f"  ✅ {item}" for item in went_well)
    improve_str = "\n".join(f"  🔧 {item}" for item in could_improve)

    result = f"""🔄 RETROSPECTIVE

What went well:
{well_str}

What could improve:
{improve_str}
"""
    if learnings:
        result += f"\nLearning: {learnings}\n"
    if live_url:
        result += f"\n🌐 Live: {live_url}\n"

    # Save to file
    retro_file = base_path / "RETROSPECTIVE.md"
    retro_file.write_text(result)

    return result + "\n✅ Saved to RETROSPECTIVE.md"
