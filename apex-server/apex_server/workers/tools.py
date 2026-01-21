"""
Apex Worker Tools - All tools that workers can use

This module defines:
1. File operations (read_file, write_file, list_files, run_command)
2. Delegation tools (assign_* for Chef to delegate to workers)
3. Communication tools (thinking, talk_to, reassign_with_feedback)
4. Meeting tools (team_kickoff, sprint_planning, team_demo, team_retrospective)
5. Testing tools (run_tests)
"""
import subprocess
from pathlib import Path
from typing import Callable, Any

from .config import ROLE_NAMES, ROLE_ICONS

# =============================================================================
# TOOL DEFINITIONS - JSON schemas for LLM tool calling
# =============================================================================

# Worker enum for delegation tools
WORKER_ENUM = ["ad", "architect", "backend", "frontend", "tester", "reviewer", "devops", "security"]

TOOL_DEFINITIONS = [
    # === FILE OPERATIONS ===
    {
        "name": "write_file",
        "description": "Write content to a file. Creates directories if needed.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path (relative to project)"},
                "content": {"type": "string", "description": "Content to write"}
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "read_file",
        "description": "Read a file from the project.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "File path (relative to project)"}
            },
            "required": ["file"]
        }
    },
    {
        "name": "list_files",
        "description": "List all files in the project directory.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Subdirectory to list", "default": "."}
            }
        }
    },
    {
        "name": "run_command",
        "description": "Run a shell command. Allowed: git, ls, cat, echo, mkdir, touch, npm, node, python, pip, pytest, curl",
        "input_schema": {
            "type": "object",
            "properties": {
                "command": {"type": "string", "description": "Command to run"}
            },
            "required": ["command"]
        }
    },

    # === DELEGATION TOOLS (Chef only) ===
    {
        "name": "assign_ad",
        "description": "Assign task to AD (Art Director). Good for design guidelines, UX, colors, typography.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Design task"},
                "context": {"type": "string", "description": "Extra context about the project"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_architect",
        "description": "Assign task to Architect. Good for planning, structure, technical design.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Planning task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_backend",
        "description": "Assign task to Backend developer. Builds API that frontend uses. RUN FIRST!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. main.py)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_frontend",
        "description": "Assign task to Frontend developer. Builds against EXISTING API. Run AFTER backend!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to build?"},
                "file": {"type": "string", "description": "Which file? (e.g. index.html, app.js)"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_tester",
        "description": "Tester WRITES test files (test_*.py). Run BEFORE run_tests()!",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "What to test? E.g. 'Write tests for API endpoints'"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_reviewer",
        "description": "Ask Reviewer to review code.",
        "input_schema": {
            "type": "object",
            "properties": {
                "files_to_review": {"type": "array", "items": {"type": "string"}, "description": "Files to review"},
                "focus": {"type": "string", "description": "What to focus on?"}
            },
            "required": ["files_to_review"]
        }
    },
    {
        "name": "assign_devops",
        "description": "Assign task to DevOps. Good for infra, CI/CD, config, monitoring.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "DevOps task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_security",
        "description": "Security audit - OWASP vulnerabilities, auth, input validation, secrets exposure.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task": {"type": "string", "description": "Security audit task"},
                "context": {"type": "string", "description": "Extra context"}
            },
            "required": ["task"]
        }
    },
    {
        "name": "assign_parallel",
        "description": "Run MULTIPLE workers SIMULTANEOUSLY. Perfect for independent tasks like AD + Architect.",
        "input_schema": {
            "type": "object",
            "properties": {
                "assignments": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "worker": {"type": "string", "enum": WORKER_ENUM, "description": "Which worker"},
                            "task": {"type": "string", "description": "The task"},
                            "context": {"type": "string", "description": "Extra context (optional)"},
                            "file": {"type": "string", "description": "File to work with (optional)"}
                        },
                        "required": ["worker", "task"]
                    },
                    "description": "List of assignments [{worker, task, context?, file?}]"
                }
            },
            "required": ["assignments"]
        }
    },

    # === COMMUNICATION TOOLS ===
    {
        "name": "thinking",
        "description": "Log your thoughts. ALWAYS USE before and after every action!",
        "input_schema": {
            "type": "object",
            "properties": {
                "thought": {"type": "string", "description": "Your thought process"}
            },
            "required": ["thought"]
        }
    },
    {
        "name": "talk_to",
        "description": "Talk freely to a worker. Has MEMORY - continues previous session!",
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "message": {"type": "string"}
            },
            "required": ["worker", "message"]
        }
    },
    {
        "name": "reassign_with_feedback",
        "description": "Send back task with feedback. Worker remembers what they did!",
        "input_schema": {
            "type": "object",
            "properties": {
                "worker": {"type": "string", "enum": WORKER_ENUM},
                "task": {"type": "string"},
                "feedback": {"type": "string"}
            },
            "required": ["worker", "task", "feedback"]
        }
    },

    # === MEETING TOOLS ===
    {
        "name": "team_kickoff",
        "description": "Kickoff meeting: PRESENT the plan to the team.",
        "input_schema": {
            "type": "object",
            "properties": {
                "vision": {"type": "string", "description": "What are we building? Why?"},
                "goals": {"type": "array", "items": {"type": "string"}, "description": "Sprint goals"},
                "plan_summary": {"type": "string", "description": "Summary of architect's plan"}
            },
            "required": ["vision", "goals"]
        }
    },
    {
        "name": "sprint_planning",
        "description": "Start a new sprint with specific features.",
        "input_schema": {
            "type": "object",
            "properties": {
                "sprint_name": {"type": "string", "description": "Sprint name, e.g. 'Sprint 1: Setup'"},
                "features": {"type": "array", "items": {"type": "string"}, "description": "Features to build"}
            },
            "required": ["sprint_name", "features"]
        }
    },
    {
        "name": "team_demo",
        "description": "Demo meeting: Show what was built.",
        "input_schema": {
            "type": "object",
            "properties": {
                "what_was_built": {"type": "string", "description": "Short description of what was built"},
                "files_created": {"type": "array", "items": {"type": "string"}, "description": "List of files created"}
            },
            "required": ["what_was_built"]
        }
    },
    {
        "name": "team_retrospective",
        "description": "Retrospective: Reflect on the sprint.",
        "input_schema": {
            "type": "object",
            "properties": {
                "went_well": {"type": "array", "items": {"type": "string"}, "description": "What went well?"},
                "could_improve": {"type": "array", "items": {"type": "string"}, "description": "What could improve?"},
                "learnings": {"type": "string", "description": "What did we learn?"},
                "live_url": {"type": "string", "description": "URL to live app (if deployed)"}
            },
            "required": ["went_well", "could_improve"]
        }
    },

    # === TESTING TOOLS ===
    {
        "name": "run_tests",
        "description": "RUN existing tests (pytest, npm test). Use assign_tester() FIRST to WRITE tests!",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "pytest", "npm", "bun", "go"],
                    "description": "Test framework (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to test"},
                "verbose": {"type": "boolean", "description": "Show detailed output"}
            }
        }
    },

    # === TESTING & QA TOOLS ===
    {
        "name": "run_lint",
        "description": "Run linting for code quality (ruff, flake8, eslint).",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "ruff", "flake8", "eslint", "prettier"],
                    "description": "Lint tool (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to lint"},
                "fix": {"type": "boolean", "description": "Try to fix automatically"}
            }
        }
    },
    {
        "name": "run_typecheck",
        "description": "Run type checking (mypy, pyright, tsc).",
        "input_schema": {
            "type": "object",
            "properties": {
                "framework": {
                    "type": "string",
                    "enum": ["auto", "mypy", "pyright", "tsc"],
                    "description": "Type checker (auto = detect automatically)"
                },
                "path": {"type": "string", "description": "Specific file/folder to check"}
            }
        }
    },
    {
        "name": "run_qa",
        "description": "Run full QA: tests + lint + typecheck.",
        "input_schema": {
            "type": "object",
            "properties": {
                "focus": {"type": "string", "description": "What to focus on"}
            }
        }
    },

    # === DEPLOY TOOLS ===
    {
        "name": "check_railway_status",
        "description": "Check Railway deployment status.",
        "input_schema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "deploy_railway",
        "description": "Deploy the project to Railway.",
        "input_schema": {
            "type": "object",
            "properties": {
                "with_database": {
                    "type": "string",
                    "enum": ["none", "postgres", "mongo"],
                    "description": "Add database service"
                }
            }
        }
    },
    {
        "name": "create_deploy_files",
        "description": "Create Dockerfile, railway.toml, Procfile, requirements.txt from templates.",
        "input_schema": {
            "type": "object",
            "properties": {
                "db": {
                    "type": "string",
                    "enum": ["none", "postgres", "mongo", "sqlite"],
                    "description": "Database type"
                },
                "extra_deps": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Extra pip dependencies"
                }
            }
        }
    },
    {
        "name": "start_dev_server",
        "description": "Start development server (uvicorn on localhost:8000).",
        "input_schema": {
            "type": "object",
            "properties": {
                "port": {"type": "integer", "description": "Port (default 8000)"}
            }
        }
    },
    {
        "name": "stop_dev_server",
        "description": "Stop the development server.",
        "input_schema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "open_browser",
        "description": "Open an HTML file in the browser.",
        "input_schema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "File to open (default: index.html)"}
            }
        }
    },

    # === BOSS/DECISION TOOLS ===
    {
        "name": "log_decision",
        "description": "Document an important decision for future reference.",
        "input_schema": {
            "type": "object",
            "properties": {
                "decision": {"type": "string", "description": "What was decided?"},
                "reason": {"type": "string", "description": "Why?"}
            },
            "required": ["decision", "reason"]
        }
    },
    {
        "name": "get_decisions",
        "description": "Get logged decisions for the project.",
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "description": "Max number to show (default 10)"}
            }
        }
    },
    {
        "name": "summarize_progress",
        "description": "Summarize the project's progress - files, decisions, status.",
        "input_schema": {
            "type": "object",
            "properties": {}
        }
    },
]


