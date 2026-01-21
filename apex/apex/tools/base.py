"""
Base utilities for Apex tools.
"""
import subprocess
import os
import re
from datetime import datetime

from core.config import CLI_FLAGS


# === SESSION TRACKING ===
# Tracks session-ID per worker to maintain memory
WORKER_SESSIONS = {}


def get_session(worker: str) -> str | None:
    """Get session-ID for a worker."""
    return WORKER_SESSIONS.get(worker)


def set_session(worker: str, session_id: str):
    """Save session-ID for a worker."""
    WORKER_SESSIONS[worker] = session_id


def clear_sessions():
    """Clear all sessions (new sprint)."""
    WORKER_SESSIONS.clear()


def _extract_session_id(output: str, cli: str) -> str | None:
    """Extract session-ID from CLI output."""
    # Claude: looks for UUID format in output
    # Typical format: Session: abc12345-1234-5678-abcd-ef1234567890
    uuid_pattern = r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}'
    matches = re.findall(uuid_pattern, output, re.IGNORECASE)
    if matches:
        return matches[-1]  # Take last (most likely session-ID)
    return None


# === FEEDBACK ===
WORKER_FEEDBACK_PROMPT = "\n\nIMPORTANT: Speak up if the task is unclear or if you have a better idea."


def log_to_sprint(cwd: str, message: str):
    """Log to sprint.log in project folder."""
    try:
        log_file = os.path.join(cwd, "sprint.log")
        timestamp = datetime.now().strftime("%H:%M:%S")
        with open(log_file, "a") as f:
            f.write(f"[{timestamp}] {message}\n")
            f.flush()
    except:
        pass


def run_cli(cli: str, prompt: str, cwd: str, worker: str = None, continue_session: bool = False) -> str:
    """Run a CLI and return output.

    Args:
        cli: Which CLI (claude, sonnet, gemini)
        prompt: The prompt to send
        cwd: Working directory
        worker: Worker name for session-tracking (e.g. "backend", "frontend")
        continue_session: If True, continue previous session (memory!)
    """
    # Check if we have a saved session for this worker
    session_id = get_session(worker) if worker else None

    if session_id:
        session_info = f" (continuing {worker} session)"
    elif continue_session:
        session_info = " (--continue)"
    else:
        session_info = ""

    log_to_sprint(cwd, f"▶️ STARTING {cli.upper()}{session_info}...")

    # Build command based on CLI
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
        # Fallback for unknown CLI
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
        output = r.stdout.strip() or "(no output)"

        # Try to extract and save session-ID for the worker
        if worker:
            new_session_id = _extract_session_id(output, cli)
            if new_session_id:
                set_session(worker, new_session_id)
                log_to_sprint(cwd, f"💾 Saved session for {worker}: {new_session_id[:8]}...")

        log_to_sprint(cwd, f"✅ {cli.upper()} done ({len(output)} chars)")
        return output
    except subprocess.TimeoutExpired:
        log_to_sprint(cwd, f"⏰ {cli.upper()} timeout (4 min)")
        return "ERROR: Timeout after 5 minutes"
    except FileNotFoundError:
        log_to_sprint(cwd, f"❌ {cli.upper()} not found")
        return f"ERROR: CLI '{cli}' is not installed"
    except Exception as e:
        log_to_sprint(cwd, f"❌ {cli.upper()} error: {e}")
        return f"ERROR: {e}"


def timestamp() -> str:
    """Return current time as string."""
    return datetime.now().strftime("%H:%M:%S")


def make_response(text: str) -> dict:
    """Create MCP response."""
    return {"content": [{"type": "text", "text": text}]}
