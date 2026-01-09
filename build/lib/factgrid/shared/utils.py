"""Shared utility functions."""

from datetime import datetime, timezone
import hashlib
from typing import Optional


def utc_now() -> str:
    """Return current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def hash_identity(url: str, title: str, source: str) -> str:
    """Generate a unique hash for an article based on URL, title, and source."""
    base = url.strip() or f"{title.strip()}|{source.strip()}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()


def safe_text(value: Optional[str]) -> str:
    """Return stripped text or empty string if None."""
    if value is None:
        return ""
    return value.strip()
