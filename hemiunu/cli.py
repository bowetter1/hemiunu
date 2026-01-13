#!/usr/bin/env python3
"""
Hemiunu CLI - Starta och hantera agenter.
"""
import sys
from substrate.db import (
    set_master,
    get_master,
    create_task,
    get_all_tasks,
    init_db
)
from agent_loop import run_tick, show_status


def cmd_init(vision: str):
    """Initiera ett nytt projekt."""
    init_db()
    set_master(vision)
    print(f"Projekt initierat med vision: {vision}")


def cmd_add(description: str, cli_test: str = None):
    """Lägg till en uppgift."""
    task_id = create_task(description, cli_test)
    print(f"Skapade uppgift: {task_id}")
    print(f"  Beskrivning: {description}")
    if cli_test:
        print(f"  CLI-test: {cli_test}")


def cmd_tick():
    """Kör nästa uppgift."""
    run_tick()


def cmd_run():
    """Kör alla uppgifter."""
    while run_tick():
        pass
    show_status()


def cmd_status():
    """Visa status."""
    vision = get_master()
    if vision:
        print(f"\nProjekt: {vision}\n")
    show_status()


def main():
    if len(sys.argv) < 2:
        print("""
Hemiunu - AI Agent System
========================

Kommandon:
  init <vision>                    - Starta nytt projekt
  add <beskrivning> [cli_test]     - Lägg till uppgift
  tick                             - Kör nästa uppgift
  run                              - Kör alla uppgifter
  status                           - Visa status

Exempel:
  python cli.py init "E-handelsplattform"
  python cli.py add "Implementera is_prime(n)" "python3 -c 'from src.prime import is_prime; print(is_prime(7))'"
  python cli.py tick
""")
        return

    cmd = sys.argv[1]

    if cmd == "init":
        if len(sys.argv) < 3:
            print("Användning: python cli.py init <vision>")
            return
        cmd_init(" ".join(sys.argv[2:]))

    elif cmd == "add":
        if len(sys.argv) < 3:
            print("Användning: python cli.py add <beskrivning> [cli_test]")
            return
        description = sys.argv[2]
        cli_test = sys.argv[3] if len(sys.argv) > 3 else None
        cmd_add(description, cli_test)

    elif cmd == "tick":
        cmd_tick()

    elif cmd == "run":
        cmd_run()

    elif cmd == "status":
        cmd_status()

    else:
        print(f"Okänt kommando: {cmd}")


if __name__ == "__main__":
    main()
