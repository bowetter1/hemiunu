"""API response schemas."""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    timestamp: str


class ArticleGridRow(BaseModel):
    """A row in the article grid."""

    id: str
    type: str
    content: str
    source: str
    confidence: float
    status: str


class ArticleMetadata(BaseModel):
    """Article metadata."""

    original_url: str
    title: str
    source: str
    topic: str
    initial_timestamp: str


class ArticleState(BaseModel):
    """Current state of an article."""

    version: int
    last_updated: str
    grid: List[ArticleGridRow]


class ArticleResponse(BaseModel):
    """Article response."""

    id: str
    article_metadata: ArticleMetadata
    current_state: ArticleState
    history: List[Dict[str, Any]]


class IngestResponse(BaseModel):
    """Ingest operation response."""

    message: str
    articles_fetched: int
    raw_payload_id: Optional[str] = None


class JudgeResponse(BaseModel):
    """Judge operation response."""

    message: str
    articles_judged: int
    article_ids: List[str]


class PipelineResponse(BaseModel):
    """Full pipeline response."""

    message: str
    articles_fetched: int
    articles_judged: int
    article_ids: List[str]


class HistoryResponse(BaseModel):
    """Article history response."""

    article_id: str
    current_version: int
    history: List[Dict[str, Any]]
