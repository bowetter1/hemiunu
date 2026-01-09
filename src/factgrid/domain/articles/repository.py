"""Article repository for MongoDB operations."""

import logging
from typing import Any, Dict, List, Optional

from factgrid.infrastructure import get_settings, get_collection
from factgrid.shared import utc_now, hash_identity, safe_text

logger = logging.getLogger(__name__)


class ArticleRepository:
    """Repository for article CRUD operations."""

    def __init__(self):
        settings = get_settings()
        self.collection = get_collection(settings.mongo_articles_collection)

    def find_all(self, limit: int = 10, skip: int = 0) -> List[Dict[str, Any]]:
        """Find all articles with pagination."""
        cursor = (
            self.collection.find()
            .sort("last_ingested_at", -1)
            .skip(skip)
            .limit(limit)
        )
        return list(cursor)

    def find_by_id(self, article_id: str) -> Optional[Dict[str, Any]]:
        """Find article by ID."""
        return self.collection.find_one({"_id": article_id})

    def get_history(self, article_id: str) -> Optional[Dict[str, Any]]:
        """Get article history."""
        return self.collection.find_one(
            {"_id": article_id},
            {"history": 1, "current_state.version": 1},
        )

    def upsert_from_judged(
        self,
        judged_article: Dict[str, Any],
        topic: str,
        source_label: str,
    ) -> str:
        """Insert or update article from judged payload."""
        article_meta = judged_article.get("article") or {}
        title = safe_text(article_meta.get("title"))
        url = safe_text(article_meta.get("url"))
        source_name = safe_text(article_meta.get("source"))
        identity = hash_identity(url, title, source_name)
        now = utc_now()
        new_grid = judged_article.get("grid") or []

        existing = self.collection.find_one(
            {"_id": identity},
            {"current_state": 1, "article_metadata": 1},
        )

        if existing:
            return self._update_existing(
                identity, existing, new_grid, title, source_name, source_label, now
            )

        return self._insert_new(
            identity, url, title, source_name, topic, new_grid, source_label, now
        )

    def _update_existing(
        self,
        identity: str,
        existing: Dict[str, Any],
        new_grid: List[Dict],
        title: str,
        source_name: str,
        source_label: str,
        now: str,
    ) -> str:
        """Update existing article."""
        current_state = existing.get("current_state") or {}
        prev_version = int(current_state.get("version", 0))
        prev_grid = current_state.get("grid") or []
        version = prev_version + 1

        history_entry = {
            "version": version,
            "commit_msg": "Automated re-judgement",
            "diff": f"Replaced grid rows ({len(prev_grid)} -> {len(new_grid)})",
            "logic": f"Judged from {source_label} payload.",
            "timestamp": now,
        }

        update = {
            "$set": {
                "article_metadata.title": title,
                "article_metadata.source": source_name,
                "current_state": {
                    "version": version,
                    "last_updated": now,
                    "grid": new_grid,
                },
                "last_ingested_at": now,
            },
            "$push": {"history": history_entry},
        }

        self.collection.update_one({"_id": identity}, update)
        logger.info("Updated article %s to version %s", identity, version)
        return identity

    def _insert_new(
        self,
        identity: str,
        url: str,
        title: str,
        source_name: str,
        topic: str,
        new_grid: List[Dict],
        source_label: str,
        now: str,
    ) -> str:
        """Insert new article."""
        history_entry = {
            "version": 1,
            "commit_msg": "Initial AI analysis",
            "diff": f"Added initial {len(new_grid)} rows",
            "logic": f"Judged from {source_label} payload.",
            "timestamp": now,
        }

        document = {
            "_id": identity,
            "article_metadata": {
                "original_url": url,
                "title": title,
                "source": source_name,
                "topic": topic,
                "initial_timestamp": now,
            },
            "current_state": {
                "version": 1,
                "last_updated": now,
                "grid": new_grid,
            },
            "history": [history_entry],
            "last_ingested_at": now,
        }

        self.collection.insert_one(document)
        logger.info("Inserted new article %s", identity)
        return identity
