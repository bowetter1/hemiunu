"""
Hemiunu Orchestrator - Driver Twin-Spawn flödet.

Flöde:
1. Hämta nästa TODO-uppgift
2. Skapa feature-branch
3. Spawna Worker
4. Worker skriver kod
5. Spawna Tester med Worker's resultat
6. Tester skriver oberoende tester
7. Tester kör alla tester
8. Om godkänt: commit + markera GREEN
9. Om avvisat: Worker får feedback, försök igen
"""
import json
from substrate.db import (
    get_master,
    get_next_todo,
    get_task,
    update_task,
    create_task,
    save_test_result,
    get_all_tasks
)
from agents.worker import WorkerAgent
from agents.tester import TesterAgent
from core.git import (
    create_branch,
    commit_changes,
    checkout_main,
    get_current_branch
)

# Max antal Worker-försök efter Tester-avvisning
MAX_RETRIES = 3


def run_twin_spawn(task: dict, use_git: bool = True) -> dict:
    """
    Kör Twin-Spawn på en uppgift.

    Args:
        task: Uppgiften att köra
        use_git: Om True, skapa branch och committa vid godkännande

    Returns:
        dict med {status, worker_result, tester_result, branch}
    """
    vision = get_master() or "Inget projekt definierat"
    task_id = task["id"]
    branch_name = None

    print(f"\n{'='*60}")
    print(f"TWIN-SPAWN: {task_id}")
    print(f"Uppgift: {task['description']}")
    print(f"{'='*60}\n")

    # === STEG 0: Skapa feature-branch ===
    if use_git:
        print("[ORCHESTRATOR] Skapar feature-branch...")
        branch_result = create_branch(task_id)
        if branch_result["success"]:
            branch_name = branch_result["branch_name"]
            update_task(task_id, branch=branch_name)
            action = "Skapade" if branch_result.get("created") else "Checkade ut"
            print(f"[ORCHESTRATOR] {action} branch: {branch_name}")
        else:
            print(f"[ORCHESTRATOR] Varning: Kunde inte skapa branch: {branch_result.get('error')}")

    for retry in range(MAX_RETRIES):
        print(f"\n--- Försök {retry + 1}/{MAX_RETRIES} ---\n")

        # === STEG 1: Worker skriver kod ===
        print("[ORCHESTRATOR] Startar Worker...")
        update_task(task_id, worker_status="WORKING")

        worker = WorkerAgent(task, context={"vision": vision})
        worker_result = worker.run()

        print(f"[ORCHESTRATOR] Worker klar: {worker_result['status']}")

        # Hantera Worker-resultat
        if worker_result["status"] == "failed":
            update_task(
                task_id,
                status="RED",
                worker_status="FAILED",
                error=worker_result.get("error")
            )
            return {
                "status": "failed",
                "worker_result": worker_result,
                "tester_result": None
            }

        elif worker_result["status"] == "split":
            # Skapa sub-tasks
            for subtask in worker_result.get("result", []):
                sub_id = create_task(
                    description=subtask["description"],
                    cli_test=subtask.get("cli_test"),
                    parent_id=task_id
                )
                print(f"[ORCHESTRATOR] Skapade sub-task: {sub_id}")

            update_task(task_id, status="SPLIT", worker_status="SPLIT")
            return {
                "status": "split",
                "worker_result": worker_result,
                "tester_result": None
            }

        # Worker lyckades - uppdatera status
        update_task(task_id, worker_status="DONE")

        # === STEG 2: Tester validerar ===
        print("\n[ORCHESTRATOR] Startar Tester...")
        update_task(task_id, tester_status="WORKING")

        # Ge Tester information om var koden finns
        code_path = task.get("code_path", "src/")
        tester = TesterAgent(
            task,
            context={
                "vision": vision,
                "code_path": code_path
            }
        )
        tester_result = tester.run()

        print(f"[ORCHESTRATOR] Tester klar: {tester_result['status']}")

        # Spara testresultat
        if tester_result.get("result"):
            save_test_result(
                task_id=task_id,
                passed=(tester_result["status"] == "approved"),
                output=json.dumps(tester_result),
                tester_tests=tester_result["result"].get("test_path")
            )

        # Hantera Tester-resultat
        if tester_result["status"] == "approved":
            update_task(
                task_id,
                status="GREEN",
                tester_status="APPROVED",
                test_path=tester_result["result"].get("test_path")
            )
            print(f"\n[ORCHESTRATOR] GODKÄNT efter {retry + 1} försök")

            # === STEG 3: Commit ändringar ===
            if use_git and branch_name:
                print(f"[ORCHESTRATOR] Committar ändringar på {branch_name}...")
                commit_result = commit_changes(task_id, task["description"])
                if commit_result["success"]:
                    if commit_result["commit_hash"]:
                        print(f"[ORCHESTRATOR] Commit: {commit_result['commit_hash']}")
                    else:
                        print("[ORCHESTRATOR] Inga nya ändringar att committa")
                else:
                    print(f"[ORCHESTRATOR] Varning: Commit misslyckades: {commit_result.get('error')}")

                # Gå tillbaka till main
                checkout_main()
                print(f"[ORCHESTRATOR] Tillbaka på main")

            return {
                "status": "approved",
                "worker_result": worker_result,
                "tester_result": tester_result,
                "branch": branch_name
            }

        elif tester_result["status"] == "rejected":
            update_task(task_id, tester_status="REJECTED")
            print(f"\n[ORCHESTRATOR] Avvisat: {tester_result.get('error')}")

            # Uppdatera task med feedback för nästa försök
            # (Worker kommer få se detta vid nästa körning)
            if retry < MAX_RETRIES - 1:
                print("[ORCHESTRATOR] Försöker igen...")
                continue
            else:
                # Max retries - markera som röd
                update_task(
                    task_id,
                    status="RED",
                    error=f"Avvisad av Tester efter {MAX_RETRIES} försök"
                )
                return {
                    "status": "failed",
                    "worker_result": worker_result,
                    "tester_result": tester_result
                }

        else:
            # Oväntad status
            update_task(
                task_id,
                status="RED",
                tester_status="ERROR",
                error=f"Oväntat Tester-status: {tester_result['status']}"
            )
            return {
                "status": "error",
                "worker_result": worker_result,
                "tester_result": tester_result
            }

    # Borde inte nå hit
    return {"status": "error", "worker_result": None, "tester_result": None}


