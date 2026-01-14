"""
Git Operations - Grundläggande git-kommandon.
"""
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent


def run_git(command: str, check: bool = True) -> dict:
    """
    Kör ett git-kommando.

    Returns:
        dict med {success, stdout, stderr, returncode}
    """
    try:
        result = subprocess.run(
            f"git {command}",
            shell=True,
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT
        )
        success = result.returncode == 0
        if check and not success:
            print(f"[GIT] Varning: {result.stderr}")
        return {
            "success": success,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "returncode": result.returncode
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }


def get_current_branch() -> str:
    """Hämta nuvarande branch-namn."""
    result = run_git("branch --show-current", check=False)
    return result["stdout"] if result["success"] else "unknown"


def branch_exists(branch_name: str) -> bool:
    """Kolla om en branch existerar."""
    result = run_git(f"branch --list {branch_name}", check=False)
    return bool(result["stdout"])


def create_branch(task_id: str) -> dict:
    """
    Skapa en feature-branch för en task.

    Returns:
        dict med {success, branch_name, error, created}
    """
    branch_name = f"feature/task-{task_id}"

    if branch_exists(branch_name):
        result = run_git(f"checkout {branch_name}")
        return {
            "success": result["success"],
            "branch_name": branch_name,
            "error": result["stderr"] if not result["success"] else None,
            "created": False
        }

    result = run_git(f"checkout -b {branch_name}")
    return {
        "success": result["success"],
        "branch_name": branch_name,
        "error": result["stderr"] if not result["success"] else None,
        "created": True
    }


def checkout_branch(branch_name: str) -> dict:
    """Checka ut en branch."""
    result = run_git(f"checkout {branch_name}")
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def checkout_main() -> dict:
    """Gå tillbaka till main/master."""
    result = run_git("checkout main", check=False)
    if not result["success"]:
        result = run_git("checkout master", check=False)
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def commit_changes(task_id: str, description: str) -> dict:
    """
    Committa alla ändringar för en task.

    Returns:
        dict med {success, commit_hash, error}
    """
    add_result = run_git("add -A")
    if not add_result["success"]:
        return {
            "success": False,
            "commit_hash": None,
            "error": f"git add misslyckades: {add_result['stderr']}"
        }

    status = run_git("status --porcelain", check=False)
    if not status["stdout"]:
        return {
            "success": True,
            "commit_hash": None,
            "error": "Inga ändringar att committa"
        }

    short_desc = description[:50] + "..." if len(description) > 50 else description
    message = f"feat(task-{task_id}): {short_desc}"

    commit_result = run_git(f'commit -m "{message}"')
    if not commit_result["success"]:
        return {
            "success": False,
            "commit_hash": None,
            "error": f"git commit misslyckades: {commit_result['stderr']}"
        }

    hash_result = run_git("rev-parse --short HEAD", check=False)
    commit_hash = hash_result["stdout"] if hash_result["success"] else "unknown"

    return {
        "success": True,
        "commit_hash": commit_hash,
        "error": None
    }


def push_branch(branch_name: str) -> dict:
    """Pusha branch till remote."""
    result = run_git(f"push -u origin {branch_name}")
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def get_branch_status(branch_name: str = None) -> dict:
    """Hämta status för en branch (ahead/behind remote)."""
    if branch_name is None:
        branch_name = get_current_branch()

    result = run_git(f"rev-parse --abbrev-ref {branch_name}@{{upstream}}", check=False)
    if not result["success"]:
        return {"ahead": 0, "behind": 0, "has_remote": False}

    result = run_git(f"rev-list --left-right --count {branch_name}...{branch_name}@{{upstream}}", check=False)
    if result["success"] and result["stdout"]:
        parts = result["stdout"].split()
        if len(parts) == 2:
            return {
                "ahead": int(parts[0]),
                "behind": int(parts[1]),
                "has_remote": True
            }

    return {"ahead": 0, "behind": 0, "has_remote": True}


def get_uncommitted_changes() -> list:
    """Hämta lista på uncommittade filer."""
    result = run_git("status --porcelain", check=False)
    if not result["success"] or not result["stdout"]:
        return []

    files = []
    for line in result["stdout"].split("\n"):
        if line.strip():
            status = line[:2]
            filename = line[3:]
            files.append({"status": status, "file": filename})
    return files
