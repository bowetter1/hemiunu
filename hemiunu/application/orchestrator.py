"""
Orchestrator - Huvudloop som driver AI-agenter.

Flöde:
1. Hämta nästa TODO från DB
2. Spawna Worker-agent
3. Worker skriver kod + testar via CLI
4. Om DONE: Spawna Tester-agent för validering
5. Om godkänt: markera GREEN
6. Om rejectat: ge Worker feedback och retry (max 2 försök)
7. Om fortfarande rejectat: markera RED
"""
from domain.agents import WorkerAgent, TesterAgent
from infrastructure.db import TaskRepository, get_master
from infrastructure.git import create_branch, commit_changes, checkout_main
from infrastructure.codebase import update_index

# Max antal retry-försök efter Tester-rejection
MAX_RETRIES = 2


class Orchestrator:
    """
    Orchestrerar task-exekvering med Twin-Spawn och retry-logik.
    """

    def __init__(self):
        self.vision = get_master() or "Inget projekt definierat"

    def run_task(self, task: dict) -> dict:
        """
        Kör en uppgift med Twin-Spawn (Worker + Tester) och retry-logik.

        Returns:
            dict med {status, worker_result, tester_result, retries}
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

        # Retry-loop
        retry_context = None  # Feedback från tidigare försök
        retries = 0

        for attempt in range(MAX_RETRIES + 1):
            # === WORKER PHASE ===
            if attempt == 0:
                print("\n[ORCH] === WORKER PHASE ===")
            else:
                print(f"\n[ORCH] === WORKER RETRY {attempt}/{MAX_RETRIES} ===")

            worker_context = {"vision": self.vision}
            if retry_context:
                worker_context.update(retry_context)

            worker = WorkerAgent(task, context=worker_context)
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
                        "code_path": f"src/",
                    }
                )
                tester_result = tester.run()

                print(f"[ORCH] Tester status: {tester_result['status']}")

                if tester_result["status"] == "approved":
                    # Godkänt - GREEN
                    TaskRepository.update(task["id"], status="GREEN")
                    TaskRepository.save_test_result(
                        task["id"],
                        passed=True,
                        output=tester_result["result"].get("summary", "OK"),
                        tester_tests=tester_result["result"].get("test_path")
                    )

                    # Uppdatera codebase index
                    try:
                        update_index()
                        print("[ORCH] Codebase index uppdaterat")
                    except Exception as e:
                        print(f"[ORCH] Varning: Kunde inte uppdatera index: {e}")

                    return {
                        "status": "GREEN",
                        "worker_result": worker_result,
                        "tester_result": tester_result,
                        "retries": retries
                    }
                else:
                    # Tester rejektade
                    retries += 1

                    if attempt < MAX_RETRIES:
                        # Förbered retry med feedback
                        rejection_reason = tester_result.get("error", "Unknown error")
                        failed_tests = []
                        if tester_result.get("result"):
                            failed_tests = tester_result["result"].get("failed_tests", [])

                        print(f"[ORCH] Tester avvisade: {rejection_reason[:60]}...")
                        print(f"[ORCH] Förbereder retry med feedback...")

                        retry_context = {
                            "is_retry": True,
                            "attempt": attempt + 1,
                            "rejection_reason": rejection_reason,
                            "failed_tests": failed_tests
                        }
                        continue  # Försök igen
                    else:
                        # Max retries nådda - RED
                        TaskRepository.update(
                            task["id"],
                            status="RED",
                            error=f"[Efter {retries} retries] {tester_result.get('error')}"
                        )
                        TaskRepository.save_test_result(
                            task["id"],
                            passed=False,
                            output=tester_result.get("error", "Rejected after retries"),
                            tester_tests=tester_result["result"].get("test_path") if tester_result.get("result") else None
                        )
                        return {
                            "status": "RED",
                            "worker_result": worker_result,
                            "tester_result": tester_result,
                            "retries": retries
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
                    "tester_result": None,
                    "retries": retries
                }

            else:
                # Worker misslyckades direkt
                TaskRepository.update(
                    task["id"],
                    status="RED",
                    error=worker_result.get("error")
                )
                return {
                    "status": "RED",
                    "worker_result": worker_result,
                    "tester_result": None,
                    "retries": retries
                }

        # Borde aldrig nås
        return {"status": "RED", "error": "Unexpected loop exit", "retries": retries}

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
