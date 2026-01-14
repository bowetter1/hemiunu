"""
Codebase Indexer - Bygger och underhåller ett index över kodbasen.

Indexet hjälper agenter att:
- Förstå filstruktur
- Hitta funktioner/klasser
- Se beroenden mellan moduler
- Undvika duplicering
"""
import ast
import json
from pathlib import Path
from datetime import datetime
from typing import Optional

# Projektrot
PROJECT_ROOT = Path(__file__).parent.parent.parent

# Index-fil
INDEX_PATH = PROJECT_ROOT / "codebase_index.json"

# Mappar att ignorera
IGNORE_DIRS = {".venv", ".git", "__pycache__", "node_modules", ".pytest_cache", "logs"}

# Filer att ignorera
IGNORE_FILES = {".DS_Store", ".env"}


def extract_python_info(file_path: Path) -> dict:
    """
    Extrahera information från en Python-fil.

    Returns:
        dict med functions, classes, imports
    """
    try:
        content = file_path.read_text(encoding="utf-8")
        tree = ast.parse(content)
    except (SyntaxError, UnicodeDecodeError):
        return {"error": "Could not parse file"}

    info = {
        "functions": [],
        "classes": [],
        "imports": [],
        "docstring": ast.get_docstring(tree)
    }

    for node in ast.walk(tree):
        # Funktioner
        if isinstance(node, ast.FunctionDef):
            func_info = {
                "name": node.name,
                "args": [arg.arg for arg in node.args.args],
                "line": node.lineno,
                "docstring": ast.get_docstring(node)
            }
            # Returntyp om den finns
            if node.returns:
                func_info["returns"] = ast.unparse(node.returns)
            info["functions"].append(func_info)

        # Klasser
        elif isinstance(node, ast.ClassDef):
            class_info = {
                "name": node.name,
                "line": node.lineno,
                "docstring": ast.get_docstring(node),
                "bases": [ast.unparse(base) for base in node.bases],
                "methods": []
            }
            # Metoder i klassen
            for item in node.body:
                if isinstance(item, ast.FunctionDef):
                    class_info["methods"].append({
                        "name": item.name,
                        "args": [arg.arg for arg in item.args.args],
                        "line": item.lineno
                    })
            info["classes"].append(class_info)

        # Imports
        elif isinstance(node, ast.Import):
            for alias in node.names:
                info["imports"].append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            for alias in node.names:
                info["imports"].append(f"{module}.{alias.name}")

    return info


def build_index(root: Path = None) -> dict:
    """
    Bygg ett komplett index över kodbasen.

    Args:
        root: Rotkatalog att indexera (default: PROJECT_ROOT)

    Returns:
        dict med struktur, filer, och metadata
    """
    root = root or PROJECT_ROOT

    index = {
        "version": "1.0",
        "generated_at": datetime.now().isoformat(),
        "root": str(root),
        "structure": {},
        "files": {},
        "summary": {
            "total_files": 0,
            "total_functions": 0,
            "total_classes": 0,
            "python_files": 0
        }
    }

    def process_directory(dir_path: Path, relative_to: Path) -> dict:
        """Rekursivt processa en katalog."""
        result = {"type": "directory", "children": {}}

        try:
            items = sorted(dir_path.iterdir())
        except PermissionError:
            return result

        for item in items:
            name = item.name

            # Ignorera vissa mappar/filer
            if name in IGNORE_DIRS or name in IGNORE_FILES:
                continue
            if name.startswith("."):
                continue

            rel_path = str(item.relative_to(relative_to))

            if item.is_dir():
                result["children"][name] = process_directory(item, relative_to)

            elif item.is_file():
                index["summary"]["total_files"] += 1

                file_info = {
                    "type": "file",
                    "size": item.stat().st_size,
                    "extension": item.suffix
                }

                # Extrahera Python-info
                if item.suffix == ".py":
                    index["summary"]["python_files"] += 1
                    py_info = extract_python_info(item)
                    file_info["python"] = py_info
                    index["files"][rel_path] = py_info

                    # Uppdatera sammanfattning
                    index["summary"]["total_functions"] += len(py_info.get("functions", []))
                    index["summary"]["total_classes"] += len(py_info.get("classes", []))

                result["children"][name] = file_info

        return result

    index["structure"] = process_directory(root, root)

    return index


