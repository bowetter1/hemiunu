#!/usr/bin/env python3
"""
Apex Web Server - Starta sprints från webbläsaren med live-loggning.
"""
import subprocess
import json
import os
import threading
import queue
import mimetypes
from datetime import datetime
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
import socketserver

from ..core.config import get_web_chef_prompt

# Global event queue för live updates
events = queue.Queue()

# Store för aktiv sprint
active_sprint = {
    "running": False,
    "task": "",
    "project": "",
    "log": []
}

# Static files directory
STATIC_DIR = Path(__file__).parent / "static"


def log_event(event_type: str, message: str, data: dict = None):
    """Logga event till queue, terminal och fil i projektmappen."""
    event = {
        "time": datetime.now().strftime("%H:%M:%S"),
        "type": event_type,
        "message": message,
        "data": data or {}
    }
    active_sprint["log"].append(event)
    events.put(event)

    # Terminal
    print(f"[{event['time']}] {event_type}: {message}")

    # Fil i projektmappen
    if active_sprint.get("project"):
        log_file = Path(active_sprint["project"]) / "sprint.log"
        with open(log_file, "a") as f:
            f.write(f"[{event['time']}] {event_type}: {message}\n")
            if data:
                f.write(f"         data: {json.dumps(data)}\n")


def run_cli(cli: str, prompt: str, cwd: str) -> str:
    """Kör en CLI - MCP för Claude så vi ser tool-anrop."""
    log_event("cli_start", f"Startar {cli.upper()}...", {"cli": cli})

    if cli == "qwen":
        cmd = ["qwen", "-y", prompt]
    elif cli == "claude":
        cmd = ["claude", "--dangerously-skip-permissions", "-p", prompt]
    else:
        cmd = [cli, prompt]

    try:
        env = os.environ.copy()
        env["PROJECT_DIR"] = cwd

        r = subprocess.run(cmd, capture_output=True, text=True, timeout=900, cwd=cwd, env=env)
        output = r.stdout.strip() or "(ingen output)"

        log_event("cli_done", f"{cli.upper()} klar", {"cli": cli, "output_length": len(output)})
        return output

    except subprocess.TimeoutExpired:
        log_event("cli_timeout", f"{cli.upper()} timeout efter 15 min", {"cli": cli})
        return "TIMEOUT: Kommandot tog för lång tid"
    except Exception as e:
        log_event("cli_error", f"{cli.upper()} error: {e}", {"cli": cli})
        return f"ERROR: {e}"


def run_sprint(task: str, project_path: str):
    """Kör en sprint - Opus styr ALLT via bash."""
    active_sprint["running"] = True
    active_sprint["task"] = task
    active_sprint["project"] = project_path
    active_sprint["log"] = []

    cwd = project_path

    # Skapa loggfil i projektmappen
    log_file = Path(project_path) / "sprint.log"
    with open(log_file, "w") as f:
        f.write(f"=== SPRINT START: {task} ===\n")
        f.write(f"=== Projekt: {project_path} ===\n")
        f.write(f"=== Tid: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===\n\n")

    try:
        log_event("meeting", "CEO OPUS TAR KOMMANDO", {"phase": "opus_control"})
        log_event("opus", f"CEO Opus: 'Jag bygger {task} med mitt team!'")

        opus_result = run_cli("claude", get_web_chef_prompt(task, cwd), cwd)
        log_event("opus", f"CEO Opus klar: {opus_result[:500]}...", {"full_result": opus_result})

        # === KLAR ===
        files = list(Path(cwd).rglob("*"))
        files = [f for f in files if f.is_file() and not f.name.startswith(".")]

        log_event("sprint_done", "SPRINT KLAR!", {
            "files": [str(f.name) for f in files],
            "file_count": len(files)
        })

    except Exception as e:
        log_event("sprint_error", f"Sprint error: {e}", {"error": str(e)})

    finally:
        active_sprint["running"] = False


