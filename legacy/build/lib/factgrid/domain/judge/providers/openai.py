"""OpenAI judge provider."""

import json
from pathlib import Path
from typing import Any, Dict

from openai import OpenAI

from factgrid.domain.judge.providers.base import BaseJudgeProvider
from factgrid.domain.judge.providers.mock import MockJudgeProvider
from factgrid.domain.judge.models import SCHEMA_VERSION
from factgrid.shared import utc_now, safe_text


PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "judge.txt"


class OpenAIJudgeProvider(BaseJudgeProvider):
    """OpenAI-powered judge provider."""

    def __init__(
        self,
        api_key: str,
        model: str = "gpt-4o-mini",
        temperature: float = 0.2,
        max_tokens: int = 1200,
    ):
        self.client = OpenAI(api_key=api_key)
        self.model = model
        self.temperature = temperature
        self.max_tokens = max_tokens
        self._mock_fallback = MockJudgeProvider(model=model)

    # Map NewsAPI categories to our topic categories
    CATEGORY_MAP = {
        "business": "Economy",
        "economy": "Economy",
        "finance": "Economy",
        "technology": "Technology",
        "tech": "Technology",
        "science": "Technology",
        "politics": "Politics",
        "government": "Politics",
        "law": "Politics",
        "health": "Health",
        "medicine": "Health",
        "sports": "Social",
        "entertainment": "Social",
        "culture": "Social",
        "environment": "Environment",
        "climate": "Environment",
        "energy": "Environment",
        "security": "Security",
        "military": "Security",
        "defense": "Security",
        "general": "Other",
    }

    def judge(self, article: Dict[str, Any]) -> Dict[str, Any]:
        """Judge article using OpenAI and return structured grid."""
        prompt = self._build_prompt(article)

        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {
                    "role": "system",
                    "content": "You are The Judge, an objective fact separator. Return ONLY valid JSON with topic field for each grid row.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=self.temperature,
            max_tokens=self.max_tokens,
            response_format={"type": "json_object"},
        )

        content = response.choices[0].message.content
        result = json.loads(content)

        # Ensure required fields
        result["schema_version"] = result.get("schema_version", SCHEMA_VERSION)
        result["model"] = self.model
        result["generated_at"] = utc_now()

        # Validate and fix grid
        if "grid" not in result or not result["grid"]:
            return self._mock_fallback.judge(article)

        # Determine fallback topic from article category
        article_category = safe_text(article.get("category", "")).lower()
        fallback_topic = self.CATEGORY_MAP.get(article_category, "Other")

        for i, row in enumerate(result["grid"]):
            row["id"] = row.get("id", f"row_{i+1}")
            row["status"] = row.get("status", "UNVERIFIED")
            row["confidence"] = row.get("confidence", 0.5)
            # Use AI-provided topic, or fallback to article category mapping
            row["topic"] = row.get("topic") or fallback_topic

        return result

    def _build_prompt(self, article: Dict[str, Any]) -> str:
        """Build prompt for OpenAI."""
        prompt_template = self._load_prompt()

        # Get category and map to topic for context
        category = safe_text(article.get("category", "general")).lower()
        suggested_topic = self.CATEGORY_MAP.get(category, "Other")

        article_payload = {
            "title": safe_text(article.get("title")),
            "description": safe_text(article.get("description")),
            "content": safe_text(article.get("content")),
            "url": safe_text(article.get("url")),
            "source": safe_text((article.get("source") or {}).get("name")),
            "category": category,
            "suggested_topic": suggested_topic,
        }
        return prompt_template.replace(
            "{{ARTICLE_JSON}}",
            json.dumps(article_payload, ensure_ascii=True, indent=2),
        )

    def _load_prompt(self) -> str:
        """Load prompt template from file."""
        return PROMPT_PATH.read_text(encoding="utf-8")
