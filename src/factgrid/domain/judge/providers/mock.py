"""Mock judge provider for testing."""

from typing import Any, Dict, List, Optional

from factgrid.domain.judge.providers.base import BaseJudgeProvider
from factgrid.domain.judge.models import SCHEMA_VERSION
from factgrid.shared import utc_now, safe_text


class MockJudgeProvider(BaseJudgeProvider):
    """Mock provider that generates simple grids without AI."""

    def __init__(self, model: str = "mock"):
        self.model = model

    def judge(self, article: Dict[str, Any]) -> Dict[str, Any]:
        """Generate a mock grid from article content."""
        title = safe_text(article.get("title"))
        description = safe_text(article.get("description"))
        content = safe_text(article.get("content"))
        url = safe_text(article.get("url"))
        source_name = safe_text((article.get("source") or {}).get("name"))
        source = source_name or url or "Unknown"

        base_confidence = 0.35
        if source_name and url:
            base_confidence = 0.45
        elif source_name or url:
            base_confidence = 0.4

        grid: List[Dict[str, Any]] = []

        if title:
            grid.append({
                "id": "row_1",
                "type": "FACT",
                "content": f"Headline: {title}",
                "source": source,
                "confidence": base_confidence,
                "status": "UNVERIFIED",
            })

        if description:
            grid.append({
                "id": f"row_{len(grid) + 1}",
                "type": "FACT",
                "content": f"Summary: {description}",
                "source": source,
                "confidence": base_confidence - 0.05,
                "status": "UNVERIFIED",
            })

        quote = self._extract_quote(content)
        if quote:
            grid.append({
                "id": f"row_{len(grid) + 1}",
                "type": "QUOTE",
                "content": quote,
                "source": source,
                "confidence": base_confidence - 0.1,
                "status": "UNVERIFIED",
            })

        if not grid:
            grid.append({
                "id": "row_1",
                "type": "FACT",
                "content": "No usable article content found.",
                "source": source,
                "confidence": 0.2,
                "status": "UNVERIFIED",
            })

        return {
            "schema_version": SCHEMA_VERSION,
            "model": self.model,
            "generated_at": utc_now(),
            "article": {
                "title": title,
                "url": url,
                "source": source_name,
            },
            "grid": grid,
        }

    def _extract_quote(self, text: str) -> Optional[str]:
        """Extract first quoted text from content."""
        if not text:
            return None
        start = text.find('"')
        if start == -1:
            return None
        end = text.find('"', start + 1)
        if end == -1:
            return None
        snippet = text[start + 1:end].strip()
        return snippet or None
