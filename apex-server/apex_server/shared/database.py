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
engine = create_engine(settings.database_url)
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
    Base.metadata.create_all(bind=engine)

    # Run migrations for new columns
    _run_migrations()


def _run_migrations():
    """Add new columns to existing tables (SQLAlchemy create_all doesn't do this)"""
    from sqlalchemy import text

    migrations = [
        # Add token tracking columns to sprints table
        ("sprints", "input_tokens", "ALTER TABLE sprints ADD COLUMN input_tokens INTEGER DEFAULT 0"),
        ("sprints", "output_tokens", "ALTER TABLE sprints ADD COLUMN output_tokens INTEGER DEFAULT 0"),
    ]

    with engine.connect() as conn:
        for table, column, sql in migrations:
            try:
                # Check if column exists
                result = conn.execute(text(f"SELECT {column} FROM {table} LIMIT 1"))
                result.close()
            except Exception:
                # Column doesn't exist, add it
                try:
                    conn.execute(text(sql))
                    conn.commit()
                    print(f"Migration: Added {column} to {table}")
                except Exception as e:
                    print(f"Migration failed for {column}: {e}")
