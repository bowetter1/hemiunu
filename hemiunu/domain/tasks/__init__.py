"""
Hemiunu Tasks - Task-modell och livscykel.

Status-flöde:
TODO -> WORKING -> GREEN/RED -> DEPLOYED

En task har:
- id: Unik identifierare
- description: Vad som ska göras
- cli_test: Kommando för att verifiera
- status: Nuvarande tillstånd
- branch: Git-branch (om skapad)
"""
from .model import Task, TaskStatus
from .contract import Contract

__all__ = ["Task", "TaskStatus", "Contract"]
