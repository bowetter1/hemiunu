"""
Hemiunu Golden Thread - Kontextinjektion för agenter.

Golden Thread är den gemensamma kontexten som alla agenter delar:
- Projektets vision (från Master)
- Relevanta existerande filer
- Tidigare beslut och patterns
- Kodstil och konventioner

Maximal kontext: ~2000 tokens för att hålla agenter fokuserade.
"""
from pathlib import Path
from substrate.db import get_master, get_all_tasks, get_task
from core.git import get_current_branch, get_uncommitted_changes

PROJECT_ROOT = Path(__file__).parent.parent
MAX_CONTEXT_CHARS = 8000  # ~2000 tokens


def get_project_structure(max_depth: int = 2) -> str:
    """
    Hämta projektstruktur för kontext.

    Returns:
        Formaterad sträng med katalogstruktur
    """
    def walk_dir(path: Path, depth: int = 0) -> list:
        if depth > max_depth:
            return []

        items = []
        try:
            for item in sorted(path.iterdir()):
                # Skippa dolda filer och __pycache__
                if item.name.startswith('.') or item.name == '__pycache__':
                    continue
                if item.name in ['venv', '.venv', 'node_modules', '.git']:
                    continue

                indent = "  " * depth
                if item.is_dir():
                    items.append(f"{indent}{item.name}/")
                    items.extend(walk_dir(item, depth + 1))
                else:
                    items.append(f"{indent}{item.name}")
        except PermissionError:
            pass

        return items

    structure = walk_dir(PROJECT_ROOT)
    return "\n".join(structure[:50])  # Max 50 rader


def get_relevant_files(task_description: str) -> list:
    """
    Hitta relevanta filer baserat på task-beskrivning.

    Returns:
        Lista med filsökvägar som kan vara relevanta
    """
    keywords = task_description.lower().split()
    relevant = []

    # Sök genom Python-filer
    for py_file in PROJECT_ROOT.rglob("*.py"):
        # Skippa venv
        if '.venv' in str(py_file) or 'venv' in str(py_file):
            continue
        if '__pycache__' in str(py_file):
            continue

        rel_path = py_file.relative_to(PROJECT_ROOT)
        file_name = py_file.stem.lower()

        # Kolla om filnamn matchar keywords
        for keyword in keywords:
            if len(keyword) > 3 and keyword in file_name:
                relevant.append(str(rel_path))
                break

    return relevant[:5]  # Max 5 filer


def get_code_conventions() -> str:
    """
    Extrahera kodkonventioner från existerande kod.

    Returns:
        Beskrivning av kodstil
    """
    conventions = []

    # Kolla om det finns en cli.py
    cli_path = PROJECT_ROOT / "cli.py"
    if cli_path.exists():
        conventions.append("- CLI-kommandon via cli.py")

    # Kolla om det finns tests/
    tests_path = PROJECT_ROOT / "tests"
    if tests_path.exists():
        conventions.append("- Tester i tests/-mappen")

    # Kolla docstrings i existerande filer
    sample_files = list(PROJECT_ROOT.glob("*.py"))[:3]
    for f in sample_files:
        try:
            content = f.read_text()
            if '"""' in content[:500]:
                conventions.append("- Docstrings på moduler och funktioner")
                break
        except:
            pass

    if not conventions:
        conventions.append("- Ingen etablerad kodstil ännu")

    return "\n".join(conventions)


def build_golden_thread(task: dict = None) -> dict:
    """
    Bygg Golden Thread-kontext för en agent.

    Args:
        task: Optional task att bygga kontext för

    Returns:
        dict med {vision, structure, conventions, relevant_files, git_status}
    """
    context = {}

    # Vision
    context["vision"] = get_master() or "Inget projekt definierat"

    # Projektstruktur
    context["structure"] = get_project_structure()

    # Kodkonventioner
    context["conventions"] = get_code_conventions()

    # Git-status
    context["git_branch"] = get_current_branch()
    changes = get_uncommitted_changes()
    context["uncommitted_files"] = [c["file"] for c in changes][:5]

    # Relevanta filer för task
    if task and task.get("description"):
        context["relevant_files"] = get_relevant_files(task["description"])
    else:
        context["relevant_files"] = []

    # Existerande tasks (för kontext)
    all_tasks = get_all_tasks()
    context["existing_tasks"] = [
        {"id": t["id"], "status": t["status"], "desc": t["description"][:40]}
        for t in all_tasks[:10]
    ]

    return context


def format_golden_thread(context: dict) -> str:
    """
    Formatera Golden Thread till en sträng för injection i prompt.

    Args:
        context: Dict från build_golden_thread()

    Returns:
        Formaterad sträng, max MAX_CONTEXT_CHARS
    """
    parts = []

    # Vision (alltid med)
    parts.append(f"=== PROJEKTVISION ===\n{context['vision']}")

    # Struktur
    if context.get("structure"):
        parts.append(f"\n=== PROJEKTSTRUKTUR ===\n{context['structure']}")

    # Konventioner
    if context.get("conventions"):
        parts.append(f"\n=== KODKONVENTIONER ===\n{context['conventions']}")

    # Git
    parts.append(f"\n=== GIT ===\nBranch: {context.get('git_branch', 'unknown')}")
    if context.get("uncommitted_files"):
        parts.append(f"Uncommitted: {', '.join(context['uncommitted_files'])}")

    # Relevanta filer
    if context.get("relevant_files"):
        parts.append(f"\n=== RELEVANTA FILER ===\n" + "\n".join(context["relevant_files"]))

    # Tasks
    if context.get("existing_tasks"):
        task_lines = [f"[{t['status']}] {t['id']}: {t['desc']}" for t in context["existing_tasks"]]
        parts.append(f"\n=== EXISTERANDE TASKS ===\n" + "\n".join(task_lines))

    result = "\n".join(parts)

    # Trunkera om för långt
    if len(result) > MAX_CONTEXT_CHARS:
        result = result[:MAX_CONTEXT_CHARS] + "\n... (trunkerad)"

    return result


def get_task_context(task_id: str) -> dict:
    """
    Hämta full kontext för en specifik task.

    Args:
        task_id: ID på task

    Returns:
        Golden Thread-kontext anpassad för tasken
    """
    task = get_task(task_id)
    if not task:
        return build_golden_thread()

    return build_golden_thread(task)


if __name__ == "__main__":
    print("Testing context.py...")

    context = build_golden_thread()
    print("\n=== RAW CONTEXT ===")
    for key, value in context.items():
        print(f"{key}: {value}")

    print("\n=== FORMATTED ===")
    print(format_golden_thread(context))