# =============================================================================
# TOOL IMPLEMENTATIONS
# =============================================================================

ALLOWED_COMMANDS = ["git", "ls", "cat", "echo", "mkdir", "touch", "npm", "node", "python", "pip", "pytest", "curl", "railway"]

# Directories to ignore when listing files
IGNORE_DIRS = {
    "__pycache__", "node_modules", ".git", ".venv", "venv",
    ".pytest_cache", ".mypy_cache", ".ruff_cache",
    "build", "dist", ".egg-info", ".tox", ".nox",
    ".idea", ".vscode", ".DS_Store"
}


def write_file(base_path: Path, args: dict) -> str:
    """Write content to a file."""
    path = args.get("path", "")
    content = args.get("content", "")

    full_path = base_path / path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)

    return f"Wrote {len(content)} bytes to {path}"


def read_file(base_path: Path, args: dict) -> str:
    """Read a file."""
    file = args.get("file", "")
    full_path = base_path / file

    if full_path.exists() and full_path.is_file():
        try:
            content = full_path.read_text()
            if len(content) > 5000:
                content = content[:5000] + f"\n\n... (truncated, {len(content)} chars total)"
            return f"📄 {file}:\n\n```\n{content}\n```"
        except Exception as e:
            return f"Error reading {file}: {e}"
    else:
        available = [
            str(f.relative_to(base_path)) for f in base_path.rglob("*")
            if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f)
        ]
        return f"Error: File '{file}' not found.\n\nAvailable files:\n" + "\n".join(f"  - {f}" for f in available[:20])


