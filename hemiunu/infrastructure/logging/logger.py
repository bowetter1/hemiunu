"""
Agent Logger - Strukturerad loggning för Hemiunu-agenter.
"""
import json
import sys
from datetime import datetime
from enum import IntEnum
from pathlib import Path
from typing import Optional, Any


class LogLevel(IntEnum):
    """Loggningsnivåer."""
    DEBUG = 10
    INFO = 20
    TOOL = 25      # Tool-anrop
    WARN = 30
    ERROR = 40


# ANSI färgkoder
COLORS = {
    LogLevel.DEBUG: "\033[90m",     # Grå
    LogLevel.INFO: "\033[37m",      # Vit
    LogLevel.TOOL: "\033[36m",      # Cyan
    LogLevel.WARN: "\033[33m",      # Gul
    LogLevel.ERROR: "\033[31m",     # Röd
}
RESET = "\033[0m"
BOLD = "\033[1m"

# Roll-färger
ROLE_COLORS = {
    "worker": "\033[32m",      # Grön
    "tester": "\033[35m",      # Magenta
    "vesir": "\033[34m",       # Blå
    "integrator": "\033[33m",  # Gul
    "orchestrator": "\033[37m",# Vit
}

# Global konfiguration
_log_level = LogLevel.INFO
_log_to_file = True
_log_dir = Path("logs")


def set_log_level(level: LogLevel):
    """Sätt global loggningsnivå."""
    global _log_level
    _log_level = level


def set_log_file(enabled: bool, directory: str = "logs"):
    """Aktivera/avaktivera filloggning."""
    global _log_to_file, _log_dir
    _log_to_file = enabled
    _log_dir = Path(directory)


