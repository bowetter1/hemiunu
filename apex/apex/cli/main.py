#!/usr/bin/env python3
"""
apex CLI - AI organisation (lokal version)

Opus (claude) är chefen med MCP-tools för att anropa andra agents.
"""
import sys
import subprocess
import os
from pathlib import Path

# Lägg till apex-mappen i path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.config import get_chef_prompt


def main():
    if len(sys.argv) < 2:
        print("apex 'vad du vill bygga'")
        print("\nOpus (claude) är chefen med MCP-tools.")
        print("Tillgängliga workers: AD, Architect, Backend, Frontend, Tester, Reviewer, DevOps")
        sys.exit(1)

    task = " ".join(sys.argv[1:])

    # Projektmapp
    name = "".join(c if c.isalnum() else "-" for c in task.lower())[:30].strip("-")
    project = Path.cwd() / name
    project.mkdir(exist_ok=True)

    print(f"📂 {project}")
    print(f"🎯 {task}")
    print(f"📋 Logg: {project}/sprint.log")
    print()

    # MCP config path
    mcp_config = Path(__file__).parent.parent / "mcp-agents.json"

    # Kör Opus (claude) med MCP tools
    cmd = [
        "claude",
        "--mcp-config", str(mcp_config),
        "--dangerously-skip-permissions",
        "-p", get_chef_prompt(task)
    ]

    print("→ OPUS startar...")
    print("=" * 50)

    env = os.environ.copy()
    env["PROJECT_DIR"] = str(project)

    # Skapa loggfil (loggar skrivs av MCP-servern)
    log_file = project / "sprint.log"
    log_file.touch()

    # Kör i projektmappen
    subprocess.run(cmd, cwd=str(project), timeout=3600, env=env)  # 60 min

    # Lista skapade filer
    print()
    print("=" * 50)
    print(f"📂 Projekt: {project}")
    files = [f for f in project.rglob("*") if f.is_file() and not f.name.startswith(".")]
    if files:
        print("📁 Filer:")
        for f in sorted(files)[:20]:
            size = f.stat().st_size
            print(f"   {f.relative_to(project)} ({size} bytes)")
    else:
        print("   (inga filer skapade)")

    print("\n✅ Klar!")


if __name__ == "__main__":
    main()