def list_files(base_path: Path, args: dict) -> str:
    """List files in project directory."""
    path = args.get("path", ".")
    target = base_path / path

    if not target.exists():
        return f"Error: Directory not found: {path}"

    files = []
    max_files = 100

    for f in target.rglob("*"):
        if any(ignored in f.parts for ignored in IGNORE_DIRS):
            continue

        if f.is_file() and not f.name.startswith("."):
            rel_path = str(f.relative_to(base_path))
            size = f.stat().st_size
            size_str = f"{size} B" if size < 1024 else f"{size//1024} KB"
            files.append((rel_path, size_str))

            if len(files) >= max_files:
                break

    if files:
        files.sort(key=lambda x: x[0])
        file_list = "\n".join(f"  {f[0]} ({f[1]})" for f in files)
        truncated = f"\n\n⚠️ Showing max {max_files} files." if len(files) >= max_files else ""
        return f"📁 Files ({len(files)}):\n\n{file_list}{truncated}"
    else:
        return "📁 No files in project yet."


def run_command(base_path: Path, args: dict) -> str:
    """Run a shell command."""
    command = args.get("command", "")
    cmd_start = command.split()[0] if command.split() else ""

    if cmd_start not in ALLOWED_COMMANDS:
        return f"Error: Command not allowed: {cmd_start}. Allowed: {ALLOWED_COMMANDS}"

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=base_path,
            capture_output=True,
            timeout=60,
            text=True
        )
        output = result.stdout + result.stderr
        return f"$ {command}\n{output}" if output else f"$ {command}\n(no output)"
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except Exception as e:
        return f"Error: {e}"


