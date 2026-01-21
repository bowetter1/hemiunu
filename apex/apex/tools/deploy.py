"""
Deploy tools - deploy_railway, check_railway_status, run_qa, open_browser

BORTTAGET: ask_user() med JSON-polling - onödigt komplext
"""
import subprocess
from pathlib import Path

from core.config import get_worker_cli
from .base import run_cli, make_response, log_to_sprint


TOOLS = [
    {
        "name": "run_qa",
        "description": "Kör QA-analys på projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "focus": {"type": "string", "description": "Vad ska analyseras?"}
            },
            "required": []
        }
    },
    {
        "name": "deploy_railway",
        "description": "Deploya projektet till Railway.",
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
        "description": "Kolla Railway deployment status.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "open_browser",
        "description": "Öppna en HTML-fil i webbläsaren.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "file": {"type": "string", "description": "Fil att öppna"}
            },
            "required": []
        }
    },
]


def run_qa(arguments: dict, cwd: str) -> dict:
    """Kör QA-analys."""
    focus = arguments.get("focus", "fullständig analys")
    cli = get_worker_cli("tester")

    prompt = f"Analysera projektet. Fokus: {focus}. Svara med PASS/FAIL och eventuella issues."
    result = run_cli(cli, prompt, cwd)
    return make_response(f"🧪 QA: {result}")


def deploy_railway(arguments: dict, cwd: str) -> dict:
    """Deploya till Railway."""
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

    # Databas om begärd
    if with_db != "none":
        try:
            r = subprocess.run(["railway", "add", "--database", with_db],
                             capture_output=True, text=True, timeout=30, cwd=cwd)
            results.append(f"db: {r.stdout or r.stderr}")
        except Exception as e:
            results.append(f"db: {e}")

    return make_response("🚀 Deploy:\n" + "\n".join(results))


def check_railway_status(arguments: dict, cwd: str) -> dict:
    """Kolla Railway status."""
    results = []

    for cmd_name, cmd in [
        ("status", ["railway", "status"]),
        ("logs", ["railway", "logs", "--limit", "10"]),
        ("domain", ["railway", "domain"])
    ]:
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=30, cwd=cwd)
            results.append(f"{cmd_name}: {r.stdout or r.stderr or '(tom)'}")
        except Exception as e:
            results.append(f"{cmd_name}: {e}")

    return make_response("\n".join(results))


def open_browser(arguments: dict, cwd: str) -> dict:
    """Öppna fil i webbläsaren."""
    file = arguments.get("file", "index.html")
    file_path = Path(cwd) / file

    if not file_path.exists():
        file_path = Path(cwd) / "static" / file

    if file_path.exists():
        subprocess.run(["open", str(file_path)])
        return make_response(f"🌐 Öppnade {file}")
    return make_response(f"❌ Hittade inte {file}")


HANDLERS = {
    "run_qa": run_qa,
    "deploy_railway": deploy_railway,
    "check_railway_status": check_railway_status,
    "open_browser": open_browser,
}
