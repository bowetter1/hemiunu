"""Project models - simplified for macOS app"""
import uuid
import enum
from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, Text, ForeignKey, Enum, Integer, Float, DateTime, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from apex_server.shared.database import Base, TimestampMixin, GUID


class ProjectStatus(str, enum.Enum):
    """Project generation status"""
    BRIEF = "brief"           # User entered brief
    MOODBOARD = "moodboard"   # Generating/showing moodboard
    LAYOUTS = "layouts"       # Generating/showing 3 layouts
    EDITING = "editing"       # User is editing
    DONE = "done"
    FAILED = "failed"


class Project(Base, TimestampMixin):
    """A design project"""
    __tablename__ = "projects"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)

    # Brief from user
    brief: Mapped[str] = mapped_column(Text)

    # Status
    status: Mapped[ProjectStatus] = mapped_column(Enum(ProjectStatus), default=ProjectStatus.BRIEF)

    # Moodboard (JSON)
    moodboard: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Selected moodboard (1, 2, or 3)
    selected_moodboard: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Selected layout (1, 2, or 3)
    selected_layout: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Storage path
    project_dir: Mapped[str] = mapped_column(String(500))

    # Owner
    user_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("users.id"))

    # Token usage
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    cost_usd: Mapped[float] = mapped_column(Float, default=0.0)

    # Error info
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Relationships
    pages: Mapped[List["Page"]] = relationship("Page", back_populates="project", cascade="all, delete-orphan")
    logs: Mapped[List["ProjectLog"]] = relationship("ProjectLog", back_populates="project", cascade="all, delete-orphan")


class Page(Base, TimestampMixin):
    """A page in a project"""
    __tablename__ = "pages"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("projects.id"))

    name: Mapped[str] = mapped_column(String(100))  # "Hem", "Om oss", etc.
    html: Mapped[str] = mapped_column(Text)

    # For layout alternatives (1, 2, 3) - null for final pages
    layout_variant: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    project: Mapped["Project"] = relationship("Project", back_populates="pages")


class ProjectLog(Base):
    """Log entry for a project"""
    __tablename__ = "project_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    project_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("projects.id"))
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    phase: Mapped[str] = mapped_column(String(50))  # "moodboard", "layout", "edit"
    message: Mapped[str] = mapped_column(Text)
    data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    project: Mapped["Project"] = relationship("Project", back_populates="logs")
