"""
Testing tools - run_tests, run_lint, run_typecheck
Kör riktiga tester, inte bara AI-analys.
"""
import subprocess
from pathlib import Path

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "run_tests",
        "description": "KÖR befintliga tester (pytest, npm test). OBS: Använd assign_tester() FÖRST för att SKRIVA tester!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "pytest", "npm", "bun", "go"],
                    "description": "Testramverk (auto = detektera automatiskt)"
                },
                "path": {
                    "type": "string",
                    "description": "Specifik fil/mapp att testa"
                },
                "verbose": {
                    "type": "boolean",
                    "description": "Visa detaljerad output"
                }
            },
            "required": []
        }
    },
    {
        "name": "run_lint",
        "description": "Kör linting för kodkvalitet (flake8, eslint, etc).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "flake8", "ruff", "eslint", "prettier"],
                    "description": "Lint-verktyg (auto = detektera automatiskt)"
                },
                "path": {
                    "type": "string",
                    "description": "Specifik fil/mapp att linta"
                },
                "fix": {
                    "type": "boolean",
                    "description": "Försök fixa automatiskt (om stöds)"
                }
            },
            "required": []
        }
    },
    {
        "name": "run_typecheck",
        "description": "Kör typkontroll (mypy, tsc, pyright).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "mypy", "pyright", "tsc"],
                    "description": "Typchecker (auto = detektera automatiskt)"
                },
                "path": {
                    "type": "string",
                    "description": "Specifik fil/mapp att typechecka"
                }
            },
            "required": []
        }
    },
]


def detect_project_type(cwd: str) -> dict:
    """Detektera projekttyp baserat på filer."""
    cwd_path = Path(cwd)

    info = {
        "python": False,
        "node": False,
        "go": False,
        "has_pytest": False,
        "has_package_json": False,
        "has_go_mod": False,
    }

    # Python
    if list(cwd_path.glob("*.py")) or list(cwd_path.glob("**/*.py")):
        info["python"] = True
    if (cwd_path / "pytest.ini").exists() or (cwd_path / "pyproject.toml").exists():
        info["has_pytest"] = True
    if (cwd_path / "requirements.txt").exists():
        info["python"] = True

    # Node
    if (cwd_path / "package.json").exists():
        info["node"] = True
        info["has_package_json"] = True

    # Go
    if (cwd_path / "go.mod").exists():
        info["go"] = True
        info["has_go_mod"] = True

    return info


