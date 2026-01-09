"""Article domain models."""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class GridRow:
    """A single row in the fact grid."""

    id: str
    type: str  # FACT, OPINION, QUOTE
    content: str
    source: str
    confidence: float
    status: str  # VERIFIED, UNVERIFIED


@dataclass
class ArticleMetadata:
    """Metadata about an article."""

    original_url: str
    title: str
    source: str
    topic: str
    initial_timestamp: str


@dataclass
class HistoryEntry:
    """A version history entry."""

    version: int
    commit_msg: str
    diff: str
    logic: str
    timestamp: str


@dataclass
class CurrentState:
    """Current state of an article's grid."""

    version: int
    last_updated: str
    grid: List[GridRow] = field(default_factory=list)


@dataclass
class Article:
    """A processed article with fact grid and version history."""

    id: str
    metadata: ArticleMetadata
    current_state: CurrentState
    history: List[HistoryEntry] = field(default_factory=list)

    @classmethod
    def from_mongo(cls, doc: dict) -> "Article":
        """Create Article from MongoDB document."""
        metadata = ArticleMetadata(
            original_url=doc["article_metadata"].get("original_url", ""),
            title=doc["article_metadata"].get("title", ""),
            source=doc["article_metadata"].get("source", ""),
            topic=doc["article_metadata"].get("topic", ""),
            initial_timestamp=doc["article_metadata"].get("initial_timestamp", ""),
        )

        grid_rows = [
            GridRow(
                id=row.get("id", ""),
                type=row.get("type", ""),
                content=row.get("content", ""),
                source=row.get("source", ""),
                confidence=row.get("confidence", 0.0),
                status=row.get("status", "UNVERIFIED"),
            )
            for row in doc.get("current_state", {}).get("grid", [])
        ]

        current_state = CurrentState(
            version=doc.get("current_state", {}).get("version", 1),
            last_updated=doc.get("current_state", {}).get("last_updated", ""),
            grid=grid_rows,
        )

        history = [
            HistoryEntry(
                version=entry.get("version", 1),
                commit_msg=entry.get("commit_msg", ""),
                diff=entry.get("diff", ""),
                logic=entry.get("logic", ""),
                timestamp=entry.get("timestamp", ""),
            )
            for entry in doc.get("history", [])
        ]

        return cls(
            id=str(doc["_id"]),
            metadata=metadata,
            current_state=current_state,
            history=history,
        )
