"""
Apex Worker Tools

Re-exports all tools from submodules for easy importing:
    from apex_server.workers.tools import TOOL_DEFINITIONS, execute_tool
"""
from pathlib import Path
from typing import Callable

# Import definitions
from .definitions import TOOL_DEFINITIONS, WORKER_ENUM

# Import handlers from each module
from .files import write_file, read_file, list_files, run_command, IGNORE_DIRS
from .testing import run_tests, run_lint, run_typecheck, run_qa
from .deploy import (
    check_railway_status, deploy_railway, create_deploy_files,
    start_dev_server, stop_dev_server, open_browser
)
from .meetings import thinking, team_kickoff, sprint_planning, team_demo, team_retrospective
from .decisions import log_decision, get_decisions, summarize_progress

# =============================================================================
# TOOL REGISTRY
# =============================================================================

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

# Delegation tools - handled specially by SprintRunner
DELEGATION_TOOLS = {
    "assign_ad", "assign_architect", "assign_backend", "assign_frontend",
    "assign_tester", "assign_reviewer", "assign_devops", "assign_security",
    "assign_parallel", "talk_to", "reassign_with_feedback"
}


def execute_tool(base_path: Path, name: str, args: dict) -> str:
    """Execute a tool by name."""
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


# Export all public symbols
__all__ = [
    # Definitions
    "TOOL_DEFINITIONS",
    "WORKER_ENUM",
    # Registry
    "TOOL_HANDLERS",
    "DELEGATION_TOOLS",
    # Functions
    "execute_tool",
    "get_tools_for_worker",
]