class AgentLogger:
    """
    Logger för en specifik agent-instans.

    Loggar till både konsol (färgad) och JSON-fil.
    """

    def __init__(
        self,
        role: str,
        task_id: str = None,
        session_id: str = None
    ):
        self.role = role.lower()
        self.task_id = task_id
        self.session_id = session_id or datetime.now().strftime("%Y%m%d_%H%M%S")
        self.iteration = 0
        self._file_handle = None

        # Skapa logg-fil om aktiverat
        if _log_to_file:
            self._init_log_file()

    def _init_log_file(self):
        """Initiera JSON-loggfil."""
        _log_dir.mkdir(parents=True, exist_ok=True)
        filename = f"{self.session_id}_{self.role}"
        if self.task_id:
            filename += f"_{self.task_id}"
        filename += ".jsonl"

        self._log_path = _log_dir / filename
        self._file_handle = open(self._log_path, "a", encoding="utf-8")

    def _format_console(self, level: LogLevel, message: str, **context) -> str:
        """Formatera meddelande för konsol."""
        level_color = COLORS.get(level, "")
        role_color = ROLE_COLORS.get(self.role, "\033[37m")

        # Tidsstämpel
        timestamp = datetime.now().strftime("%H:%M:%S")

        # Roll och iteration
        role_tag = f"{role_color}{BOLD}[{self.role.upper()}]{RESET}"

        iter_tag = ""
        if self.iteration > 0:
            iter_tag = f"\033[90m[{self.iteration}]{RESET} "

        # Nivå-prefix för WARN/ERROR
        level_prefix = ""
        if level >= LogLevel.WARN:
            level_name = level.name
            level_prefix = f"{level_color}{level_name}: {RESET}"

        # Kontext
        context_str = ""
        if context:
            ctx_parts = []
            for k, v in context.items():
                if isinstance(v, str) and len(v) > 50:
                    v = v[:50] + "..."
                ctx_parts.append(f"{k}={v}")
            if ctx_parts:
                context_str = f" \033[90m({', '.join(ctx_parts)}){RESET}"

        return f"\033[90m{timestamp}{RESET} {role_tag} {iter_tag}{level_prefix}{level_color}{message}{RESET}{context_str}"

    def _format_json(self, level: LogLevel, message: str, **context) -> dict:
        """Formatera meddelande för JSON-logg."""
        return {
            "timestamp": datetime.now().isoformat(),
            "level": level.name,
            "role": self.role,
            "task_id": self.task_id,
            "session_id": self.session_id,
            "iteration": self.iteration,
            "message": message,
            **context
        }

    def _log(self, level: LogLevel, message: str, **context):
        """Intern loggnings-metod."""
        if level < _log_level:
            return

        # Konsol
        print(self._format_console(level, message, **context))

        # Fil
        if self._file_handle:
            json_entry = self._format_json(level, message, **context)
            self._file_handle.write(json.dumps(json_entry, ensure_ascii=False) + "\n")
            self._file_handle.flush()

    def set_iteration(self, iteration: int):
        """Uppdatera nuvarande iteration."""
        self.iteration = iteration

    def debug(self, message: str, **context):
        """Logga debug-meddelande."""
        self._log(LogLevel.DEBUG, message, **context)

    def info(self, message: str, **context):
        """Logga info-meddelande."""
        self._log(LogLevel.INFO, message, **context)

    def tool(self, tool_name: str, arguments: dict = None, result: dict = None):
        """Logga tool-anrop."""
        context = {"tool": tool_name}
        if arguments:
            # Trunkera långa argument
            truncated = {}
            for k, v in arguments.items():
                if isinstance(v, str) and len(v) > 100:
                    truncated[k] = v[:100] + f"... ({len(v)} chars)"
                else:
                    truncated[k] = v
            context["args"] = truncated
        if result:
            context["result"] = result.get("success", result)

        msg = f"Tool: {tool_name}"
        self._log(LogLevel.TOOL, msg, **context)

    def tool_result(self, tool_name: str, result: dict):
        """Logga tool-resultat."""
        success = result.get("success", True)
        status = "OK" if success else "FAIL"

        context = {"tool": tool_name, "success": success}
        if not success and result.get("error"):
            context["error"] = result["error"][:100]

        self._log(LogLevel.TOOL, f"  -> {status}", **context)

    def warn(self, message: str, **context):
        """Logga varning."""
        self._log(LogLevel.WARN, message, **context)

    def error(self, message: str, **context):
        """Logga fel."""
        self._log(LogLevel.ERROR, message, **context)

    def llm_call(self, model: str, tokens_in: int = None, tokens_out: int = None):
        """Logga LLM-anrop."""
        context = {"model": model}
        if tokens_in:
            context["tokens_in"] = tokens_in
        if tokens_out:
            context["tokens_out"] = tokens_out
        self._log(LogLevel.DEBUG, "LLM call", **context)

    def llm_response(self, stop_reason: str, tool_calls: int = 0):
        """Logga LLM-svar."""
        context = {"stop_reason": stop_reason}
        if tool_calls:
            context["tool_calls"] = tool_calls
        self._log(LogLevel.DEBUG, "LLM response", **context)

    def start(self, description: str = None):
        """Logga att agenten startar."""
        msg = f"Starting task: {self.task_id or 'unknown'}"
        context = {}
        if description:
            context["description"] = description[:60]
        self._log(LogLevel.INFO, msg, **context)

    def complete(self, status: str, **context):
        """Logga att agenten är klar."""
        self._log(LogLevel.INFO, f"Completed: {status}", **context)

    def close(self):
        """Stäng logg-fil."""
        if self._file_handle:
            self._file_handle.close()
            self._file_handle = None


# Logger-cache per roll/task
_loggers: dict[str, AgentLogger] = {}


def get_logger(role: str, task_id: str = None) -> AgentLogger:
    """
    Hämta eller skapa logger för en roll/task.

    Args:
        role: Agent-roll (worker, tester, etc.)
        task_id: Uppgifts-ID (valfritt)

    Returns:
        AgentLogger instans
    """
    key = f"{role}:{task_id or 'global'}"
    if key not in _loggers:
        _loggers[key] = AgentLogger(role, task_id)
    return _loggers[key]
