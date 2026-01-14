"""
Task-modell - Domänobjekt för uppgifter.
"""
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional
from datetime import datetime


class TaskStatus(Enum):
    """Möjliga status för en task."""
    TODO = "TODO"           # Väntar på att påbörjas
    WORKING = "WORKING"     # Worker arbetar
    GREEN = "GREEN"         # Godkänd av Tester
    RED = "RED"             # Avvisad av Tester
    SPLIT = "SPLIT"         # Delad i subtasks
    DEPLOYED = "DEPLOYED"   # Mergad till main


@dataclass
class Task:
    """
    En atomär uppgift i Hemiunu.

    Invarianter:
    - cli_test måste vara körbart kommando
    - description får inte vara tom
    - status följer definierad livscykel
    """
    id: str
    description: str
    cli_test: Optional[str] = None
    status: TaskStatus = TaskStatus.TODO

    # Arbetsstatus
    worker_status: Optional[str] = None
    tester_status: Optional[str] = None

    # Resultat
    branch: Optional[str] = None
    code_path: Optional[str] = None
    test_path: Optional[str] = None
    error: Optional[str] = None

    # Hierarki
    parent_id: Optional[str] = None

    # Metadata
    created_at: datetime = field(default_factory=datetime.now)

    def can_start(self) -> bool:
        """Kan denna task påbörjas?"""
        return self.status == TaskStatus.TODO

    def can_approve(self) -> bool:
        """Kan denna task godkännas?"""
        return self.status == TaskStatus.WORKING

    def can_deploy(self) -> bool:
        """Kan denna task deployas?"""
        return self.status == TaskStatus.GREEN

    def start(self) -> None:
        """Markera som påbörjad."""
        if not self.can_start():
            raise ValueError(f"Kan inte starta task med status {self.status}")
        self.status = TaskStatus.WORKING
        self.worker_status = "WORKING"

    def approve(self) -> None:
        """Markera som godkänd."""
        if not self.can_approve():
            raise ValueError(f"Kan inte godkänna task med status {self.status}")
        self.status = TaskStatus.GREEN
        self.tester_status = "APPROVED"

    def reject(self, error: str) -> None:
        """Markera som avvisad."""
        self.status = TaskStatus.RED
        self.tester_status = "REJECTED"
        self.error = error

    def deploy(self) -> None:
        """Markera som deployad."""
        if not self.can_deploy():
            raise ValueError(f"Kan inte deploya task med status {self.status}")
        self.status = TaskStatus.DEPLOYED

    def to_dict(self) -> dict:
        """Konvertera till dictionary för persistens."""
        return {
            "id": self.id,
            "description": self.description,
            "cli_test": self.cli_test,
            "status": self.status.value,
            "worker_status": self.worker_status,
            "tester_status": self.tester_status,
            "branch": self.branch,
            "code_path": self.code_path,
            "test_path": self.test_path,
            "error": self.error,
            "parent_id": self.parent_id,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Task":
        """Skapa från dictionary."""
        return cls(
            id=data["id"],
            description=data["description"],
            cli_test=data.get("cli_test"),
            status=TaskStatus(data.get("status", "TODO")),
            worker_status=data.get("worker_status"),
            tester_status=data.get("tester_status"),
            branch=data.get("branch"),
            code_path=data.get("code_path"),
            test_path=data.get("test_path"),
            error=data.get("error"),
            parent_id=data.get("parent_id"),
            created_at=datetime.fromisoformat(data["created_at"]) if data.get("created_at") else datetime.now()
        )
