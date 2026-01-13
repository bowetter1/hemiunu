"""Pipeline for fetching, saving, and researching news headlines."""

import hashlib
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional
from dataclasses import dataclass

from factgrid.infrastructure import get_settings
from factgrid.domain.research.models import RawHeadline, ResearchedStory
from factgrid.domain.research.repository import HeadlineRepository, StoryRepository
from factgrid.domain.research.service import ResearchService

logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    """Result of running the research pipeline."""
    headlines_fetched: int
    headlines_saved: int
    stories_created: int
    stories: List[ResearchedStory]
    errors: List[str]


class ResearchPipeline:
    """Pipeline for fetching headlines and researching them with AI."""

    def __init__(self):
        self.headline_repo = HeadlineRepository()
        self.story_repo = StoryRepository()
        self.research_service = ResearchService(
            headline_repo=self.headline_repo,
            story_repo=self.story_repo
        )

    def fetch_headlines_from_newsapi(self) -> List[RawHeadline]:
        """Fetch top headlines from NewsAPI and convert to RawHeadline."""
        import requests
        settings = get_settings()

        url = f"{settings.newsapi_base_url}/{settings.newsapi_endpoint}"
        params = {
            "country": settings.newsapi_country,
            "category": settings.newsapi_category,
            "pageSize": settings.newsapi_page_size,
            "apiKey": settings.newsapi_key,
        }

        try:
            response = requests.get(
                url,
                params=params,
                timeout=settings.newsapi_timeout_seconds,
                headers={"User-Agent": settings.newsapi_user_agent}
            )
            response.raise_for_status()
            data = response.json()

            if data.get("status") != "ok":
                logger.error("NewsAPI error: %s", data.get("message", "Unknown"))
                return []

            articles = data.get("articles", [])
            logger.info("Fetched %d articles from NewsAPI", len(articles))

            # Convert to RawHeadline objects
            headlines = []
            for article in articles:
                # Generate ID from URL
                headline_id = hashlib.sha256(
                    article.get("url", "").encode()
                ).hexdigest()[:16]

                headline = RawHeadline.from_newsapi(article, headline_id)
                headlines.append(headline)

            return headlines

        except requests.RequestException as e:
            logger.error("Failed to fetch from NewsAPI: %s", e)
            return []

    def run(
        self,
        fetch_new: bool = True,
        process_limit: int = 5,
    ) -> PipelineResult:
        """
        Run the full research pipeline.

        Args:
            fetch_new: Whether to fetch new headlines from NewsAPI
            process_limit: Max number of headlines to research

        Returns:
            PipelineResult with stats and created stories
        """
        errors = []
        headlines_fetched = 0
        headlines_saved = 0

        # Step 1: Fetch new headlines (optional)
        if fetch_new:
            logger.info("Step 1: Fetching headlines from NewsAPI...")
            headlines = self.fetch_headlines_from_newsapi()
            headlines_fetched = len(headlines)

            if headlines:
                headlines_saved = self.headline_repo.save_many(headlines)
                logger.info("Saved %d headlines to database", headlines_saved)
            else:
                errors.append("No headlines fetched from NewsAPI")

        # Step 2: Get unprocessed headlines
        logger.info("Step 2: Getting unprocessed headlines...")
        unprocessed = self.headline_repo.get_unprocessed(limit=process_limit)
        logger.info("Found %d unprocessed headlines", len(unprocessed))

        # Step 3: Research each headline with Claude
        logger.info("Step 3: Researching headlines with Claude...")
        stories = []
        for i, headline in enumerate(unprocessed):
            logger.info("[%d/%d] Researching: %s",
                       i + 1, len(unprocessed), headline.title[:50])
            try:
                story = self.research_service.research_and_save(headline)
                if story:
                    stories.append(story)
            except Exception as e:
                error_msg = f"Failed to research '{headline.title[:30]}': {str(e)}"
                logger.error(error_msg)
                errors.append(error_msg)

        logger.info("Pipeline complete: %d stories created", len(stories))

        return PipelineResult(
            headlines_fetched=headlines_fetched,
            headlines_saved=headlines_saved,
            stories_created=len(stories),
            stories=stories,
            errors=errors,
        )

    def get_status(self) -> Dict[str, Any]:
        """Get current pipeline status."""
        return {
            "headlines_total": self.headline_repo.count(),
            "headlines_processed": self.headline_repo.count(processed=True),
            "headlines_pending": self.headline_repo.count(processed=False),
            "stories_total": self.story_repo.count(),
        }
