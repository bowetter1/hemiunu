#!/usr/bin/env python3
"""
Hemiunu CLI - Huvudentrypoint för systemet.

Kommandon:
  init <vision>     - Starta nytt projekt
  plan <uppdrag>    - Bryt ner uppdrag till tasks (via Vesir)
  add <desc> [test] - Lägg till enskild uppgift
  tick              - Kör nästa uppgift
  run               - Kör alla uppgifter
  deploy            - Kör deploy-cykel
  status            - Visa status
"""
import sys
from pathlib import Path

# Lägg till project root i path för imports
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from infrastructure.db import TaskRepository, init_db, set_master, get_master
from application.orchestrator import Orchestrator, show_status
from application.deployer import Deployer, show_deploy_history
from domain.agents import VesirAgent


def cmd_init(vision: str):
    """Initiera ett nytt projekt."""
    init_db()
    set_master(vision)
    print(f"Projekt initierat med vision: {vision}")


def cmd_add(description: str, cli_test: str = None):
    """Lägg till en uppgift."""
    task_id = TaskRepository.create(description, cli_test)
    print(f"Skapade uppgift: {task_id}")
    print(f"  Beskrivning: {description}")
    if cli_test:
        print(f"  CLI-test: {cli_test}")


def cmd_tick():
    """Kör nästa uppgift."""
    orchestrator = Orchestrator()
    orchestrator.run_next()


def cmd_run():
    """Kör alla uppgifter."""
    orchestrator = Orchestrator()
    orchestrator.run_all()


def cmd_deploy(dry_run: bool = False):
    """Kör deploy-cykel."""
    deployer = Deployer()
    deployer.run(dry_run=dry_run)


def cmd_status():
    """Visa status."""
    vision = get_master()
    if vision:
        print(f"\nProjekt: {vision}\n")
    show_status()


def cmd_plan(request: str):
    """Bryt ner ett stort uppdrag till atomära tasks via Vesir."""
    print(f"\n{'='*60}")
    print("VESIR - Strategisk nedbrytning")
    print(f"{'='*60}")
    print(f"\nUppdrag: {request}\n")

    vision = get_master() or "Inget projekt definierat"
    vesir = VesirAgent(request, context={"vision": vision})
    result = vesir.run()

    if result["status"] == "completed":
        print(f"\n{'='*60}")
        print("PLAN KLAR")
        print(f"{'='*60}")
        print(f"\nSammanfattning: {result['result'].get('summary', 'OK')}")
        print(f"Antal tasks: {result['result'].get('total_tasks', 0)}")
        print("\nSkapade tasks:")
        for task in result['result'].get('tasks', []):
            print(f"  [{task['id']}] {task['description'][:50]}")
            print(f"           CLI: {task['cli_test']}")
            print(f"           Testfall: {task.get('estimated_test_cases', '?')}")
        print(f"\nKör 'hemiunu run' för att starta implementation.")
    elif result["status"] == "rejected":
        print(f"\nVesir avvisade uppdraget: {result.get('error')}")
    else:
        print(f"\nFel: {result.get('error', 'Okänt fel')}")


def cmd_history():
    """Visa deploy-historik."""
    show_deploy_history()


def main():
    if len(sys.argv) < 2:
        print("""
Hemiunu - AI Agent System
========================

Kommandon:
  init <vision>                    - Starta nytt projekt
  plan <stort uppdrag>             - Bryt ner uppdrag till tasks (via Vesir)
  add <beskrivning> [cli_test]     - Lägg till enskild uppgift
  tick                             - Kör nästa uppgift
  run                              - Kör alla uppgifter
  deploy [--dry-run]               - Kör deploy-cykel
  status                           - Visa status
  history                          - Visa deploy-historik

Exempel:
  python -m interface.cli init "E-handelsplattform"
  python -m interface.cli plan "Bygg en kalkylator med grundläggande operationer"
  python -m interface.cli add "Implementera is_prime(n)" "python3 -c 'from src.prime import is_prime; print(is_prime(7))'"
  python -m interface.cli run
""")
        return

    cmd = sys.argv[1]

    if cmd == "init":
        if len(sys.argv) < 3:
            print("Användning: hemiunu init <vision>")
            return
        cmd_init(" ".join(sys.argv[2:]))

    elif cmd == "add":
        if len(sys.argv) < 3:
            print("Användning: hemiunu add <beskrivning> [cli_test]")
            return
        description = sys.argv[2]
        cli_test = sys.argv[3] if len(sys.argv) > 3 else None
        cmd_add(description, cli_test)

    elif cmd == "tick":
        cmd_tick()

    elif cmd == "run":
        cmd_run()

    elif cmd == "deploy":
        dry_run = "--dry-run" in sys.argv
        cmd_deploy(dry_run=dry_run)

    elif cmd == "status":
        cmd_status()

    elif cmd == "plan":
        if len(sys.argv) < 3:
            print("Användning: hemiunu plan <stort uppdrag>")
            return
        cmd_plan(" ".join(sys.argv[2:]))

    elif cmd == "history":
        cmd_history()

    else:
        print(f"Okänt kommando: {cmd}")


if __name__ == "__main__":
    main()
