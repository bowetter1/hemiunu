"""
Apex Tools - Modulära verktyg för MCP-servern.

Varje modul exporterar:
- TOOLS: Lista med tool-schemas
- HANDLERS: Dict med {tool_name: handler_func}
"""

from .base import run_cli, log_to_sprint
from .meetings import TOOLS as MEETING_TOOLS, HANDLERS as MEETING_HANDLERS
from .delegation import TOOLS as DELEGATION_TOOLS, HANDLERS as DELEGATION_HANDLERS
from .communication import TOOLS as COMMUNICATION_TOOLS, HANDLERS as COMMUNICATION_HANDLERS
from .files import TOOLS as FILE_TOOLS, HANDLERS as FILE_HANDLERS
from .deploy import TOOLS as DEPLOY_TOOLS, HANDLERS as DEPLOY_HANDLERS
from .testing import TOOLS as TESTING_TOOLS, HANDLERS as TESTING_HANDLERS
from .boss import TOOLS as BOSS_TOOLS, HANDLERS as BOSS_HANDLERS

# Kombinera alla tools
ALL_TOOLS = (
    MEETING_TOOLS +
    DELEGATION_TOOLS +
    COMMUNICATION_TOOLS +
    FILE_TOOLS +
    DEPLOY_TOOLS +
    TESTING_TOOLS +
    BOSS_TOOLS
)

# Kombinera alla handlers
ALL_HANDLERS = {
    **MEETING_HANDLERS,
    **DELEGATION_HANDLERS,
    **COMMUNICATION_HANDLERS,
    **FILE_HANDLERS,
    **DEPLOY_HANDLERS,
    **TESTING_HANDLERS,
    **BOSS_HANDLERS,
}