def save_index(index: dict = None, path: Path = None):
    """
    Spara indexet till fil.

    Args:
        index: Indexet att spara (bygger nytt om None)
        path: Sökväg att spara till (default: INDEX_PATH)
    """
    if index is None:
        index = build_index()

    path = path or INDEX_PATH

    with open(path, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)

    return path


def load_index(path: Path = None) -> Optional[dict]:
    """
    Ladda indexet från fil.

    Args:
        path: Sökväg att ladda från (default: INDEX_PATH)

    Returns:
        Index-dict eller None om filen inte finns
    """
    path = path or INDEX_PATH

    if not path.exists():
        return None

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_index() -> dict:
    """
    Hämta indexet, bygg nytt om det saknas eller är gammalt.

    Returns:
        Index-dict
    """
    index = load_index()

    if index is None:
        index = build_index()
        save_index(index)

    return index


def find_function(name: str) -> list:
    """
    Hitta alla funktioner med ett visst namn.

    Args:
        name: Funktionsnamn att söka efter

    Returns:
        Lista med {file, function_info}
    """
    index = get_index()
    results = []

    for file_path, file_info in index.get("files", {}).items():
        for func in file_info.get("functions", []):
            if name.lower() in func["name"].lower():
                results.append({
                    "file": file_path,
                    "function": func
                })

    return results


def find_class(name: str) -> list:
    """
    Hitta alla klasser med ett visst namn.

    Args:
        name: Klassnamn att söka efter

    Returns:
        Lista med {file, class_info}
    """
    index = get_index()
    results = []

    for file_path, file_info in index.get("files", {}).items():
        for cls in file_info.get("classes", []):
            if name.lower() in cls["name"].lower():
                results.append({
                    "file": file_path,
                    "class": cls
                })

    return results


def get_file_summary(file_path: str) -> Optional[dict]:
    """
    Hämta sammanfattning av en specifik fil.

    Args:
        file_path: Relativ sökväg till filen

    Returns:
        dict med filinformation eller None
    """
    index = get_index()
    return index.get("files", {}).get(file_path)


def get_project_summary() -> dict:
    """
    Hämta en kort sammanfattning av projektet.

    Returns:
        dict med projektöversikt
    """
    index = get_index()

    summary = index.get("summary", {})

    # Hitta viktiga moduler
    important_files = []
    for file_path, file_info in index.get("files", {}).items():
        # Filer med flera klasser eller funktioner är viktiga
        num_items = len(file_info.get("functions", [])) + len(file_info.get("classes", []))
        if num_items >= 3:
            important_files.append({
                "path": file_path,
                "functions": len(file_info.get("functions", [])),
                "classes": len(file_info.get("classes", []))
            })

    # Sortera efter komplexitet
    important_files.sort(key=lambda x: x["functions"] + x["classes"], reverse=True)

    return {
        "total_files": summary.get("total_files", 0),
        "python_files": summary.get("python_files", 0),
        "total_functions": summary.get("total_functions", 0),
        "total_classes": summary.get("total_classes", 0),
        "important_files": important_files[:10],
        "generated_at": index.get("generated_at")
    }


def update_index():
    """
    Uppdatera indexet (bygg om och spara).

    Anropas efter att en task är klar.
    """
    index = build_index()
    save_index(index)
    return index


# CLI för manuell körning
if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "build":
        print("Bygger codebase index...")
        index = build_index()
        path = save_index(index)
        print(f"Index sparat till: {path}")
        print(f"  Python-filer: {index['summary']['python_files']}")
        print(f"  Funktioner: {index['summary']['total_functions']}")
        print(f"  Klasser: {index['summary']['total_classes']}")

    elif len(sys.argv) > 2 and sys.argv[1] == "find":
        name = sys.argv[2]
        print(f"Söker efter: {name}")

        funcs = find_function(name)
        if funcs:
            print(f"\nFunktioner ({len(funcs)}):")
            for f in funcs:
                print(f"  {f['file']}: {f['function']['name']}()")

        classes = find_class(name)
        if classes:
            print(f"\nKlasser ({len(classes)}):")
            for c in classes:
                print(f"  {c['file']}: {c['class']['name']}")

    else:
        print("Användning:")
        print("  python indexer.py build    - Bygg index")
        print("  python indexer.py find X   - Sök efter X")
