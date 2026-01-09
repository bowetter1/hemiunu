"""Article service for business logic."""

from typing import List, Optional

from factgrid.domain.articles.models import Article
from factgrid.domain.articles.repository import ArticleRepository


class ArticleService:
    """Service for article operations."""

    def __init__(self):
        self.repository = ArticleRepository()

    def list_articles(self, limit: int = 10, skip: int = 0) -> List[Article]:
        """List all articles with pagination."""
        docs = self.repository.find_all(limit=limit, skip=skip)
        return [Article.from_mongo(doc) for doc in docs]

    def get_article(self, article_id: str) -> Optional[Article]:
        """Get a specific article by ID."""
        doc = self.repository.find_by_id(article_id)
        if not doc:
            return None
        return Article.from_mongo(doc)

    def get_article_history(self, article_id: str) -> Optional[dict]:
        """Get version history for an article."""
        doc = self.repository.get_history(article_id)
        if not doc:
            return None
        return {
            "article_id": article_id,
            "current_version": doc.get("current_state", {}).get("version", 0),
            "history": doc.get("history", []),
        }

    def store_judged_articles(
        self,
        judged_payload: dict,
        source_label: str = "NewsAPI",
        topic: str = "business",
    ) -> List[str]:
        """Store judged articles in database."""
        article_ids = []
        for judged_article in judged_payload.get("articles") or []:
            article_id = self.repository.upsert_from_judged(
                judged_article,
                topic=topic,
                source_label=source_label,
            )
            article_ids.append(article_id)
        return article_ids
