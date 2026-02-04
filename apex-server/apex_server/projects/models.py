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
    CLARIFICATION = "clarification"  # Waiting for user clarification
    RESEARCHING = "researching"      # Research in progress
    RESEARCH_DONE = "research_done"  # Research complete, waiting for user to trigger layout generation
    MOODBOARD = "moodboard"   # Generating/showing moodboard (legacy)
    LAYOUTS = "layouts"       # Generating/showing 3 layouts
    EDITING = "editing"       # User is editing
    BUILDING = "building"     # Sandbox is building/installing
    RUNNING = "running"       # App is running in sandbox
    DONE = "done"
    FAILED = "failed"


class Project(Base, TimestampMixin):
    """A design project"""
    __tablename__ = "projects"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)

    # Brief from user
    brief: Mapped[str] = mapped_column(Text)

    # Image source preference ("ai", "stock", "existing_site")
    image_source: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, default="ai")

    # Status
    status: Mapped[ProjectStatus] = mapped_column(Enum(ProjectStatus), default=ProjectStatus.BRIEF)

    # Moodboard (JSON)
    moodboard: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Clarification (JSON) - question and options when status is CLARIFICATION
    clarification: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Research markdown report (written by Opus during research phase)
    research_md: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

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

    # Generation configuration (JSON) - toggleable tools/phases
    generation_config: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Error info
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Daytona sandbox
    sandbox_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    sandbox_status: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    sandbox_preview_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Relationships
    variants: Mapped[List["Variant"]] = relationship("Variant", back_populates="project", cascade="all, delete-orphan")
    pages: Mapped[List["Page"]] = relationship("Page", back_populates="project", cascade="all, delete-orphan")
    logs: Mapped[List["ProjectLog"]] = relationship("ProjectLog", back_populates="project", cascade="all, delete-orphan")


class Variant(Base, TimestampMixin):
    """A design variant within a project - each can have multiple pages"""
    __tablename__ = "variants"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("projects.id"))

    name: Mapped[str] = mapped_column(String(100))  # "Minimalist", "Bold", etc.
    moodboard_index: Mapped[int] = mapped_column(Integer)  # Which moodboard (1, 2, 3)

    project: Mapped["Project"] = relationship("Project", back_populates="variants")
    pages: Mapped[List["Page"]] = relationship("Page", back_populates="variant", cascade="all, delete-orphan")


class Page(Base, TimestampMixin):
    """A page in a variant"""
    __tablename__ = "pages"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)
    project_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("projects.id"))
    variant_id: Mapped[Optional[uuid.UUID]] = mapped_column(GUID, ForeignKey("variants.id"), nullable=True)

    # Parent page ID - for grouping generated pages under their layout/hero page
    parent_page_id: Mapped[Optional[uuid.UUID]] = mapped_column(GUID, ForeignKey("pages.id"), nullable=True)

    name: Mapped[str] = mapped_column(String(100))  # "Home", "About", etc.
    html: Mapped[str] = mapped_column(Text)

    # Legacy: For layout alternatives (1, 2, 3) - kept for migration compatibility
    layout_variant: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Current version number
    current_version: Mapped[int] = mapped_column(Integer, default=1)

    project: Mapped["Project"] = relationship("Project", back_populates="pages")
    variant: Mapped[Optional["Variant"]] = relationship("Variant", back_populates="pages")
    versions: Mapped[List["PageVersion"]] = relationship("PageVersion", back_populates="page", cascade="all, delete-orphan")

    # Self-referential relationship for parent/child pages
    children: Mapped[List["Page"]] = relationship("Page", back_populates="parent", cascade="all, delete-orphan")
    parent: Mapped[Optional["Page"]] = relationship("Page", back_populates="children", remote_side=[id])


class PageVersion(Base):
    """A version of a page - created on each edit"""
    __tablename__ = "page_versions"

    id: Mapped[uuid.UUID] = mapped_column(GUID, primary_key=True, default=uuid.uuid4)
    page_id: Mapped[uuid.UUID] = mapped_column(GUID, ForeignKey("pages.id"))

    version: Mapped[int] = mapped_column(Integer)  # 1, 2, 3...
    html: Mapped[str] = mapped_column(Text)
    instruction: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # Edit instruction that created this version
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    page: Mapped["Page"] = relationship("Page", back_populates="versions")


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
