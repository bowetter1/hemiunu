"""Deploy tools - Railway, dev server, deploy files"""
import subprocess
from pathlib import Path

# Dev server process reference
_dev_server_process = None


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
        deps.extend(["pytest", "httpx"])
        requirements.write_text("\n".join(sorted(set(deps))) + "\n")
        created.append("requirements.txt")

    if created:
        return f"✅ Created deploy files:\n- " + "\n- ".join(created)
    else:
        return "ℹ️ All deploy files already exist"
