#!/usr/bin/env python3
"""
Apex Lite CLI

Boss + Devs modell - smart decomposition, minimal sync.

Användning:
    python cli.py "Bygg ett quiz-spel"
    python cli.py "Bygg en e-commerce site med produkter och varukorg"
"""
import sys
import subprocess
import os
from pathlib import Path


def load_boss_prompt(task: str) -> str:
    """Ladda boss-prompten."""
    prompt_path = Path(__file__).parent / "prompts" / "boss.md"
    template = prompt_path.read_text()
    return template.format(task=task)


def main():
    if len(sys.argv) < 2:
        print("""
╔══════════════════════════════════════════════════════════╗
║                      APEX LITE                           ║
║              Boss + Devs - Smart Decomposition           ║
╚══════════════════════════════════════════════════════════╝

Användning:
    python cli.py "Bygg ett quiz-spel"
    python cli.py "Bygg en todo-app med auth"

Boss (Opus) analyserar och delar upp arbetet.
Devs (Opus) bygger moduler parallellt.
""")
        sys.exit(1)

    task = " ".join(sys.argv[1:])

    # Skapa projektmapp
    name = "".join(c if c.isalnum() else "-" for c in task.lower())[:40].strip("-")
    project = Path.cwd() / name
    project.mkdir(exist_ok=True)

    # Skriv projekt-path så MCP-servern kan hitta den
    (Path(__file__).parent / ".current_project").write_text(str(project))

    # MCP config
    mcp_config = Path(__file__).parent / "mcp-config.json"

    print(f"""
╔══════════════════════════════════════════════════════════╗
║                      APEX LITE                           ║
╚══════════════════════════════════════════════════════════╝

📋 Task: {task}
📂 Project: {project}
📝 Log: {project}/sprint.log
""")

    # Skapa log-fil
    (project / "sprint.log").touch()

    # Kör Boss via Claude med MCP tools
    # Blockera inbyggda verktyg så Claude MÅSTE använda MCP-verktygen
    cmd = [
        "claude",
        "--mcp-config", str(mcp_config),
        "--dangerously-skip-permissions",
        "--disallowedTools", "Write,Edit,MultiEdit,Bash,Read,Glob,Grep,LS",
        "-p", load_boss_prompt(task)
    ]

    env = os.environ.copy()
    env["PROJECT_DIR"] = str(project)

    print("🎯 VD startar research & development...\n")
    print("=" * 60)
    print("📊 Live log: tail -f " + str(project / "sprint.log"))
    print("=" * 60 + "\n")

    # Skriv initial log
    from datetime import datetime
    with open(project / "sprint.log", "a") as f:
        f.write(f"\n{'='*60}\n")
        f.write(f"[{datetime.now().strftime('%H:%M:%S')}] [START] VD STARTAR\n")
        f.write(f"[{datetime.now().strftime('%H:%M:%S')}] [START] Task: {task}\n")
        f.write(f"{'='*60}\n\n")

    # Kör Boss
    process = subprocess.run(cmd, cwd=str(project), env=env, timeout=3600)

    # Sammanfattning
    print("\n" + "=" * 60)
    print(f"\n📂 Projekt: {project}")

    files = [f for f in project.rglob("*") if f.is_file() and not f.name.startswith(".")]
    if files:
        print("📁 Filer:")
        for f in sorted(files)[:20]:
            size = f.stat().st_size
            print(f"   {f.relative_to(project)} ({size} bytes)")

    print("\n✅ Klart!")


if __name__ == "__main__":
    main()
