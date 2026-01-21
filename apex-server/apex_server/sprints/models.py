"""Sprint models"""
import uuid
import enum
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Text, ForeignKey, Enum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from apex_server.shared.database import Base, TimestampMixin, GUID


class SprintStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


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

    def __repr__(self):
        return f"<Sprint {self.id} [{self.status.value}]>"
