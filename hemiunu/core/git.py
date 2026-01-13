"""
Hemiunu Git - Hantering av git-operationer.

Funktioner:
- Skapa feature-branch per task
- Commit ändringar
- Push till remote
- Hämta branch-status
"""
import subprocess
from pathlib import Path
from typing import Optional

PROJECT_ROOT = Path(__file__).parent.parent


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
        dict med {success, branch_name, error}
    """
    branch_name = f"feature/task-{task_id}"

    # Kolla om branchen redan finns
    if branch_exists(branch_name):
        # Checka ut existerande branch
        result = run_git(f"checkout {branch_name}")
        return {
            "success": result["success"],
            "branch_name": branch_name,
            "error": result["stderr"] if not result["success"] else None,
            "created": False
        }

    # Skapa och checka ut ny branch
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


def commit_changes(task_id: str, description: str) -> dict:
    """
    Committa alla ändringar för en task.

    Returns:
        dict med {success, commit_hash, error}
    """
    # Lägg till alla ändringar
    add_result = run_git("add -A")
    if not add_result["success"]:
        return {
            "success": False,
            "commit_hash": None,
            "error": f"git add misslyckades: {add_result['stderr']}"
        }

    # Kolla om det finns något att committa
    status = run_git("status --porcelain", check=False)
    if not status["stdout"]:
        return {
            "success": True,
            "commit_hash": None,
            "error": "Inga ändringar att committa"
        }

    # Skapa commit-meddelande
    short_desc = description[:50] + "..." if len(description) > 50 else description
    message = f"feat(task-{task_id}): {short_desc}"

    # Committa
    commit_result = run_git(f'commit -m "{message}"')
    if not commit_result["success"]:
        return {
            "success": False,
            "commit_hash": None,
            "error": f"git commit misslyckades: {commit_result['stderr']}"
        }

    # Hämta commit hash
    hash_result = run_git("rev-parse --short HEAD", check=False)
    commit_hash = hash_result["stdout"] if hash_result["success"] else "unknown"

    return {
        "success": True,
        "commit_hash": commit_hash,
        "error": None
    }


def push_branch(branch_name: str) -> dict:
    """
    Pusha branch till remote.

    Returns:
        dict med {success, error}
    """
    result = run_git(f"push -u origin {branch_name}")
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def get_branch_status(branch_name: str = None) -> dict:
    """
    Hämta status för en branch (ahead/behind remote).

    Returns:
        dict med {ahead, behind, has_remote}
    """
    if branch_name is None:
        branch_name = get_current_branch()

    # Kolla om remote finns
    result = run_git(f"rev-parse --abbrev-ref {branch_name}@{{upstream}}", check=False)
    if not result["success"]:
        return {"ahead": 0, "behind": 0, "has_remote": False}

    # Hämta ahead/behind
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


def checkout_main() -> dict:
    """Gå tillbaka till main/master."""
    # Prova main först, sedan master
    result = run_git("checkout main", check=False)
    if not result["success"]:
        result = run_git("checkout master", check=False)
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def get_uncommitted_changes() -> list:
    """Hämta lista på uncommittade filer."""
    result = run_git("status --porcelain", check=False)
    if not result["success"] or not result["stdout"]:
        return []

    files = []
    for line in result["stdout"].split("\n"):
        if line.strip():
            # Format: "XY filename" där X=index, Y=worktree
            status = line[:2]
            filename = line[3:]
            files.append({"status": status, "file": filename})
    return files


# === KONFLIKT-HANTERING ===

def start_merge(branch_name: str) -> dict:
    """
    Starta en merge utan att committa.

    Returns:
        dict med {success, conflict, conflict_files, error}
    """
    result = run_git(f"merge {branch_name} --no-commit --no-ff", check=False)

    if result["success"]:
        return {"success": True, "conflict": False, "conflict_files": [], "error": None}

    # Kolla om det är en konflikt
    if "CONFLICT" in result["stdout"] or "CONFLICT" in result["stderr"]:
        # Hämta konfliktfiler
        conflict_files = get_conflict_files()
        return {
            "success": False,
            "conflict": True,
            "conflict_files": conflict_files,
            "error": result["stdout"] + result["stderr"]
        }

    return {
        "success": False,
        "conflict": False,
        "conflict_files": [],
        "error": result["stderr"]
    }


def get_conflict_files() -> list:
    """Hämta lista på filer med konflikter."""
    result = run_git("diff --name-only --diff-filter=U", check=False)
    if not result["success"] or not result["stdout"]:
        return []
    return [f.strip() for f in result["stdout"].split("\n") if f.strip()]


def get_conflict_content(file_path: str) -> dict:
    """
    Hämta innehållet i en konfliktfil med markörer.

    Returns:
        dict med {ours, theirs, merged}
    """
    full_path = PROJECT_ROOT / file_path

    try:
        with open(full_path, "r") as f:
            content = f.read()
    except Exception as e:
        return {"error": str(e)}

    # Parsa konfliktmarkörer
    ours = []
    theirs = []
    current = None

    for line in content.split("\n"):
        if line.startswith("<<<<<<<"):
            current = "ours"
        elif line.startswith("======="):
            current = "theirs"
        elif line.startswith(">>>>>>>"):
            current = None
        elif current == "ours":
            ours.append(line)
        elif current == "theirs":
            theirs.append(line)

    return {
        "full_content": content,
        "ours": "\n".join(ours),
        "theirs": "\n".join(theirs)
    }


def resolve_file_conflict(file_path: str, resolved_content: str) -> dict:
    """
    Lös en konflikt genom att skriva resolved innehåll.

    Returns:
        dict med {success, error}
    """
    full_path = PROJECT_ROOT / file_path

    try:
        with open(full_path, "w") as f:
            f.write(resolved_content)

        # Markera som resolved
        result = run_git(f"add {file_path}")
        return {
            "success": result["success"],
            "error": result["stderr"] if not result["success"] else None
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def abort_merge() -> dict:
    """Avbryt pågående merge."""
    result = run_git("merge --abort", check=False)
    return {
        "success": result["success"],
        "error": result["stderr"] if not result["success"] else None
    }


def complete_merge(message: str) -> dict:
    """Slutför merge med commit."""
    result = run_git(f'commit -m "{message}"')
    if not result["success"]:
        return {"success": False, "commit_hash": None, "error": result["stderr"]}

    hash_result = run_git("rev-parse --short HEAD", check=False)
    return {
        "success": True,
        "commit_hash": hash_result["stdout"] if hash_result["success"] else "unknown",
        "error": None
    }


def get_file_from_branch(branch_name: str, file_path: str) -> dict:
    """
    Hämta filinnehåll från en specifik branch.

    Returns:
        dict med {success, content, error}
    """
    result = run_git(f"show {branch_name}:{file_path}", check=False)
    return {
        "success": result["success"],
        "content": result["stdout"] if result["success"] else None,
        "error": result["stderr"] if not result["success"] else None
    }


if __name__ == "__main__":
    # Test
    print("Testing git.py...")
    print(f"Current branch: {get_current_branch()}")
    print(f"Uncommitted: {get_uncommitted_changes()}")
    print(f"Branch status: {get_branch_status()}")
