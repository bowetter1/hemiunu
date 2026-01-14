"""
Infrastructure DB - SQLite persistens.

Hanterar all databasinteraktion:
- Tasks repository
- Deploy log
- Konflikthantering
"""
from .connection import get_connection, init_db
from .repository import TaskRepository, DeployRepository, ConflictRepository
from .master import set_master, get_master

__all__ = [
    "get_connection",
    "init_db",
    "TaskRepository",
    "DeployRepository",
    "ConflictRepository",
    "set_master",
    "get_master"
]
