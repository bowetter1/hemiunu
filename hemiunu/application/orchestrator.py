"""
Orchestrator - Huvudloop som driver AI-agenter.

Flöde:
1. Hämta nästa TODO från DB
2. Spawna Worker-agent
3. Worker skriver kod + testar via CLI
4. Om DONE: Spawna Tester-agent för validering
5. Om båda godkänner: markera GREEN
6. Om någon rejectar: markera RED
"""
from domain.agents import WorkerAgent, TesterAgent
from infrastructure.db import TaskRepository, get_master
from infrastructure.git import create_branch, commit_changes, checkout_main


class Orchestrator:
    """
    Orchestrerar task-exekvering med Twin-Spawn.
    """

    def __init__(self):
        self.vision = get_master() or "Inget projekt definierat"

    def run_task(self, task: dict) -> dict:
        """
        Kör en uppgift med Twin-Spawn (Worker + Tester).

        Returns:
            dict med {status, worker_result, tester_result}
        """
        print(f"\n{'='*60}")
        print(f"STARTAR UPPGIFT: {task['id']}")
        print(f"Beskrivning: {task['description']}")
        print(f"{'='*60}\n")

        # Skapa feature branch
        branch_result = create_branch(task["id"])
        if branch_result["success"]:
            TaskRepository.update(task["id"], branch=branch_result["branch_name"])
            print(f"[ORCH] Branch: {branch_result['branch_name']}")

        # Markera som WORKING
        TaskRepository.update(task["id"], status="WORKING")

        # === WORKER PHASE ===
        print("\n[ORCH] === WORKER PHASE ===")
        worker = WorkerAgent(task, context={"vision": self.vision})
        worker_result = worker.run()

        print(f"[ORCH] Worker status: {worker_result['status']}")

        if worker_result["status"] == "done":
            # Commit ändringar
            commit_result = commit_changes(task["id"], task["description"])
            if commit_result["success"]:
                print(f"[ORCH] Commit: {commit_result.get('commit_hash')}")

            # === TESTER PHASE ===
            print("\n[ORCH] === TESTER PHASE ===")
            tester = TesterAgent(
                task,
                context={
                    "vision": self.vision,
                    "code_path": f"src/",  # Worker's kod
                }
            )
            tester_result = tester.run()

            print(f"[ORCH] Tester status: {tester_result['status']}")

            if tester_result["status"] == "approved":
                # Båda godkände - GREEN
                TaskRepository.update(task["id"], status="GREEN")
                TaskRepository.save_test_result(
                    task["id"],
                    passed=True,
                    output=tester_result["result"].get("summary", "OK"),
                    tester_tests=tester_result["result"].get("test_path")
                )
                return {
                    "status": "GREEN",
                    "worker_result": worker_result,
                    "tester_result": tester_result
                }
            else:
                # Tester rejektade - RED
                TaskRepository.update(
                    task["id"],
                    status="RED",
                    error=tester_result.get("error")
                )
                TaskRepository.save_test_result(
                    task["id"],
                    passed=False,
                    output=tester_result.get("error", "Rejected"),
                    tester_tests=tester_result["result"].get("test_path") if tester_result.get("result") else None
                )
                return {
                    "status": "RED",
                    "worker_result": worker_result,
                    "tester_result": tester_result
                }

        elif worker_result["status"] == "split":
            # Worker delade upp uppgiften
            TaskRepository.update(task["id"], status="SPLIT")
            for subtask in worker_result.get("result", []):
                TaskRepository.create(
                    description=subtask["description"],
                    cli_test=subtask.get("cli_test"),
                    parent_id=task["id"]
                )
            return {
                "status": "SPLIT",
                "worker_result": worker_result,
                "tester_result": None
            }

        else:
            # Worker misslyckades
            TaskRepository.update(
                task["id"],
                status="RED",
                error=worker_result.get("error")
            )
            return {
                "status": "RED",
                "worker_result": worker_result,
                "tester_result": None
            }

    def run_next(self) -> bool:
        """
        Kör nästa TODO-uppgift.

        Returns:
            True om en uppgift kördes, False om kön är tom.
        """
        task = TaskRepository.get_next_todo()

        if not task:
            print("[ORCH] Inga fler uppgifter i kön.")
            return False

        result = self.run_task(task)
        print(f"\n[ORCH] Resultat: {result['status']}")

        # Återgå till main
        checkout_main()

        return True

    def run_all(self):
        """Kör alla TODO-uppgifter."""
        while self.run_next():
            pass
        show_status()


def run_tick() -> bool:
    """Kör en iteration: ta nästa TODO och processa den."""
    orchestrator = Orchestrator()
    return orchestrator.run_next()


def show_status():
    """Visa status för alla uppgifter."""
    tasks = TaskRepository.get_all()

    print("\n" + "="*60)
    print("UPPGIFTSSTATUS")
    print("="*60)

    status_icons = {
        "TODO": "[ ]",
        "WORKING": "[~]",
        "GREEN": "[+]",
        "RED": "[X]",
        "SPLIT": "[/]",
        "DEPLOYED": "[D]"
    }

    for task in tasks:
        icon = status_icons.get(task["status"], "[?]")
        print(f"{icon} {task['id']}: {task['description'][:50]}")
        if task.get("error"):
            print(f"    Error: {task['error'][:60]}")

    print("="*60 + "\n")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Användning:")
        print("  python -m application.orchestrator tick   - Kör nästa uppgift")
        print("  python -m application.orchestrator run    - Kör alla uppgifter")
        print("  python -m application.orchestrator status - Visa status")
        sys.exit(1)

    command = sys.argv[1]

    if command == "tick":
        run_tick()
    elif command == "run":
        orchestrator = Orchestrator()
        orchestrator.run_all()
    elif command == "status":
        show_status()
    else:
        print(f"Okänt kommando: {command}")
