"""Auth models"""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from apex_server.shared.database import Base, TimestampMixin, GUID


class User(Base, TimestampMixin):
    """A user in the system"""
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(20), default="member")  # admin, member
    firebase_uid: Mapped[Optional[str]] = mapped_column(String(128), unique=True, nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(20), default="approved")  # pending, approved, rejected
    telegram_chat_id: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    # Tenant relationship
    tenant_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("tenants.id"))
    tenant: Mapped["Tenant"] = relationship("Tenant", back_populates="users")

    def __repr__(self):
        return f"<User {self.email}>"