def run_tick() -> bool:
    """
    Kör en iteration: ta nästa TODO och processa med Twin-Spawn.

    Returns:
        True om det fanns en uppgift att köra, False annars
    """
    task = get_next_todo()

    if not task:
        print("Inga fler uppgifter i kön.")
        return False

    update_task(task["id"], status="WORKING")
    result = run_twin_spawn(task)
    print(f"\nResultat: {result['status']}")
    return True


def show_status():
    """Visa status för alla uppgifter."""
    tasks = get_all_tasks()

    print("\n" + "="*60)
    print(f"UPPGIFTSSTATUS (branch: {get_current_branch()})")
    print("="*60)

    for task in tasks:
        status_icon = {
            "TODO": "[ ]",
            "WORKING": "[~]",
            "GREEN": "[✓]",
            "RED": "[✗]",
            "SPLIT": "[/]",
            "DEPLOYED": "[★]"
        }.get(task["status"], "[?]")

        worker = task.get("worker_status", "-")
        tester = task.get("tester_status", "-")
        branch = task.get("branch", "")

        print(f"{status_icon} {task['id']}: {task['description'][:40]}")
        print(f"    Worker: {worker} | Tester: {tester}")
        if branch:
            print(f"    Branch: {branch}")

        if task.get("error"):
            print(f"    Error: {task['error'][:50]}")

    print("="*60 + "\n")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("""
Hemiunu Orchestrator - Twin-Spawn
=================================

Kommandon:
  tick     - Kör nästa uppgift med Twin-Spawn
  run      - Kör alla uppgifter
  status   - Visa status

Exempel:
  python orchestrator.py tick
  python orchestrator.py status
""")
        sys.exit(0)

    command = sys.argv[1]

    if command == "tick":
        run_tick()
    elif command == "run":
        while run_tick():
            pass
        show_status()
    elif command == "status":
        show_status()
    else:
        print(f"Okänt kommando: {command}")
