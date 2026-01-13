"""Judge service for article analysis."""

import logging
from typing import Any, Dict, List

from factgrid.infrastructure import get_settings
from factgrid.domain.judge.providers.base import BaseJudgeProvider
from factgrid.domain.judge.providers.mock import MockJudgeProvider
from factgrid.domain.judge.providers.openai import OpenAIJudgeProvider
from factgrid.domain.judge.models import JUDGE_SCHEMA
from factgrid.shared import utc_now

logger = logging.getLogger(__name__)


class JudgeService:
    """Service for judging articles."""

    def __init__(self, provider: str = None):
        settings = get_settings()
        provider_name = (provider or settings.judge_provider).lower()
        self.provider = self._create_provider(provider_name, settings)

    def _create_provider(self, provider_name: str, settings) -> BaseJudgeProvider:
        """Create the appropriate judge provider."""
        if provider_name == "mock":
            return MockJudgeProvider(model=settings.judge_model)

        if provider_name == "openai":
            if not settings.openai_api_key:
                raise ValueError("OPENAI_API_KEY is required for openai provider")
            return OpenAIJudgeProvider(
                api_key=settings.openai_api_key,
                model=settings.judge_model,
                temperature=settings.judge_temperature,
                max_tokens=settings.judge_max_tokens,
            )

        raise NotImplementedError(f"Provider '{provider_name}' is not implemented")

    def judge_article(self, article: Dict[str, Any], category: str = None) -> Dict[str, Any]:
        """Judge a single article."""
        # Add category to article for prompt context
        if category:
            article = {**article, "category": category}
        return self.provider.judge(article)

    def judge_payload(self, payload: Dict[str, Any], category: str = None) -> Dict[str, Any]:
        """Judge all articles in a payload."""
        articles = payload.get("articles") or []
        judged = [self.judge_article(article, category=category) for article in articles]
        return {
            "source": "NewsAPI",
            "fetched_at": utc_now(),
            "total_results": payload.get("totalResults"),
            "articles": judged,
        }

    def validate_result(self, result: Dict[str, Any]) -> List[str]:
        """Validate judge result against schema."""
        errors: List[str] = []

        if not isinstance(result, dict):
            return ["result must be a dict"]

        for field in JUDGE_SCHEMA["required"]:
            if field not in result:
                errors.append(f"missing field: {field}")

        grid = result.get("grid")
        if not isinstance(grid, list) or not grid:
            errors.append("grid must be a non-empty list")
        else:
            grid_item_schema = JUDGE_SCHEMA["properties"]["grid"]["items"]
            for index, row in enumerate(grid, start=1):
                if not isinstance(row, dict):
                    errors.append(f"grid[{index}] must be an object")
                    continue
                for field in grid_item_schema["required"]:
                    if field not in row:
                        errors.append(f"grid[{index}] missing field: {field}")
                if "confidence" in row and not isinstance(row["confidence"], (int, float)):
                    errors.append(f"grid[{index}] confidence must be a number")

        return errors
