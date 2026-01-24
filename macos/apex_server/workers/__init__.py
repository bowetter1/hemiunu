"""
Apex Workers - Multi-agent orchestration for software development

This module provides:
- Worker configuration and AI mappings
- Tool definitions for LLM tool calling
- Prompt templates for each worker role
"""

from .config import (
    WORKER_AI,
    ALL_ROLES,
    ROLE_NAMES,
    ROLE_ICONS,
    MODEL_IDS,
    AVAILABLE_PROVIDERS,
    TEAMS,
    DEFAULT_TEAM,
    get_worker_ai,
    get_model_id,
    get_provider,
    get_team_config,
    get_chef_prompt,
    get_worker_prompt,
    get_base_prompt,
)

from .tools import (
    TOOL_DEFINITIONS,
    TOOL_HANDLERS,
    DELEGATION_TOOLS,
    execute_tool,
    get_tools_for_worker,
)

__all__ = [
    # Config
    "WORKER_AI",
    "ALL_ROLES",
    "ROLE_NAMES",
    "ROLE_ICONS",
    "MODEL_IDS",
    "AVAILABLE_PROVIDERS",
    "TEAMS",
    "DEFAULT_TEAM",
    "get_worker_ai",
    "get_model_id",
    "get_provider",
    "get_team_config",
    "get_chef_prompt",
    "get_worker_prompt",
    "get_base_prompt",
    # Tools
    "TOOL_DEFINITIONS",
    "TOOL_HANDLERS",
    "DELEGATION_TOOLS",
    "execute_tool",
    "get_tools_for_worker",
]
