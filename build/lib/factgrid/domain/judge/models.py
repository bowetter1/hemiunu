"""Judge domain models."""

from dataclasses import dataclass, field
from typing import List, Dict, Any


SCHEMA_VERSION = "1.0"


@dataclass
class JudgeResult:
    """Result from judging an article."""

    schema_version: str
    model: str
    generated_at: str
    article: Dict[str, str]
    grid: List[Dict[str, Any]]

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            "schema_version": self.schema_version,
            "model": self.model,
            "generated_at": self.generated_at,
            "article": self.article,
            "grid": self.grid,
        }


JUDGE_SCHEMA: Dict[str, Any] = {
    "type": "object",
    "required": ["schema_version", "model", "generated_at", "article", "grid"],
    "properties": {
        "schema_version": {"type": "string"},
        "model": {"type": "string"},
        "generated_at": {"type": "string"},
        "article": {
            "type": "object",
            "required": ["title", "url", "source"],
            "properties": {
                "title": {"type": "string"},
                "url": {"type": "string"},
                "source": {"type": "string"},
            },
        },
        "grid": {
            "type": "array",
            "items": {
                "type": "object",
                "required": ["id", "type", "content", "source", "confidence", "status"],
                "properties": {
                    "id": {"type": "string"},
                    "type": {"type": "string"},
                    "content": {"type": "string"},
                    "source": {"type": "string"},
                    "confidence": {"type": "number"},
                    "status": {"type": "string"},
                },
            },
        },
    },
}
