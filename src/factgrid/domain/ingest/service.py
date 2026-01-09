"""Ingest service for fetching and storing raw news."""

import logging
from typing import Any, Dict, List, Optional

from factgrid.infrastructure import get_settings, get_collection
from factgrid.infrastructure.rss import parse_rss_feed, rss_to_newsapi_format
from factgrid.domain.ingest.sources.newsapi import NewsAPISource
from factgrid.domain.ingest.models import IngestResult
from factgrid.domain.sources import get_balanced_sources, get_enabled_sources
from factgrid.shared import utc_now

logger = logging.getLogger(__name__)


class IngestService:
    """Service for ingesting news from external sources."""

    def __init__(self):
        self.settings = get_settings()
        self.source = NewsAPISource(self.settings)

    def fetch(self) -> Dict[str, Any]:
        """Fetch news from configured source (NewsAPI)."""
        return self.source.fetch()

    def fetch_multi_source(self, limit_per_source: int = 5) -> Dict[str, Any]:
        """Fetch news from multiple RSS sources with different biases."""
        all_articles = []
        sources_used = []

        # Get balanced sources (left, center, right)
        sources = get_balanced_sources(limit_per_bias=2)

        for source in sources:
            logger.info(f"Fetching from {source.name} ({source.bias})...")
            try:
                rss_articles = parse_rss_feed(
                    feed_url=source.rss_url,
                    source_name=source.name,
                    source_bias=source.bias,
                    limit=limit_per_source,
                )
                articles = rss_to_newsapi_format(rss_articles)
                all_articles.extend(articles)
                if articles:
                    sources_used.append(f"{source.name} ({source.bias})")
                    logger.info(f"Got {len(articles)} from {source.name}")
            except Exception as e:
                logger.warning(f"Failed to fetch from {source.name}: {e}")

        logger.info(f"Total articles from {len(sources_used)} sources: {len(all_articles)}")

        return {
            "status": "ok",
            "totalResults": len(all_articles),
            "sources_used": sources_used,
            "articles": all_articles,
        }

    def fetch_and_store_raw(self) -> IngestResult:
        """Fetch news and store raw payload in MongoDB."""
        payload = self.fetch()
        raw_id = self._store_raw(payload)

        return IngestResult(
            source=self.source.name,
            articles_count=len(payload.get("articles", [])),
            raw_payload_id=raw_id,
        )

    def _store_raw(self, payload: Dict[str, Any]) -> str:
        """Store raw payload in MongoDB."""
        collection = get_collection(self.settings.mongo_raw_collection)

        document = {
            "source": self.source.name,
            "fetched_at": utc_now(),
            "payload": payload,
        }

        result = collection.insert_one(document)
        logger.info("Stored raw payload with id=%s", result.inserted_id)

        return str(result.inserted_id)
