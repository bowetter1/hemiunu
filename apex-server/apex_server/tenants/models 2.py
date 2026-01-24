"""Tenant models"""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from apex_server.shared.database import Base, TimestampMixin


class Tenant(Base, TimestampMixin):
    """A tenant (organization) in the system"""
    __tablename__ = "tenants"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100))
    slug: Mapped[str] = mapped_column(String(50), unique=True, index=True)

    # Limits
    max_concurrent_sprints: Mapped[int] = mapped_column(Integer, default=3)

    # Worker config: {"backend": "opus", "frontend": "opus", "chef": "opus"}
    worker_config: Mapped[dict] = mapped_column(JSON, default=dict)

    # Credentials (encrypted in production)
    github_token: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Relationships
    users: Mapped[list["User"]] = relationship("User", back_populates="tenant")
    sprints: Mapped[list["Sprint"]] = relationship("Sprint", back_populates="tenant")

    def __repr__(self):
        return f"<Tenant {self.slug}>"
