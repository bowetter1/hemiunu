"""
Deploy tools - deploy_railway, check_railway_status, run_qa, open_browser, start_dev_server, stop_dev_server

REMOVED: ask_user() with JSON-polling - unnecessarily complex
"""
import subprocess
import os
import signal
import time
from pathlib import Path

from core.config import get_worker_cli
from .base import run_cli, make_response, log_to_sprint

# Track dev server process
_dev_server_process = None


TOOLS = [
    {
        "name": "run_qa",
        "description": "Run QA analysis on the project.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "focus": {"type": "string", "description": "What should be analyzed?"}
            },
            "required": []
        }
    },
    {
        "name": "deploy_railway",
        "description": "Deploy the project to Railway.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "with_database": {"type": "string", "enum": ["none", "postgres", "mongo"]}
            },
            "required": []
        }
    },
    {
        "name": "check_railway_status",
        "description": "Check Railway deployment status.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "open_browser",
        "description": "Open an HTML file in the browser.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "File to open"}
            },
            "required": []
        }
    },
    {
        "name": "start_dev_server",
        "description": "Start uvicorn dev server on port 8000. Auto-kills any existing process on that port first.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "port": {"type": "integer", "description": "Port (default 8000)"}
            },
            "required": []
        }
    },
    {
        "name": "stop_dev_server",
        "description": "Stop the dev server.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "create_deploy_files",
        "description": "Create standard deploy files (Dockerfile, railway.toml, Procfile, requirements.txt) from templates. Use db='postgres', 'mongo', or 'sqlite' for database support.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "db": {"type": "string", "enum": ["none", "postgres", "mongo", "sqlite"], "description": "Database type"},
                "extra_deps": {"type": "array", "items": {"type": "string"}, "description": "Extra pip dependencies"}
            },
            "required": []
        }
    },
]


def run_qa(arguments: dict, cwd: str) -> dict:
    """Run QA analysis."""
    focus = arguments.get("focus", "full analysis")
    cli = get_worker_cli("tester")

    prompt = f"Analyze the project. Focus: {focus}. Respond with PASS/FAIL and any issues."
    result = run_cli(cli, prompt, cwd)
    return make_response(f"🧪 QA: {result}")


def deploy_railway(arguments: dict, cwd: str) -> dict:
    """Deploy to Railway."""
    with_db = arguments.get("with_database", "none")
    project_name = Path(cwd).name

    log_to_sprint(cwd, f"🚀 DEPLOY {project_name}...")
    results = []

    # Railway init + up
    for cmd_name, cmd in [
        ("init", ["railway", "init", "--name", project_name]),
        ("up", ["railway", "up", "--detach"])
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=180, cwd=cwd, input="y\n")
            results.append(f"{cmd_name}: {r.stdout or r.stderr or 'OK'}")
        except Exception as e:
            results.append(f"{cmd_name}: {e}")

    # Database if requested
    if with_db != "none":
        try:
            r = subprocess.run(["railway", "add", "--database", with_db],
                             capture_output=True, text=True, timeout=30, cwd=cwd)
            results.append(f"db: {r.stdout or r.stderr}")
        except Exception as e:
            results.append(f"db: {e}")

    return make_response("🚀 Deploy:\n" + "\n".join(results))


def check_railway_status(arguments: dict, cwd: str) -> dict:
    """Check Railway status."""
    results = []

    for cmd_name, cmd in [
        ("status", ["railway", "status"]),
        ("logs", ["railway", "logs", "--limit", "10"]),
        ("domain", ["railway", "domain"])
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=cwd)
            results.append(f"{cmd_name}: {r.stdout or r.stderr or '(empty)'}")
        except Exception as e:
            results.append(f"{cmd_name}: {e}")

    return make_response("\n".join(results))


def open_browser(arguments: dict, cwd: str) -> dict:
    """Open file in browser."""
    file = arguments.get("file", "index.html")
    file_path = Path(cwd) / file

    if not file_path.exists():
        file_path = Path(cwd) / "static" / file

    if file_path.exists():
        subprocess.run(["open", str(file_path)])
        return make_response(f"🌐 Opened {file}")
    return make_response(f"❌ Could not find {file}")


def _kill_port(port: int) -> list[int]:
    """Kill any process using the specified port. Returns list of killed PIDs."""
    killed = []
    try:
        # Find processes using the port (macOS/Linux)
        result = subprocess.run(
            ["lsof", "-ti", f":{port}"],
            capture_output=True, text=True, timeout=5
        )
        if result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                try:
                    os.kill(int(pid), signal.SIGTERM)
                    killed.append(int(pid))
                except (ValueError, ProcessLookupError):
                    pass
            # Give processes time to die
            time.sleep(0.5)
    except Exception:
        pass
    return killed


