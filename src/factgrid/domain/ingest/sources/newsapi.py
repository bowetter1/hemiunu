"""NewsAPI news source."""

import logging
from typing import Any, Dict

import requests

from factgrid.domain.ingest.sources.base import BaseNewsSource
from factgrid.infrastructure import Settings

logger = logging.getLogger(__name__)


class NewsAPISource(BaseNewsSource):
    """NewsAPI.org news source."""

    def __init__(self, settings: Settings):
        self.settings = settings

    @property
    def name(self) -> str:
        return "NewsAPI"

    def fetch(self) -> Dict[str, Any]:
        """Fetch top headlines from NewsAPI."""
        url = f"{self.settings.newsapi_base_url.rstrip('/')}/{self.settings.newsapi_endpoint.lstrip('/')}"

        params = {
            "language": self.settings.newsapi_language,
            "country": self.settings.newsapi_country,
            "category": self.settings.newsapi_category,
            "pageSize": self.settings.newsapi_page_size,
        }

        headers = {
            "X-Api-Key": self.settings.newsapi_key,
            "User-Agent": self.settings.newsapi_user_agent,
        }

        logger.info("Fetching NewsAPI %s with params=%s", self.settings.newsapi_endpoint, params)

        response = requests.get(
            url,
            params=params,
            headers=headers,
            timeout=self.settings.newsapi_timeout_seconds,
        )

        if response.status_code != 200:
            raise RuntimeError(
                f"NewsAPI error {response.status_code}: {response.text.strip()}"
            )

        payload = response.json()

        if payload.get("status") != "ok":
            raise RuntimeError(f"NewsAPI returned status={payload.get('status')}")

        return payload
