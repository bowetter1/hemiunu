#!/usr/bin/env python3
"""
Hemiunu Deploy Cycle - Automatisk merge och deploy.

Körs: Var 15:e minut (via cron) eller manuellt.

Flöde:
1. git checkout main && git pull
2. Hämta GREEN branches från DB
3. För varje branch:
   - git merge origin/{branch} --no-edit
   - Om konflikt: spara conflict-record, fortsätt med nästa
4. git push origin main
5. Kör integrationstester
6. Om grönt: markera tasks som DEPLOYED
7. Om rött: git reset --hard, notifiera
"""
import json
from datetime import datetime
from substrate.db import (
    get_tasks_by_status,
    update_task,
    save_deploy,
    save_conflict,
    get_deploy_log
)
from core.git import run_git, get_current_branch, checkout_main


def pull_main():
    """Uppdatera main från remote."""
    checkout_main()
    result = run_git("pull origin main", check=False)
    return {
        "success": result["success"] or "Already up to date" in result["stdout"],
        "output": result["stdout"] or result["stderr"]
    }


def merge_branch(branch_name):
    """Försök merga en branch till main."""
    result = run_git(f"merge {branch_name} --no-edit", check=False)

    if result["success"]:
        return {"success": True, "conflict": False, "error": None}

    if "CONFLICT" in result["stdout"] or "CONFLICT" in result["stderr"]:
        run_git("merge --abort", check=False)
        return {
            "success": False,
            "conflict": True,
            "error": result["stdout"] + result["stderr"]
        }

    return {
        "success": False,
        "conflict": False,
        "error": result["stderr"]
    }


def run_integration_tests():
    """Kör integrationstester."""
    import subprocess
    from pathlib import Path

    project_root = Path(__file__).parent
    test_dir = project_root / "tests"

    test_files = list(test_dir.glob("test_*.py")) if test_dir.exists() else []
    if not test_files:
        return {"success": True, "output": "Inga tester att köra"}

    all_passed = True
    outputs = []

    for test_file in test_files:
        try:
            proc = subprocess.run(
                ["python3", str(test_file)],
                capture_output=True,
                text=True,
                timeout=60,
                cwd=project_root
            )
            outputs.append(f"{test_file.name}: {'PASS' if proc.returncode == 0 else 'FAIL'}")
            if proc.returncode != 0:
                all_passed = False
        except Exception as e:
            all_passed = False
            outputs.append(f"{test_file.name}: ERROR - {e}")

    return {"success": all_passed, "output": "\n".join(outputs)}


def push_main():
    """Pusha main till remote."""
    result = run_git("push origin main", check=False)
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def reset_main():
    """Återställ main till remote state."""
    result = run_git("reset --hard origin/main", check=False)
    return {"success": result["success"]}


def run_deploy_cycle(dry_run=False):
    """Kör en deploy-cykel."""
    print(f"\n{'='*60}")
    print(f"DEPLOY CYCLE - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}\n")

    green_tasks = get_tasks_by_status("GREEN")
    branches_to_merge = [
        t for t in green_tasks
        if t.get("branch") and t["status"] == "GREEN"
    ]

    if not branches_to_merge:
        print("[DEPLOY] Inga GREEN branches att merga")
        return {"success": True, "merged": [], "conflicts": [], "deployed": [], "error": None}

    print(f"[DEPLOY] Hittade {len(branches_to_merge)} GREEN branches")
    for t in branches_to_merge:
        print(f"  - {t['branch']}: {t['description'][:40]}")

    if dry_run:
        print("\n[DEPLOY] DRY RUN - inga ändringar görs")
        return {"success": True, "merged": [t["branch"] for t in branches_to_merge], "conflicts": [], "deployed": [], "error": None}

    print("\n[DEPLOY] Uppdaterar main...")
    pull_main()

    merged = []
    conflicts = []

    for task in branches_to_merge:
        branch = task["branch"]
        print(f"\n[DEPLOY] Mergar {branch}...")

        merge_result = merge_branch(branch)

        if merge_result["success"]:
            print(f"[DEPLOY] ✓ Mergad: {branch}")
            merged.append(branch)
        elif merge_result["conflict"]:
            print(f"[DEPLOY] ✗ Konflikt: {branch}")
            conflicts.append(branch)
            save_conflict("main", branch)
        else:
            print(f"[DEPLOY] ✗ Fel: {merge_result['error']}")

    if not merged:
        print("\n[DEPLOY] Inga branches mergades")
        return {"success": False, "merged": [], "conflicts": conflicts, "deployed": [], "error": "Inga branches kunde mergas"}

    print("\n[DEPLOY] Kör integrationstester...")
    test_result = run_integration_tests()

    if not test_result["success"]:
        print(f"[DEPLOY] ✗ Tester misslyckades!")
        reset_main()
        save_deploy(merged, "FAILED", error="Integration tests failed")
        return {"success": False, "merged": merged, "conflicts": conflicts, "deployed": [], "error": "Integration tests failed"}

    print("[DEPLOY] ✓ Alla tester passerade")

    print("\n[DEPLOY] Pushar main...")
    push_main()

    deployed = []
    for task in branches_to_merge:
        if task["branch"] in merged:
            update_task(task["id"], status="DEPLOYED")
            deployed.append(task["id"])
            print(f"[DEPLOY] ✓ Deployed: {task['id']}")

    commit_hash = run_git("rev-parse --short HEAD", check=False)["stdout"]
    save_deploy(merged, "SUCCESS", commit_hash=commit_hash)

    print(f"\n{'='*60}")
    print(f"DEPLOY KLAR - Merged: {len(merged)}, Conflicts: {len(conflicts)}, Deployed: {len(deployed)}")
    print(f"{'='*60}\n")

    return {"success": True, "merged": merged, "conflicts": conflicts, "deployed": deployed, "error": None}


def show_deploy_history():
    """Visa deploy-historik."""
    deploys = get_deploy_log(10)
    print("\n" + "="*60)
    print("DEPLOY HISTORIK")
    print("="*60)
    if not deploys:
        print("Ingen deploy-historik")
    else:
        for d in deploys:
            status_icon = "✓" if d["status"] == "SUCCESS" else "✗"
            branches = json.loads(d["branches"]) if d["branches"] else []
            print(f"{status_icon} {d['created_at']}: {d['status']} - {', '.join(branches)}")
    print("="*60 + "\n")


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Kommandon: run, dry-run, history")
        sys.exit(0)
    cmd = sys.argv[1]
    if cmd == "run":
        run_deploy_cycle()
    elif cmd == "dry-run":
        run_deploy_cycle(dry_run=True)
    elif cmd == "history":
        show_deploy_history()
    else:
        print(f"Okänt: {cmd}")