def thinking(base_path: Path, args: dict) -> str:
    """Log a thought."""
    thought = args.get("thought", "")
    return f"💭 {thought}"


def team_kickoff(base_path: Path, args: dict) -> str:
    """Team kickoff meeting."""
    vision = args.get("vision", "")
    goals = args.get("goals", [])
    plan_summary = args.get("plan_summary", "")

    # Read PLAN.md if exists
    plan_file = base_path / "PLAN.md"
    plan = plan_file.read_text()[:500] if plan_file.exists() else plan_summary

    goals_str = "\n".join(f"  {i+1}. {g}" for i, g in enumerate(goals))

    return f"""🚀 KICKOFF

Vision: {vision}

Goals:
{goals_str}

{f'Plan: {plan}...' if plan else ''}

Team is informed and ready!"""


def sprint_planning(base_path: Path, args: dict) -> str:
    """Sprint planning meeting."""
    sprint_name = args.get("sprint_name", "Sprint 1")
    features = args.get("features", [])

    features_str = "\n".join(f"  - {f}" for f in features)

    return f"""📋 SPRINT PLANNING: {sprint_name}

Features:
{features_str}

Let's build this!"""


def team_demo(base_path: Path, args: dict) -> str:
    """Team demo meeting."""
    what_was_built = args.get("what_was_built", "")
    files_created = args.get("files_created", [])

    # List actual files if not provided
    if not files_created:
        files_created = [
            str(f.relative_to(base_path)) for f in base_path.rglob("*")
            if f.is_file() and not f.name.startswith(".")
            and "__pycache__" not in str(f) and "node_modules" not in str(f)
            and "venv" not in str(f)
        ][:15]

    return f"""🎯 DEMO

Built: {what_was_built}

Files ({len(files_created)}):
{chr(10).join(f'  • {f}' for f in files_created)}"""


def team_retrospective(base_path: Path, args: dict) -> str:
    """Team retrospective."""
    went_well = args.get("went_well", [])
    could_improve = args.get("could_improve", [])
    learnings = args.get("learnings", "")
    live_url = args.get("live_url", "")

    well_str = "\n".join(f"  ✅ {item}" for item in went_well)
    improve_str = "\n".join(f"  🔧 {item}" for item in could_improve)

    result = f"""🔄 RETROSPECTIVE

What went well:
{well_str}

What could improve:
{improve_str}
"""
    if learnings:
        result += f"\nLearning: {learnings}\n"
    if live_url:
        result += f"\n🌐 Live: {live_url}\n"

    # Save to file
    retro_file = base_path / "RETROSPECTIVE.md"
    retro_file.write_text(result)

    return result + "\n✅ Saved to RETROSPECTIVE.md"


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


