"""
Testing tools - run_tests, run_lint, run_typecheck
Run real tests, not just AI analysis.
"""
import subprocess
from pathlib import Path

from .base import make_response, log_to_sprint


TOOLS = [
    {
        "name": "run_tests",
        "description": "RUN existing tests (pytest, npm test). NOTE: Use assign_tester() FIRST to WRITE tests!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "pytest", "npm", "bun", "go"],
                    "description": "Test framework (auto = detect automatically)"
                },
                "path": {
                    "type": "string",
                    "description": "Specific file/folder to test"
                },
                "verbose": {
                    "type": "boolean",
                    "description": "Show detailed output"
                }
            },
            "required": []
        }
    },
    {
        "name": "run_lint",
        "description": "Run linting for code quality (flake8, eslint, etc).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "flake8", "ruff", "eslint", "prettier"],
                    "description": "Lint tool (auto = detect automatically)"
                },
                "path": {
                    "type": "string",
                    "description": "Specific file/folder to lint"
                },
                "fix": {
                    "type": "boolean",
                    "description": "Try to fix automatically (if supported)"
                }
            },
            "required": []
        }
    },
    {
        "name": "run_typecheck",
        "description": "Run type checking (mypy, tsc, pyright).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "mypy", "pyright", "tsc"],
                    "description": "Type checker (auto = detect automatically)"
                },
                "path": {
                    "type": "string",
                    "description": "Specific file/folder to typecheck"
                }
            },
            "required": []
        }
    },
]


def detect_project_type(cwd: str) -> dict:
    """Detect project type based on files."""
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
    """Run command and return (success, output)."""
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
        return False, f"TIMEOUT after {timeout}s"
    except FileNotFoundError:
        return False, f"Command not found: {cmd[0]}"
    except Exception as e:
        return False, f"Error: {e}"


def run_tests(arguments: dict, cwd: str) -> dict:
    """Run tests."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", "")
    verbose = arguments.get("verbose", False)

    log_to_sprint(cwd, f"🧪 STARTING TESTS ({framework})...")

    project = detect_project_type(cwd)
    results = []
    any_success = False

    # Auto-detect or specific framework
    if framework == "auto":
        # Try in order
        if project["python"]:
            framework = "pytest"
        elif project["node"]:
            framework = "npm"
        elif project["go"]:
            framework = "go"
        else:
            return make_response("❌ Could not detect test framework. Specify framework manually.")

    # Run tests based on framework
    if framework == "pytest":
        cmd = ["pytest"]
        if verbose:
            cmd.append("-v")
        if path:
            cmd.append(path)
        else:
            # Look for tests folder
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

    final_status = "✅ TESTS PASSED" if any_success else "❌ TESTS FAILED"
    log_to_sprint(cwd, f"🧪 {final_status}")

    return make_response(f"🧪 TEST RESULT: {final_status}\n\n" + "\n\n".join(results))


def run_lint(arguments: dict, cwd: str) -> dict:
    """Run linting."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", ".")
    fix = arguments.get("fix", False)

    log_to_sprint(cwd, f"🔍 STARTING LINTING ({framework})...")

    project = detect_project_type(cwd)
    results = []
    any_issues = False

    # Auto-detect
    if framework == "auto":
        if project["python"]:
            framework = "ruff"  # Ruff is fastest
        elif project["node"]:
            framework = "eslint"
        else:
            return make_response("❌ Could not detect lint tool. Specify framework manually.")

    # Run lint
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

    final_status = "⚠️ LINT ISSUES FOUND" if any_issues else "✅ LINT CLEAN"
    log_to_sprint(cwd, f"🔍 {final_status}")

    return make_response(f"🔍 LINT RESULT: {final_status}\n\n" + "\n\n".join(results))


def run_typecheck(arguments: dict, cwd: str) -> dict:
    """Run type checking."""
    framework = arguments.get("framework", "auto")
    path = arguments.get("path", ".")

    log_to_sprint(cwd, f"📝 STARTING TYPECHECK ({framework})...")

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
            return make_response("❌ Could not detect type checker. Specify framework manually.")

    # Run typecheck
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

    final_status = "❌ TYPE ERRORS FOUND" if any_errors else "✅ TYPES OK"
    log_to_sprint(cwd, f"📝 {final_status}")

    return make_response(f"📝 TYPECHECK RESULT: {final_status}\n\n" + "\n\n".join(results))


HANDLERS = {
    "run_tests": run_tests,
    "run_lint": run_lint,
    "run_typecheck": run_typecheck,
}