def run_command(cmd: list, cwd: str, timeout: int = 120) -> tuple[bool, str]:
    """Kör kommando och returnera (success, output)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd
        )
        output = result.stdout + result.stderr
        success = result.returncode == 0
        return success, output
    except subprocess.TimeoutExpired:
        return False, f"TIMEOUT efter {timeout}s"
    except FileNotFoundError:
        return False, f"Kommando ej hittat: {cmd[0]}"
    except Exception as e:
        return False, f"Fel: {e}"


def run_tests(arguments: dict, cwd: str) -> dict:
    """Kör tester."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", "")
    verbose = arguments.get("verbose", False)

    log_to_sprint(cwd, f"🧪 STARTAR TESTER ({framework})...")

    project = detect_project_type(cwd)
    results = []
    any_success = False

    # Auto-detect eller specifikt ramverk
    if framework == "auto":
        # Prova i ordning
        if project["python"]:
            framework = "pytest"
        elif project["node"]:
            framework = "npm"
        elif project["go"]:
            framework = "go"
        else:
            return make_response("❌ Kunde inte detektera testramverk. Ange framework manuellt.")

    # Kör tester baserat på ramverk
    if framework == "pytest":
        cmd = ["pytest"]
        if verbose:
            cmd.append("-v")
        if path:
            cmd.append(path)
        else:
            # Leta efter tests-mapp
            if (Path(cwd) / "tests").exists():
                cmd.append("tests/")

        success, output = run_command(cmd, cwd)
        any_success = success
        status = "✅ PASS" if success else "❌ FAIL"
        results.append(f"**pytest** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "npm":
        cmd = ["npm", "test"]
        success, output = run_command(cmd, cwd, timeout=180)
        any_success = success
        status = "✅ PASS" if success else "❌ FAIL"
        results.append(f"**npm test** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "bun":
        cmd = ["bun", "test"]
        if path:
            cmd.append(path)
        success, output = run_command(cmd, cwd)
        any_success = success
        status = "✅ PASS" if success else "❌ FAIL"
        results.append(f"**bun test** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "go":
        cmd = ["go", "test", "./..."]
        if verbose:
            cmd.insert(2, "-v")
        success, output = run_command(cmd, cwd)
        any_success = success
        status = "✅ PASS" if success else "❌ FAIL"
        results.append(f"**go test** {status}\n```\n{output[-2000:]}\n```")

    final_status = "✅ TESTER GODKÄNDA" if any_success else "❌ TESTER MISSLYCKADES"
    log_to_sprint(cwd, f"🧪 {final_status}")

    return make_response(f"🧪 TEST RESULTAT: {final_status}\n\n" + "\n\n".join(results))


def run_lint(arguments: dict, cwd: str) -> dict:
    """Kör linting."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", ".")
    fix = arguments.get("fix", False)

    log_to_sprint(cwd, f"🔍 STARTAR LINTING ({framework})...")

    project = detect_project_type(cwd)
    results = []
    any_issues = False

    # Auto-detect
    if framework == "auto":
        if project["python"]:
            framework = "ruff"  # Ruff är snabbast
        elif project["node"]:
            framework = "eslint"
        else:
            return make_response("❌ Kunde inte detektera lint-verktyg. Ange framework manuellt.")

    # Kör lint
    if framework == "ruff":
        cmd = ["ruff", "check", path]
        if fix:
            cmd.append("--fix")
        success, output = run_command(cmd, cwd)
        any_issues = not success
        status = "✅ CLEAN" if success else "⚠️ ISSUES"
        results.append(f"**ruff** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "flake8":
        cmd = ["flake8", path]
        success, output = run_command(cmd, cwd)
        any_issues = not success
        status = "✅ CLEAN" if success else "⚠️ ISSUES"
        results.append(f"**flake8** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "eslint":
        cmd = ["npx", "eslint", path]
        if fix:
            cmd.append("--fix")
        success, output = run_command(cmd, cwd)
        any_issues = not success
        status = "✅ CLEAN" if success else "⚠️ ISSUES"
        results.append(f"**eslint** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "prettier":
        cmd = ["npx", "prettier", "--check", path]
        if fix:
            cmd = ["npx", "prettier", "--write", path]
        success, output = run_command(cmd, cwd)
        any_issues = not success
        status = "✅ FORMATTED" if success else "⚠️ NEEDS FORMAT"
        results.append(f"**prettier** {status}\n```\n{output[-2000:]}\n```")

    final_status = "⚠️ LINT ISSUES HITTADE" if any_issues else "✅ LINT CLEAN"
    log_to_sprint(cwd, f"🔍 {final_status}")

    return make_response(f"🔍 LINT RESULTAT: {final_status}\n\n" + "\n\n".join(results))


def run_typecheck(arguments: dict, cwd: str) -> dict:
    """Kör typkontroll."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", ".")

    log_to_sprint(cwd, f"📝 STARTAR TYPECHECK ({framework})...")

    project = detect_project_type(cwd)
    results = []
    any_errors = False

    # Auto-detect
    if framework == "auto":
        if project["python"]:
            framework = "mypy"
        elif project["node"]:
            framework = "tsc"
        else:
            return make_response("❌ Kunde inte detektera typechecker. Ange framework manuellt.")

    # Kör typecheck
    if framework == "mypy":
        cmd = ["mypy", path]
        success, output = run_command(cmd, cwd)
        any_errors = not success
        status = "✅ CLEAN" if success else "❌ TYPE ERRORS"
        results.append(f"**mypy** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "pyright":
        cmd = ["pyright", path]
        success, output = run_command(cmd, cwd)
        any_errors = not success
        status = "✅ CLEAN" if success else "❌ TYPE ERRORS"
        results.append(f"**pyright** {status}\n```\n{output[-2000:]}\n```")

    elif framework == "tsc":
        cmd = ["npx", "tsc", "--noEmit"]
        success, output = run_command(cmd, cwd)
        any_errors = not success
        status = "✅ CLEAN" if success else "❌ TYPE ERRORS"
        results.append(f"**tsc** {status}\n```\n{output[-2000:]}\n```")

    final_status = "❌ TYPFEL HITTADE" if any_errors else "✅ TYPER OK"
    log_to_sprint(cwd, f"📝 {final_status}")

    return make_response(f"📝 TYPECHECK RESULTAT: {final_status}\n\n" + "\n\n".join(results))


HANDLERS = {
    "run_tests": run_tests,
    "run_lint": run_lint,
    "run_typecheck": run_typecheck,
}
