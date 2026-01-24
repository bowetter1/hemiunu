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
from .files import write_file, read_file, list_files, run_command, check_needs, IGNORE_DIRS
from .testing import run_tests, run_lint, run_typecheck, run_qa
from .deploy import (
    check_railway_status, deploy_railway, create_deploy_files,
    start_dev_server, stop_dev_server, open_browser
)
from .meetings import thinking, team_kickoff, sprint_planning, team_demo, team_retrospective
from .decisions import log_decision, get_decisions, summarize_progress
from .github import GITHUB_TOOL_DEFINITIONS, execute_github_tool

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

    # Coordination tools
    "check_needs": check_needs,

    # GitHub tools (handled by execute_github_tool)
    "git_init": None,
    "git_commit": None,
    "git_status": None,
    "github_create_repo": None,
    "github_push": None,
}

# GitHub tool names
GITHUB_TOOLS = {"git_init", "git_commit", "git_status", "github_create_repo", "github_push"}

# Delegation tools - handled specially by SprintRunner
DELEGATION_TOOLS = {
    "assign_ad", "assign_architect", "assign_backend", "assign_frontend",
    "assign_tester", "assign_reviewer", "assign_devops", "assign_security",
    "assign_parallel", "talk_to", "reassign_with_feedback", "checkin_worker"
}


def execute_tool(base_path: Path, name: str, args: dict) -> str:
    """Execute a tool by name."""
    if name in DELEGATION_TOOLS:
        return f"⚠️ Delegation tool '{name}' must be handled by SprintRunner"

    # Handle GitHub tools specially
    if name in GITHUB_TOOLS:
        return execute_github_tool(base_path, name, args)

    handler = TOOL_HANDLERS.get(name)
    if handler:
        return handler(base_path, args)
    else:
        return f"❌ Unknown tool: {name}"


def get_tools_for_worker(worker: str) -> list[dict]:
    """Get tool definitions appropriate for a worker role.

    Chef gets all tools including delegation.
    DevOps gets file ops, deploy tools, and GitHub tools.
    Other workers get only file operations and communication.
    """
    # Combine base tool definitions with GitHub tools
    all_tools = TOOL_DEFINITIONS + GITHUB_TOOL_DEFINITIONS

    if worker == "chef":
        return all_tools

    elif worker == "devops":
        # DevOps gets file ops, deploy tools, and GitHub tools
        devops_tools = [
            "write_file", "read_file", "list_files", "run_command",
            "thinking",
            "check_railway_status", "deploy_railway", "create_deploy_files",
            "start_dev_server", "stop_dev_server",
            "git_init", "git_commit", "git_status", "github_create_repo", "github_push"
        ]
        return [t for t in all_tools if t["name"] in devops_tools]

    else:
        # Workers only get file ops, thinking, and testing
        worker_tools = [
            "write_file", "read_file", "list_files", "run_command",
            "thinking", "run_tests"
        ]
        return [t for t in all_tools if t["name"] in worker_tools]


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