def start_dev_server(arguments: dict, cwd: str) -> dict:
    """Start uvicorn dev server with port cleanup."""
    global _dev_server_process
    port = arguments.get("port", 8000)

    log_to_sprint(cwd, f"🚀 Starting dev server on port {port}...")

    # Kill any existing process on the port
    killed = _kill_port(port)
    if killed:
        log_to_sprint(cwd, f"   ↳ Killed old processes: {killed}")

    # Also stop our tracked process if any
    if _dev_server_process:
        try:
            _dev_server_process.terminate()
            _dev_server_process.wait(timeout=2)
        except Exception:
            pass
        _dev_server_process = None

    # Check if main.py exists
    main_file = Path(cwd) / "main.py"
    if not main_file.exists():
        return make_response(f"❌ No main.py found in {cwd}")

    # Start uvicorn
    try:
        _dev_server_process = subprocess.Popen(
            ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", str(port), "--reload"],
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        # Wait a bit for server to start
        time.sleep(2)

        # Check if it's running
        if _dev_server_process.poll() is None:
            log_to_sprint(cwd, f"✅ Dev server running at http://localhost:{port}")
            return make_response(f"✅ Dev server started at http://localhost:{port}\n\nPID: {_dev_server_process.pid}")
        else:
            stderr = _dev_server_process.stderr.read().decode() if _dev_server_process.stderr else ""
            return make_response(f"❌ Server failed to start:\n{stderr}")

    except FileNotFoundError:
        return make_response("❌ uvicorn not found. Install with: pip install uvicorn")
    except Exception as e:
        return make_response(f"❌ Error starting server: {e}")


def stop_dev_server(arguments: dict, cwd: str) -> dict:
    """Stop the dev server."""
    global _dev_server_process
    port = 8000

    log_to_sprint(cwd, "🛑 Stopping dev server...")

    stopped = []

    # Stop our tracked process
    if _dev_server_process:
        try:
            _dev_server_process.terminate()
            _dev_server_process.wait(timeout=2)
            stopped.append(_dev_server_process.pid)
        except Exception:
            pass
        _dev_server_process = None

    # Also kill any process on port 8000 (cleanup)
    killed = _kill_port(port)
    stopped.extend(killed)

    if stopped:
        log_to_sprint(cwd, f"✅ Stopped processes: {stopped}")
        return make_response(f"✅ Dev server stopped (PIDs: {stopped})")
    else:
        return make_response("✅ No dev server was running")


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

# Base dependencies for each database type
REQUIREMENTS_BASE = ["fastapi", "uvicorn[standard]", "python-multipart", "jinja2"]
REQUIREMENTS_DB = {
    "none": [],
    "sqlite": ["aiosqlite"],
    "postgres": ["sqlalchemy", "psycopg2-binary", "asyncpg"],
    "mongo": ["motor", "pymongo"],
}


def create_deploy_files(arguments: dict, cwd: str) -> dict:
    """Create standard deploy files from templates."""
    db = arguments.get("db", "none")
    extra_deps = arguments.get("extra_deps", [])

    log_to_sprint(cwd, f"📦 Creating deploy files (db={db})...")

    created = []
    project_path = Path(cwd)

    # Dockerfile
    dockerfile = project_path / "Dockerfile"
    if not dockerfile.exists():
        dockerfile.write_text(DOCKERFILE_TEMPLATE)
        created.append("Dockerfile")

    # railway.toml
    railway_toml = project_path / "railway.toml"
    if not railway_toml.exists():
        railway_toml.write_text(RAILWAY_TOML_TEMPLATE)
        created.append("railway.toml")

    # Procfile
    procfile = project_path / "Procfile"
    if not procfile.exists():
        procfile.write_text(PROCFILE_TEMPLATE)
        created.append("Procfile")

    # requirements.txt
    requirements = project_path / "requirements.txt"
    if not requirements.exists():
        deps = REQUIREMENTS_BASE + REQUIREMENTS_DB.get(db, []) + extra_deps
        # Add pytest for testing
        deps.append("pytest")
        deps.append("httpx")  # For TestClient
        requirements.write_text("\n".join(sorted(set(deps))) + "\n")
        created.append("requirements.txt")

    # .env.example
    env_example = project_path / ".env.example"
    if not env_example.exists():
        env_content = "# Environment variables\n"
        if db == "postgres":
            env_content += "DATABASE_URL=postgresql://user:pass@localhost:5432/dbname\n"
        elif db == "mongo":
            env_content += "MONGODB_URL=mongodb://localhost:27017/dbname\n"
        env_example.write_text(env_content)
        created.append(".env.example")

    if created:
        log_to_sprint(cwd, f"✅ Created: {', '.join(created)}")
        return make_response(f"✅ Created deploy files:\n- " + "\n- ".join(created))
    else:
        return make_response("ℹ️ All deploy files already exist")


HANDLERS = {
    "run_qa": run_qa,
    "deploy_railway": deploy_railway,
    "check_railway_status": check_railway_status,
    "open_browser": open_browser,
    "start_dev_server": start_dev_server,
    "stop_dev_server": stop_dev_server,
    "create_deploy_files": create_deploy_files,
}
