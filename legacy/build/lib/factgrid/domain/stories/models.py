"""Story models for clustering and fact extraction."""

from dataclasses import dataclass, field
from typing import List, Dict, Any


@dataclass
class Fact:
    """A verifiable fact."""
    content: str
    source: str
    confidence: float = 0.0
    status: str = "UNVERIFIED"


@dataclass
class Opinion:
    """A subjective opinion."""
    content: str
    source: str
    affiliation: str = ""


@dataclass
class Quote:
    """A direct quote."""
    content: str
    source: str
    role: str = ""


@dataclass
class Perspective:
    """Opinions and quotes grouped by political/ideological perspective."""
    perspective: str  # Conservative, Progressive, Expert, International, Neutral
    label: str  # Human-readable label like "Right/GOP", "Left/DEM"
    opinions: List[Opinion] = field(default_factory=list)
    quotes: List[Quote] = field(default_factory=list)


@dataclass
class Story:
    """A news story with clustered articles and extracted facts/perspectives."""
    id: str
    name: str
    summary: str
    article_indices: List[int]
    articles: List[Dict[str, Any]] = field(default_factory=list)
    facts: List[Fact] = field(default_factory=list)
    perspectives: List[Perspective] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        # Get first available image from articles
        image_url = None
        for a in self.articles:
            if a.get("urlToImage"):
                image_url = a.get("urlToImage")
                break

        return {
            "id": self.id,
            "name": self.name,
            "summary": self.summary,
            "article_count": len(self.articles),
            "image_url": image_url,
            "sources": list(set(
                (a.get("source") or {}).get("name", "Unknown")
                for a in self.articles
            )),
            "facts": [
                {
                    "content": f.content,
                    "source": f.source,
                    "confidence": f.confidence,
                    "status": f.status,
                }
                for f in self.facts
            ],
            "perspectives": [
                {
                    "perspective": p.perspective,
                    "label": p.label,
                    "opinions": [
                        {
                            "content": o.content,
                            "source": o.source,
                            "affiliation": o.affiliation,
                        }
                        for o in p.opinions
                    ],
                    "quotes": [
                        {
                            "content": q.content,
                            "source": q.source,
                            "role": q.role,
                        }
                        for q in p.quotes
                    ],
                }
                for p in self.perspectives
            ],
        }


@dataclass
class StoryClusterResult:
    """Result of clustering articles into stories."""
    stories: List[Story]
    unclustered_count: int = 0
