"""Ingest domain models."""

from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass
class RawArticle:
    """A raw article from a news source."""

    title: Optional[str]
    description: Optional[str]
    content: Optional[str]
    url: Optional[str]
    source_name: Optional[str]
    published_at: Optional[str]
    author: Optional[str]

    @classmethod
    def from_newsapi(cls, data: Dict[str, Any]) -> "RawArticle":
        """Create from NewsAPI response."""
        return cls(
            title=data.get("title"),
            description=data.get("description"),
            content=data.get("content"),
            url=data.get("url"),
            source_name=(data.get("source") or {}).get("name"),
            published_at=data.get("publishedAt"),
            author=data.get("author"),
        )


@dataclass
class IngestResult:
    """Result from an ingest operation."""

    source: str
    articles_count: int
    raw_payload_id: Optional[str] = None
