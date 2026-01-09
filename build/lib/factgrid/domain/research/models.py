"""Models for research domain - headlines and AI-researched stories."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Dict, Any, Optional


@dataclass
class RawHeadline:
    """Raw headline from NewsAPI, stored before processing."""
    id: str
    title: str
    description: str
    source_name: str
    source_id: Optional[str]
    url: str
    url_to_image: Optional[str]
    published_at: str
    content: Optional[str]
    fetched_at: datetime
    processed: bool = False
    story_id: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for MongoDB storage."""
        return {
            "_id": self.id,
            "title": self.title,
            "description": self.description,
            "source_name": self.source_name,
            "source_id": self.source_id,
            "url": self.url,
            "url_to_image": self.url_to_image,
            "published_at": self.published_at,
            "content": self.content,
            "fetched_at": self.fetched_at,
            "processed": self.processed,
            "story_id": self.story_id,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "RawHeadline":
        """Create from MongoDB document."""
        return cls(
            id=str(data.get("_id", "")),
            title=data.get("title", ""),
            description=data.get("description", ""),
            source_name=data.get("source_name", ""),
            source_id=data.get("source_id"),
            url=data.get("url", ""),
            url_to_image=data.get("url_to_image"),
            published_at=data.get("published_at", ""),
            content=data.get("content"),
            fetched_at=data.get("fetched_at", datetime.utcnow()),
            processed=data.get("processed", False),
            story_id=data.get("story_id"),
        )

    @classmethod
    def from_newsapi(cls, article: Dict[str, Any], headline_id: str) -> "RawHeadline":
        """Create from NewsAPI article response."""
        source = article.get("source", {})
        return cls(
            id=headline_id,
            title=article.get("title", ""),
            description=article.get("description", ""),
            source_name=source.get("name", "Unknown"),
            source_id=source.get("id"),
            url=article.get("url", ""),
            url_to_image=article.get("urlToImage"),
            published_at=article.get("publishedAt", ""),
            content=article.get("content"),
            fetched_at=datetime.utcnow(),
        )


@dataclass
class ResearchQuote:
    """A direct quote found during research."""
    content: str
    speaker: str
    role: str = ""
    affiliation: str = ""
    source_url: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "content": self.content,
            "speaker": self.speaker,
            "role": self.role,
            "affiliation": self.affiliation,
            "source_url": self.source_url,
        }


@dataclass
class ResearchFact:
    """A verified fact found during research."""
    content: str
    source: str
    source_url: str = ""
    confidence: float = 0.8
    verification_notes: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "content": self.content,
            "source": self.source,
            "source_url": self.source_url,
            "confidence": self.confidence,
            "verification_notes": self.verification_notes,
        }


@dataclass
class ResearchPerspective:
    """A political/ideological perspective with opinions and quotes."""
    perspective: str  # Conservative, Progressive, Expert, International, Neutral
    label: str  # Human-readable: "Höger", "Vänster", etc.
    summary: str = ""
    quotes: List[ResearchQuote] = field(default_factory=list)
    key_arguments: List[str] = field(default_factory=list)
    sources_used: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "perspective": self.perspective,
            "label": self.label,
            "summary": self.summary,
            "quotes": [q.to_dict() for q in self.quotes],
            "key_arguments": self.key_arguments,
            "sources_used": self.sources_used,
        }


@dataclass
class ResearchedStory:
    """A fully researched story with facts and multiple perspectives."""
    id: str
    headline_ids: List[str]  # Original headlines this story is based on
    title: str
    summary: str
    facts: List[ResearchFact] = field(default_factory=list)
    perspectives: List[ResearchPerspective] = field(default_factory=list)
    image_url: Optional[str] = None
    sources_searched: List[str] = field(default_factory=list)
    research_queries: List[str] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
    updated_at: datetime = field(default_factory=datetime.utcnow)
    version: int = 1

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for MongoDB storage and API response."""
        return {
            "_id": self.id,
            "headline_ids": self.headline_ids,
            "title": self.title,
            "summary": self.summary,
            "facts": [f.to_dict() for f in self.facts],
            "perspectives": [p.to_dict() for p in self.perspectives],
            "image_url": self.image_url,
            "sources_searched": self.sources_searched,
            "research_queries": self.research_queries,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "version": self.version,
        }

    def to_api_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for API response (without internal fields)."""
        return {
            "id": self.id,
            "name": self.title,
            "summary": self.summary,
            "image_url": self.image_url,
            "article_count": len(self.headline_ids),
            "sources": self.sources_searched[:5],
            "facts": [
                {
                    "content": f.content,
                    "source": f.source,
                    "confidence": f.confidence,
                    "status": "VERIFIED" if f.confidence > 0.7 else "UNVERIFIED",
                }
                for f in self.facts
            ],
            "perspectives": [
                {
                    "perspective": p.perspective,
                    "label": p.label,
                    "opinions": [
                        {
                            "content": arg,
                            "source": p.sources_used[0] if p.sources_used else "",
                            "affiliation": "",
                        }
                        for arg in p.key_arguments[:2]
                    ],
                    "quotes": [
                        {
                            "content": q.content,
                            "source": q.speaker,
                            "role": q.role,
                        }
                        for q in p.quotes[:2]
                    ],
                }
                for p in self.perspectives
            ],
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "ResearchedStory":
        """Create from MongoDB document."""
        facts = [
            ResearchFact(
                content=f.get("content", ""),
                source=f.get("source", ""),
                source_url=f.get("source_url", ""),
                confidence=f.get("confidence", 0.8),
                verification_notes=f.get("verification_notes", ""),
            )
            for f in data.get("facts", [])
        ]

        perspectives = []
        for p in data.get("perspectives", []):
            quotes = [
                ResearchQuote(
                    content=q.get("content", ""),
                    speaker=q.get("speaker", ""),
                    role=q.get("role", ""),
                    affiliation=q.get("affiliation", ""),
                    source_url=q.get("source_url", ""),
                )
                for q in p.get("quotes", [])
            ]
            perspectives.append(ResearchPerspective(
                perspective=p.get("perspective", "Neutral"),
                label=p.get("label", ""),
                summary=p.get("summary", ""),
                quotes=quotes,
                key_arguments=p.get("key_arguments", []),
                sources_used=p.get("sources_used", []),
            ))

        return cls(
            id=str(data.get("_id", "")),
            headline_ids=data.get("headline_ids", []),
            title=data.get("title", ""),
            summary=data.get("summary", ""),
            facts=facts,
            perspectives=perspectives,
            image_url=data.get("image_url"),
            sources_searched=data.get("sources_searched", []),
            research_queries=data.get("research_queries", []),
            created_at=data.get("created_at", datetime.utcnow()),
            updated_at=data.get("updated_at", datetime.utcnow()),
            version=data.get("version", 1),
        )
