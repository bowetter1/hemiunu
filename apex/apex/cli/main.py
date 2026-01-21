#!/usr/bin/env python3
"""
apex CLI - AI organization (local version)

Opus (claude) is the boss with MCP-tools to call other agents.
"""
import sys
import subprocess
import os
from pathlib import Path

# Add apex folder to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from core.config import get_chef_prompt


def main():
    if len(sys.argv) < 2:
        print("apex 'what you want to build'")
        print("\nOpus (claude) is the boss with MCP-tools.")
        print("Available workers: AD, Architect, Backend, Frontend, Tester, Reviewer, Security, DevOps")
        sys.exit(1)

    task = " ".join(sys.argv[1:])

    # Project folder
    name = "".join(c if c.isalnum() else "-" for c in task.lower())[:30].strip("-")
    project = Path.cwd() / name
    project.mkdir(exist_ok=True)

    print(f"📂 {project}")
    print(f"🎯 {task}")
    print(f"📋 Log: {project}/sprint.log")
    print()

    # MCP config path
    mcp_config = Path(__file__).parent.parent / "mcp-agents.json"

    # Run Opus (claude) with MCP tools
    cmd = [
        "claude",
        "--mcp-config", str(mcp_config),
        "--dangerously-skip-permissions",
        "-p", get_chef_prompt(task)
    ]

    print("→ OPUS starting...")
    print("=" * 50)

    env = os.environ.copy()
    env["PROJECT_DIR"] = str(project)

    # Create log file (logs written by MCP server)
    log_file = project / "sprint.log"
    log_file.touch()

    # Run in project folder
    subprocess.run(cmd, cwd=str(project), timeout=3600, env=env)  # 60 min

    # List created files
    print()
    print("=" * 50)
    print(f"📂 Project: {project}")
    files = [f for f in project.rglob("*") if f.is_file() and not f.name.startswith(".")]
    if files:
        print("📁 Files:")
        for f in sorted(files)[:20]:
            size = f.stat().st_size
            print(f"   {f.relative_to(project)} ({size} bytes)")
    else:
        print("   (no files created)")

    print("\n✅ Done!")


if __name__ == "__main__":
    main()
