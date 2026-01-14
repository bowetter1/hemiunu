"""
Git Merge - Konflikthantering och merge-operationer.
"""
from pathlib import Path
from .operations import run_git

PROJECT_ROOT = Path(__file__).parent.parent.parent


def start_merge(branch_name: str) -> dict:
    """
    Starta en merge utan att committa.

    Returns:
        dict med {success, conflict, conflict_files, error}
    """
    result = run_git(f"merge {branch_name} --no-commit --no-ff", check=False)

    if result["success"]:
        return {"success": True, "conflict": False, "conflict_files": [], "error": None}

    if "CONFLICT" in result["stdout"] or "CONFLICT" in result["stderr"]:
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
        dict med {ours, theirs, full_content}
    """
    full_path = PROJECT_ROOT / file_path

    try:
        with open(full_path, "r") as f:
            content = f.read()
    except Exception as e:
        return {"error": str(e)}

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
