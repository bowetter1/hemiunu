"""Database setup with SQLAlchemy"""
import uuid
from datetime import datetime
from typing import Generator

from sqlalchemy import create_engine, String
from sqlalchemy.orm import sessionmaker, Session, DeclarativeBase, Mapped, mapped_column
from sqlalchemy.types import TypeDecorator, CHAR

from apex_server.config import get_settings


class GUID(TypeDecorator):
    """Platform-independent GUID type.
    Uses PostgreSQL's UUID type or CHAR(36) for SQLite.
    """
    impl = CHAR(36)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            return str(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            return uuid.UUID(value)
        return value


class Base(DeclarativeBase):
    """Base class for all models"""
    type_annotation_map = {
        uuid.UUID: GUID
    }


class TimestampMixin:
    """Adds created_at and updated_at to models"""
    created_at: Mapped[datetime] = mapped_column(default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(default=datetime.utcnow, onupdate=datetime.utcnow)


# Engine and session
settings = get_settings()

# Fix Railway's postgres:// URL (SQLAlchemy needs postgresql://)
_db_url = settings.database_url
if _db_url.startswith("postgres://"):
    _db_url = _db_url.replace("postgres://", "postgresql://", 1)

engine = create_engine(_db_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """Dependency for getting DB session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Create all tables"""
    # Import all models so they register with Base
    from apex_server.auth.models import User
    from apex_server.projects.models import Project, Page, PageVersion, ProjectLog

    Base.metadata.create_all(bind=engine)

    # Run migrations for new columns
    _run_migrations()


def _run_migrations():
    """Add new columns to existing tables (SQLAlchemy create_all doesn't do this)"""
    from sqlalchemy import text

    # First, ensure page_versions table exists
    create_page_versions = """
    CREATE TABLE IF NOT EXISTS page_versions (
        id VARCHAR(36) PRIMARY KEY,
        page_id VARCHAR(36) NOT NULL REFERENCES pages(id) ON DELETE CASCADE,
        version INTEGER NOT NULL,
        html TEXT NOT NULL,
        instruction TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """
    with engine.connect() as conn:
        try:
            conn.execute(text(create_page_versions))
            conn.commit()
            print("Migration: Ensured page_versions table exists", flush=True)
        except Exception as e:
            print(f"page_versions table migration: {e}", flush=True)

    migrations = [
        # Add selected_moodboard to projects table
        ("projects", "selected_moodboard", "ALTER TABLE projects ADD COLUMN selected_moodboard INTEGER"),
        # Add clarification JSON column for two-phase flow
        ("projects", "clarification", "ALTER TABLE projects ADD COLUMN clarification JSON"),
        # Add current_version to pages table for version history
        ("pages", "current_version", "ALTER TABLE pages ADD COLUMN current_version INTEGER DEFAULT 1"),
    ]

    # Add new enum values (PostgreSQL specific)
    enum_migrations = [
        ("projectstatus", "CLARIFICATION", "ALTER TYPE projectstatus ADD VALUE IF NOT EXISTS 'CLARIFICATION'"),
    ]

    for enum_type, value, sql in enum_migrations:
        with engine.connect() as conn:
            try:
                conn.execute(text(sql))
                conn.commit()
                print(f"Migration: Added {value} to enum {enum_type}", flush=True)
            except Exception as e:
                # May already exist or not supported
                print(f"Enum migration skipped for {value}: {e}", flush=True)

    for table, column, sql in migrations:
        with engine.connect() as conn:
            try:
                # Check if column exists
                result = conn.execute(text(f"SELECT {column} FROM {table} LIMIT 1"))
                result.close()
            except Exception:
                # Column doesn't exist, rollback and try to add it
                conn.rollback()
                try:
                    conn.execute(text(sql))
                    conn.commit()
                    print(f"Migration: Added {column} to {table}", flush=True)
                except Exception as e:
                    print(f"Migration failed for {column}: {e}", flush=True)
