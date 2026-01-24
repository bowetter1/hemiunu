"""Testing & QA tools - run_tests, run_lint, run_typecheck, run_qa"""
import subprocess
from pathlib import Path


def run_tests(base_path: Path, args: dict) -> str:
    """Run tests."""
    framework = args.get("framework", "auto")
    path = args.get("path", "")
    verbose = args.get("verbose", False)

    # Auto-detect framework
    if framework == "auto":
        if list(base_path.glob("*.py")) or list(base_path.glob("**/*.py")):
            framework = "pytest"
        elif (base_path / "package.json").exists():
            framework = "npm"
        elif (base_path / "go.mod").exists():
            framework = "go"
        else:
            return "❌ Could not detect test framework. Specify framework manually."

    # Run tests
    if framework == "pytest":
        cmd = ["pytest"]
        if verbose:
            cmd.append("-v")
        if path:
            cmd.append(path)
        elif (base_path / "tests").exists():
            cmd.append("tests/")
    elif framework == "npm":
        cmd = ["npm", "test"]
    elif framework == "go":
        cmd = ["go", "test", "./..."]
    else:
        return f"❌ Unknown framework: {framework}"

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=base_path
        )
        output = result.stdout + result.stderr
        success = result.returncode == 0
        status = "✅ PASS" if success else "❌ FAIL"
        return f"🧪 TEST RESULT: {status}\n\n```\n{output[-2000:]}\n```"
    except subprocess.TimeoutExpired:
        return "❌ Tests timed out after 120s"
    except Exception as e:
        return f"❌ Error running tests: {e}"


def run_lint(base_path: Path, args: dict) -> str:
    """Run linting."""
    framework = args.get("framework", "auto")
    path = args.get("path", ".")
    fix = args.get("fix", False)

    # Auto-detect
    if framework == "auto":
        if list(base_path.glob("*.py")) or list(base_path.glob("**/*.py")):
            framework = "ruff"
        elif (base_path / "package.json").exists():
            framework = "eslint"
        else:
            return "❌ Could not detect lint tool. Specify framework manually."

    # Run lint
    if framework == "ruff":
        cmd = ["ruff", "check", path]
        if fix:
            cmd.append("--fix")
    elif framework == "flake8":
        cmd = ["flake8", path]
    elif framework == "eslint":
        cmd = ["npx", "eslint", path]
        if fix:
            cmd.append("--fix")
    elif framework == "prettier":
        cmd = ["npx", "prettier", "--check" if not fix else "--write", path]
    else:
        return f"❌ Unknown lint tool: {framework}"

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60, cwd=base_path)
        output = result.stdout + result.stderr
        success = result.returncode == 0
        status = "✅ CLEAN" if success else "⚠️ ISSUES"
        return f"🔍 LINT ({framework}): {status}\n\n```\n{output[-2000:]}\n```"
    except FileNotFoundError:
        return f"❌ {framework} not found. Install it first."
    except Exception as e:
        return f"❌ Error running lint: {e}"


def run_typecheck(base_path: Path, args: dict) -> str:
    """Run type checking."""
    framework = args.get("framework", "auto")
    path = args.get("path", ".")

    # Auto-detect
    if framework == "auto":
        if list(base_path.glob("*.py")) or list(base_path.glob("**/*.py")):
            framework = "mypy"
        elif (base_path / "package.json").exists():
            framework = "tsc"
        else:
            return "❌ Could not detect type checker. Specify framework manually."

    # Run typecheck
    if framework == "mypy":
        cmd = ["mypy", path]
    elif framework == "pyright":
        cmd = ["pyright", path]
    elif framework == "tsc":
        cmd = ["npx", "tsc", "--noEmit"]
    else:
        return f"❌ Unknown type checker: {framework}"

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120, cwd=base_path)
        output = result.stdout + result.stderr
        success = result.returncode == 0
        status = "✅ CLEAN" if success else "❌ TYPE ERRORS"
        return f"📝 TYPECHECK ({framework}): {status}\n\n```\n{output[-2000:]}\n```"
    except FileNotFoundError:
        return f"❌ {framework} not found. Install it first."
    except Exception as e:
        return f"❌ Error running typecheck: {e}"


def run_qa(base_path: Path, args: dict) -> str:
    """Run full QA suite."""
    results = []

    # Run tests
    test_result = run_tests(base_path, {"framework": "auto"})
    results.append(test_result)

    # Run lint
    lint_result = run_lint(base_path, {"framework": "auto"})
    results.append(lint_result)

    # Run typecheck
    type_result = run_typecheck(base_path, {"framework": "auto"})
    results.append(type_result)

    return "🧪 QA RESULTS:\n\n" + "\n\n---\n\n".join(results)