class ApexHandler(SimpleHTTPRequestHandler):
    """HTTP handler för apex."""

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/":
            self.serve_static("index.html")
        elif parsed.path.startswith("/static/"):
            filename = parsed.path[8:]  # Remove "/static/"
            self.serve_static(filename)
        elif parsed.path == "/api/status":
            self.serve_json(active_sprint)
        elif parsed.path.startswith("/api/files"):
            self.serve_files()
        elif parsed.path == "/api/log":
            self.serve_sprint_log()
        elif parsed.path == "/api/question":
            self.serve_question()
        elif parsed.path == "/api/events":
            self.serve_events()
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == "/api/start":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            data = json.loads(post_data)

            task = data.get("task", "")
            if task and not active_sprint["running"]:
                name = "".join(c if c.isalnum() else "-" for c in task.lower())[:30].strip("-")
                project = Path.cwd() / name
                project.mkdir(exist_ok=True)

                thread = threading.Thread(target=run_sprint, args=(task, str(project)))
                thread.start()

                self.serve_json({"status": "started", "project": str(project)})
            else:
                self.serve_json({"status": "error", "message": "Already running or no task"})

        elif parsed.path == "/api/answer":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode('utf-8')
            data = json.loads(post_data)

            answer = data.get("answer", "")
            project = active_sprint.get("project", "")

            if project:
                questions_file = Path(project) / "questions.json"
                if questions_file.exists():
                    try:
                        with open(questions_file, "r") as f:
                            question_data = json.load(f)

                        question_data["answered"] = True
                        question_data["answer"] = answer

                        with open(questions_file, "w") as f:
                            json.dump(question_data, f, ensure_ascii=False, indent=2)

                        self.serve_json({"status": "ok"})
                    except Exception as e:
                        self.serve_json({"status": "error", "message": str(e)})
                else:
                    self.serve_json({"status": "error", "message": "No question file"})
            else:
                self.serve_json({"status": "error", "message": "No active project"})
        else:
            self.send_error(404)

    def serve_static(self, filename: str):
        """Serve a static file."""
        filepath = STATIC_DIR / filename
        if not filepath.exists():
            self.send_error(404)
            return

        content_type, _ = mimetypes.guess_type(str(filepath))
        if content_type is None:
            content_type = 'application/octet-stream'

        self.send_response(200)
        self.send_header('Content-type', content_type)
        self.end_headers()
        self.wfile.write(filepath.read_bytes())

    def serve_json(self, data):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def serve_files(self):
        """Lista filer i projektmappen."""
        project = active_sprint.get("project", "")
        files = []

        if project and Path(project).exists():
            for f in Path(project).rglob("*"):
                if f.is_file() and not f.name.startswith(".") and "node_modules" not in str(f) and "__pycache__" not in str(f) and f.name != "sprint.log":
                    size = f.stat().st_size
                    size_str = f"{size} B" if size < 1024 else f"{size//1024} KB"
                    files.append({
                        "name": str(f.relative_to(project)),
                        "path": str(f),
                        "size": size_str
                    })

        self.serve_json(files)

    def serve_sprint_log(self):
        """Läs sprint.log direkt från fil för live MCP-uppdateringar."""
        project = active_sprint.get("project", "")
        lines = []

        if project:
            log_file = Path(project) / "sprint.log"
            if log_file.exists():
                with open(log_file, "r") as f:
                    lines = f.readlines()

        self.serve_json({"lines": lines, "running": active_sprint["running"]})

    def serve_question(self):
        """Läs questions.json för att se om Opus har en fråga."""
        project = active_sprint.get("project", "")
        question_data = None

        if project:
            questions_file = Path(project) / "questions.json"
            if questions_file.exists():
                try:
                    with open(questions_file, "r") as f:
                        question_data = json.load(f)
                except:
                    pass

        self.serve_json(question_data or {"question": None})

    def serve_events(self):
        """Server-Sent Events för live updates."""
        self.send_response(200)
        self.send_header('Content-type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()

        while True:
            try:
                event = events.get(timeout=30)
                data = json.dumps(event)
                self.wfile.write(f"data: {data}\n\n".encode())
                self.wfile.flush()
            except queue.Empty:
                self.wfile.write(": keepalive\n\n".encode())
                self.wfile.flush()


def main():
    port = 8080

    # Byt till apex root-mappen
    os.chdir(Path(__file__).parent.parent.parent)

    print(f"""
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   APEX WEB SERVER                                             ║
║                                                               ║
║   Öppna i webbläsaren:                                        ║
║   → http://localhost:{port}                                     ║
║                                                               ║
║   Tryck Ctrl+C för att avsluta                                ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
""")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", port), ApexHandler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