def check_railway_status(base_path: Path, args: dict) -> str:
    """Check Railway deployment status."""
    try:
        result = subprocess.run(
            ["railway", "status"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=base_path
        )
        output = result.stdout + result.stderr
        return f"🚂 Railway Status:\n{output}"
    except Exception as e:
        return f"❌ Error checking Railway: {e}"


# Dev server process reference (for start/stop)
_dev_server_process = None


def start_dev_server(base_path: Path, args: dict) -> str:
    """Start development server."""
    global _dev_server_process

    if _dev_server_process and _dev_server_process.poll() is None:
        return "⚠️ Dev server already running"

    try:
        _dev_server_process = subprocess.Popen(
            ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"],
            cwd=base_path,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        return "🚀 Dev server started at http://localhost:8000"
    except Exception as e:
        return f"❌ Error starting dev server: {e}"


def stop_dev_server(base_path: Path, args: dict) -> str:
    """Stop development server."""
    global _dev_server_process

    if _dev_server_process:
        _dev_server_process.terminate()
        _dev_server_process = None
        return "🛑 Dev server stopped"
    else:
        return "⚠️ No dev server running"


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


def deploy_railway(base_path: Path, args: dict) -> str:
    """Deploy to Railway."""
    with_db = args.get("with_database", "none")
    project_name = base_path.name

    results = []

    # Railway init + up
    for cmd_name, cmd in [
        ("init", ["railway", "init", "--name", project_name]),
        ("up", ["railway", "up", "--detach"])
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=180, cwd=base_path, input="y\n")
            results.append(f"{cmd_name}: {r.stdout or r.stderr or 'OK'}")
        except Exception as e:
            results.append(f"{cmd_name}: {e}")

    # Database if requested
    if with_db != "none":
        try:
            r = subprocess.run(["railway", "add", "--database", with_db],
                             capture_output=True, text=True, timeout=30, cwd=base_path)
            results.append(f"db: {r.stdout or r.stderr}")
        except Exception as e:
            results.append(f"db: {e}")

    return "🚀 Deploy:\n" + "\n".join(results)


# Deploy file templates
DOCKERFILE_TEMPLATE = """FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
"""

RAILWAY_TOML_TEMPLATE = """[build]
builder = "nixpacks"

[deploy]
startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT"
healthcheckPath = "/"
restartPolicyType = "on_failure"
"""

PROCFILE_TEMPLATE = """web: uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
"""

REQUIREMENTS_BASE = ["fastapi", "uvicorn[standard]", "python-multipart", "jinja2"]
REQUIREMENTS_DB = {
    "none": [],
    "sqlite": ["aiosqlite"],
    "postgres": ["sqlalchemy", "psycopg2-binary", "asyncpg"],
    "mongo": ["motor", "pymongo"],
}


def create_deploy_files(base_path: Path, args: dict) -> str:
    """Create standard deploy files from templates."""
    db = args.get("db", "none")
    extra_deps = args.get("extra_deps", [])

    created = []

    # Dockerfile
    dockerfile = base_path / "Dockerfile"
    if not dockerfile.exists():
        dockerfile.write_text(DOCKERFILE_TEMPLATE)
        created.append("Dockerfile")

    # railway.toml
    railway_toml = base_path / "railway.toml"
    if not railway_toml.exists():
        railway_toml.write_text(RAILWAY_TOML_TEMPLATE)
        created.append("railway.toml")

    # Procfile
    procfile = base_path / "Procfile"
    if not procfile.exists():
        procfile.write_text(PROCFILE_TEMPLATE)
        created.append("Procfile")

    # requirements.txt
    requirements = base_path / "requirements.txt"
    if not requirements.exists():
        deps = REQUIREMENTS_BASE + REQUIREMENTS_DB.get(db, []) + extra_deps
        deps.extend(["pytest", "httpx"])  # For testing
        requirements.write_text("\n".join(sorted(set(deps))) + "\n")
        created.append("requirements.txt")

    if created:
        return f"✅ Created deploy files:\n- " + "\n- ".join(created)
    else:
        return "ℹ️ All deploy files already exist"


def open_browser(base_path: Path, args: dict) -> str:
    """Open file in browser."""
    file = args.get("file", "index.html")
    file_path = base_path / file

    if not file_path.exists():
        file_path = base_path / "static" / file

    if file_path.exists():
        subprocess.run(["open", str(file_path)])
        return f"🌐 Opened {file}"
    return f"❌ Could not find {file}"


import json
from datetime import datetime

def _get_decisions_file(base_path: Path) -> Path:
    """Get path to decisions file."""
    return base_path / ".apex_decisions.json"


def _load_decisions(base_path: Path) -> list:
    """Load decisions from file."""
    decisions_file = _get_decisions_file(base_path)
    if decisions_file.exists():
        try:
            return json.load(open(decisions_file))
        except:
            return []
    return []


def _save_decisions(base_path: Path, decisions: list):
    """Save decisions to file."""
    with open(_get_decisions_file(base_path), "w") as f:
        json.dump(decisions, f, indent=2, ensure_ascii=False)


def log_decision(base_path: Path, args: dict) -> str:
    """Log a decision."""
    decision = args.get("decision", "")
    reason = args.get("reason", "")
    timestamp = datetime.now().isoformat()

    decisions = _load_decisions(base_path)
    decisions.append({"timestamp": timestamp, "decision": decision, "reason": reason})
    _save_decisions(base_path, decisions)

    return f"📝 Decision logged: {decision}\nReason: {reason}"


def get_decisions(base_path: Path, args: dict) -> str:
    """Get logged decisions."""
    limit = args.get("limit", 10)
    decisions = _load_decisions(base_path)

    if not decisions:
        return "No decisions logged yet."

    recent = decisions[-limit:][::-1]
    lines = [f"📝 Decisions ({len(recent)} of {len(decisions)}):\n"]
    for d in recent:
        lines.append(f"• [{d['timestamp'][:10]}] {d['decision']}")

    return "\n".join(lines)


def summarize_progress(base_path: Path, args: dict) -> str:
    """Summarize progress."""
    # Count files
    files = [f for f in base_path.rglob("*") if f.is_file()
             and not any(x in f.parts for x in IGNORE_DIRS)
             and not f.name.startswith(".")]

    decisions = _load_decisions(base_path)

    summary = [
        f"📊 Progress Summary:",
        f"• Files: {len(files)}",
        f"• Decisions: {len(decisions)}"
    ]

    # Recent decisions
    if decisions:
        summary.append("• Recent decisions:")
        for d in decisions[-3:]:
            summary.append(f"  - {d['decision'][:50]}")

    # Key files
    key_files = ["main.py", "index.html", "app.js", "style.css", "requirements.txt"]
    existing = [f for f in key_files if (base_path / f).exists()]
    if existing:
        summary.append(f"• Key files: {', '.join(existing)}")

    return "\n".join(summary)


# =============================================================================
# TOOL REGISTRY
# =============================================================================

# Map tool names to their handler functions
# Note: Delegation tools (assign_*) are handled specially by SprintRunner
# because they need to call run_worker recursively
TOOL_HANDLERS: dict[str, Callable[[Path, dict], str]] = {
    # File operations
    "write_file": write_file,
    "read_file": read_file,
    "list_files": list_files,
    "run_command": run_command,

    # Communication
    "thinking": thinking,

    # Meetings
    "team_kickoff": team_kickoff,
    "sprint_planning": sprint_planning,
    "team_demo": team_demo,
    "team_retrospective": team_retrospective,

    # Testing & QA
    "run_tests": run_tests,
    "run_lint": run_lint,
    "run_typecheck": run_typecheck,
    "run_qa": run_qa,

    # Deploy
    "check_railway_status": check_railway_status,
    "deploy_railway": deploy_railway,
    "create_deploy_files": create_deploy_files,
    "start_dev_server": start_dev_server,
    "stop_dev_server": stop_dev_server,
    "open_browser": open_browser,

    # Boss/Decision tools
    "log_decision": log_decision,
    "get_decisions": get_decisions,
    "summarize_progress": summarize_progress,
}

# Delegation tools - these need special handling in SprintRunner
DELEGATION_TOOLS = {
    "assign_ad", "assign_architect", "assign_backend", "assign_frontend",
    "assign_tester", "assign_reviewer", "assign_devops", "assign_security",
    "assign_parallel", "talk_to", "reassign_with_feedback"
}


def execute_tool(base_path: Path, name: str, args: dict) -> str:
    """Execute a tool by name.

    Args:
        base_path: Project directory path
        name: Tool name
        args: Tool arguments

    Returns:
        Tool result as string
    """
    if name in DELEGATION_TOOLS:
        return f"⚠️ Delegation tool '{name}' must be handled by SprintRunner"

    handler = TOOL_HANDLERS.get(name)
    if handler:
        return handler(base_path, args)
    else:
        return f"❌ Unknown tool: {name}"


def get_tools_for_worker(worker: str) -> list[dict]:
    """Get tool definitions appropriate for a worker role.

    Chef gets all tools including delegation.
    Other workers get only file operations and communication.
    """
    if worker == "chef":
        return TOOL_DEFINITIONS
    else:
        # Workers only get file ops, thinking, and testing
        worker_tools = [
            "write_file", "read_file", "list_files", "run_command",
            "thinking", "run_tests"
        ]
        return [t for t in TOOL_DEFINITIONS if t["name"] in worker_tools]
