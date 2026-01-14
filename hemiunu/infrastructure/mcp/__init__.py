"""
Infrastructure MCP - Model Context Protocol servrar.

Varje agent-roll har sin egen MCP-server med rollspecifika verktyg:
- WorkerServer: Skriva kod, köra kommandon, markera klart
- TesterServer: Läsa kod, köra tester, godkänna/avvisa
- VesirServer: Läsa kodbas, planera tasks
- IntegratorServer: Lösa merge-konflikter
"""
from .worker_server import create_worker_server
from .tester_server import create_tester_server
from .vesir_server import create_vesir_server
from .integrator_server import create_integrator_server

__all__ = [
    "create_worker_server",
    "create_tester_server",
    "create_vesir_server",
    "create_integrator_server"
]
