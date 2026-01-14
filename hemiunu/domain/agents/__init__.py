"""
Hemiunu Agents - AI-agenter för olika roller.

Roller:
- Worker: Skriver kod
- Tester: Validerar kod (oberoende)
- Vesir: Bryter ner stora uppdrag
- Integrator: Löser merge-konflikter

Två varianter:
- Original (BaseAgent): Direkt tool-execution
- MCP (MCPAgent): Rollseparerade tools via MCP-servrar
"""
# Original agents (bakåtkompatibilitet)
from .base import BaseAgent
from .worker import WorkerAgent
from .tester import TesterAgent
from .vesir import VesirAgent
from .integrator import IntegratorAgent

# MCP-baserade agents (nya, med rollseparation)
from .mcp_base import MCPAgent
from .mcp_worker import MCPWorkerAgent
from .mcp_tester import MCPTesterAgent
from .mcp_vesir import MCPVesirAgent
from .mcp_integrator import MCPIntegratorAgent

__all__ = [
    # Original
    "BaseAgent",
    "WorkerAgent",
    "TesterAgent",
    "VesirAgent",
    "IntegratorAgent",
    # MCP
    "MCPAgent",
    "MCPWorkerAgent",
    "MCPTesterAgent",
    "MCPVesirAgent",
    "MCPIntegratorAgent",
]
