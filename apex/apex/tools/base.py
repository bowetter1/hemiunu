"""
Base utilities for Apex tools.
"""
import subprocess
import os
import re
from datetime import datetime

from core.config import CLI_FLAGS


# === SESSION TRACKING ===
# Spårar session-ID per worker för att behålla minne
WORKER_SESSIONS = {}


def get_session(worker: str) -> str | None:
    """Hämta session-ID för en worker."""
    return WORKER_SESSIONS.get(worker)


def set_session(worker: str, session_id: str):
    """Spara session-ID för en worker."""
    WORKER_SESSIONS[worker] = session_id


def clear_sessions():
    """Rensa alla sessions (ny sprint)."""
    WORKER_SESSIONS.clear()


def _extract_session_id(output: str, cli: str) -> str | None:
    """Extrahera session-ID från CLI-output."""
    # Claude: letar efter UUID-format i output
    # Typiskt format: Session: abc12345-1234-5678-abcd-ef1234567890
    uuid_pattern = r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}'
    matches = re.findall(uuid_pattern, output, re.IGNORECASE)
    if matches:
        return matches[-1]  # Ta sista (mest sannolikt session-ID)
    return None


# === FEEDBACK ===
WORKER_FEEDBACK_PROMPT = "\n\nVIKTIGT: Säg ifrån om uppdraget är oklart eller om du har en bättre idé."


def log_to_sprint(cwd: str, message: str):
    """Logga till sprint.log i projektmappen."""
    try:
        log_file = os.path.join(cwd, "sprint.log")
        timestamp = datetime.now().strftime("%H:%M:%S")
        with open(log_file, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
            f.flush()
    except:
        pass


def run_cli(cli: str, prompt: str, cwd: str, worker: str = None, continue_session: bool = False) -> str:
    """Kör en CLI och returnera output.

    Args:
        cli: Vilken CLI (qwen, claude, gemini)
        prompt: Prompten att skicka
        cwd: Working directory
        worker: Worker-namn för session-tracking (t.ex. "backend", "frontend")
        continue_session: Om True, fortsätt tidigare session (minne!)
    """
    # Kolla om vi har en sparad session för denna worker
    session_id = get_session(worker) if worker else None

    if session_id:
        session_info = f" (fortsätter {worker} session)"
    elif continue_session:
        session_info = " (--continue)"
    else:
        session_info = ""

    log_to_sprint(cwd, f"▶️ STARTAR {cli.upper()}{session_info}...")

    # Bygg kommando baserat på CLI
    if cli == "claude":
        cmd = ["claude", "-p", prompt, "--dangerously-skip-permissions"]
        if session_id:
            cmd.extend(["--resume", session_id])
        elif continue_session:
            cmd.append("--continue")
    elif cli == "sonnet":
        cmd = ["claude", "-p", prompt, "--dangerously-skip-permissions", "--model", "sonnet"]
        if session_id:
            cmd.extend(["--resume", session_id])
        elif continue_session:
            cmd.append("--continue")
    elif cli == "gemini":
        cmd = ["gemini", "-y"]
        if session_id:
            cmd.extend(["-r", session_id])
        elif continue_session:
            cmd.extend(["-r", "latest"])
        cmd.append(prompt)
    else:
        # Fallback för okänd CLI
        cmd = [cli, prompt]

    try:
        r = subprocess.run(
            cmd,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=240,
            cwd=cwd
        )
        output = r.stdout.strip() or "(ingen output)"

        # Försök extrahera och spara session-ID för workern
        if worker:
            new_session_id = _extract_session_id(output, cli)
            if new_session_id:
                set_session(worker, new_session_id)
                log_to_sprint(cwd, f"💾 Sparade session för {worker}: {new_session_id[:8]}...")

        log_to_sprint(cwd, f"✅ {cli.upper()} klar ({len(output)} tecken)")
        return output
    except subprocess.TimeoutExpired:
        log_to_sprint(cwd, f"⏰ {cli.upper()} timeout (4 min)")
        return "ERROR: Timeout efter 5 minuter"
    except FileNotFoundError:
        log_to_sprint(cwd, f"❌ {cli.upper()} hittades inte")
        return f"ERROR: CLI '{cli}' är inte installerad"
    except Exception as e:
        log_to_sprint(cwd, f"❌ {cli.upper()} fel: {e}")
        return f"ERROR: {e}"


def timestamp() -> str:
    """Returnera nuvarande tid som sträng."""
    return datetime.now().strftime("%H:%M:%S")


def make_response(text: str) -> dict:
    """Skapa MCP-response."""
    return {"content": [{"type": "text", "text": text}]}
