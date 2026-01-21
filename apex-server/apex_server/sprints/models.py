"""Sprint models"""
import uuid
import enum
from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, Text, ForeignKey, Enum, Integer, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship

from apex_server.shared.database import Base, TimestampMixin, GUID


class SprintStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class LogType(str, enum.Enum):
    INFO = "info"
    PHASE = "phase"
    WORKER_START = "worker_start"
    WORKER_DONE = "worker_done"
    TOOL_CALL = "tool_call"
    TOOL_RESULT = "tool_result"
    THINKING = "thinking"
    PARALLEL_START = "parallel_start"
    PARALLEL_DONE = "parallel_done"
    ERROR = "error"
    SUCCESS = "success"


class Sprint(Base, TimestampMixin):
    """A sprint (task execution) in the system"""
    __tablename__ = "sprints"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    task: Mapped[str] = mapped_column(Text)
    status: Mapped[SprintStatus] = mapped_column(Enum(SprintStatus), default=SprintStatus.PENDING)

    # Storage path for sprint files
    project_dir: Mapped[str] = mapped_column(String(255))

    # Optional GitHub integration
    github_repo: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Timing
    started_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    completed_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)

    # Error info
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    tenant_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("tenants.id"))
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="sprints")

    created_by_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    created_by: Mapped["User"] = relationship("User", back_populates="sprints")

    # Log entries
    logs: Mapped[List["LogEntry"]] = relationship("LogEntry", back_populates="sprint", order_by="LogEntry.id")

    def __repr__(self):
        return f"<Sprint {self.id} [{self.status.value}]>"


class LogEntry(Base):
    """A log entry for a sprint"""
    __tablename__ = "log_entries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    log_type: Mapped[LogType] = mapped_column(Enum(LogType), default=LogType.INFO)
    worker: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    message: Mapped[str] = mapped_column(Text)
    data: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON string for extra data

    # Sprint relationship
    sprint_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("sprints.id"))
    sprint: Mapped["Sprint"] = relationship("Sprint", back_populates="logs")

    def __repr__(self):
        return f"<LogEntry {self.id} [{self.log_type.value}]>"
