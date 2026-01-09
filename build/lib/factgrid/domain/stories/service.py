"""Story service for clustering and fact extraction."""

import json
import hashlib
import logging
from pathlib import Path
from typing import Any, Dict, List

from openai import OpenAI

from factgrid.infrastructure import get_settings
from factgrid.domain.stories.models import (
    Story, StoryClusterResult, Fact, Opinion, Quote, Perspective
)
from factgrid.shared import utc_now, safe_text

logger = logging.getLogger(__name__)

PROMPTS_DIR = Path(__file__).parent / "prompts"


class StoryService:
    """Service for clustering articles into stories and extracting facts."""

    def __init__(self):
        settings = get_settings()
        self.client = OpenAI(api_key=settings.openai_api_key)
        self.model = settings.judge_model
        self.cluster_prompt = (PROMPTS_DIR / "cluster.txt").read_text()
        self.extract_prompt = (PROMPTS_DIR / "extract.txt").read_text()

    def cluster_articles(self, articles: List[Dict[str, Any]]) -> StoryClusterResult:
        """Cluster articles into stories based on content similarity."""
        if not articles:
            return StoryClusterResult(stories=[], unclustered_count=0)

        # Prepare article summaries for clustering
        article_summaries = []
        for i, article in enumerate(articles):
            article_summaries.append({
                "index": i,
                "title": safe_text(article.get("title", "")),
                "description": safe_text(article.get("description", "")),
                "source": safe_text((article.get("source") or {}).get("name", "")),
            })

        # Call AI for clustering
        prompt = self.cluster_prompt.replace(
            "{{ARTICLES_JSON}}",
            json.dumps(article_summaries, indent=2)
        )

        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {
                    "role": "system",
                    "content": "You are a news analyst that groups related articles. Return ONLY valid JSON.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_tokens=2000,
            response_format={"type": "json_object"},
        )

        result = json.loads(response.choices[0].message.content)

        # Build Story objects
        stories = []
        clustered_indices = set()

        for story_data in result.get("stories", []):
            indices = story_data.get("article_indices", [])
            if len(indices) < 2:
                continue

            story_id = hashlib.sha256(
                story_data.get("name", "").encode()
            ).hexdigest()[:16]

            story = Story(
                id=story_id,
                name=story_data.get("name", "Unknown Story"),
                summary=story_data.get("summary", ""),
                article_indices=indices,
                articles=[articles[i] for i in indices if i < len(articles)],
            )
            stories.append(story)
            clustered_indices.update(indices)

        unclustered = len(articles) - len(clustered_indices)

        return StoryClusterResult(stories=stories, unclustered_count=unclustered)

    def extract_story_grid(self, story: Story) -> Story:
        """Extract facts and perspectives for a story."""
        if not story.articles:
            return story

        # Combine article content
        combined_content = []
        for article in story.articles:
            source_name = (article.get("source") or {}).get("name", "Unknown")
            combined_content.append(
                f"[Source: {source_name}]\n"
                f"Title: {article.get('title', '')}\n"
                f"Description: {article.get('description', '')}\n"
                f"Content: {article.get('content', '')}\n"
            )

        articles_text = "\n---\n".join(combined_content)

        # Build prompt
        prompt = self.extract_prompt.replace(
            "{{STORY_NAME}}", story.name
        ).replace(
            "{{STORY_SUMMARY}}", story.summary
        ).replace(
            "{{ARTICLES_CONTENT}}", articles_text[:8000]  # Limit content size
        )

        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {
                    "role": "system",
                    "content": "You are The Judge, extracting facts and perspectives. Return ONLY valid JSON.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.2,
            max_tokens=3000,
            response_format={"type": "json_object"},
        )

        result = json.loads(response.choices[0].message.content)

        # Parse facts
        facts = []
        for f in result.get("facts", []):
            facts.append(Fact(
                content=f.get("content", ""),
                source=f.get("source", ""),
                confidence=f.get("confidence", 0.5),
                status=f.get("status", "UNVERIFIED"),
            ))

        # Parse perspectives
        perspectives = []
        for p in result.get("perspectives", []):
            opinions = [
                Opinion(
                    content=o.get("content", ""),
                    source=o.get("source", ""),
                    affiliation=o.get("affiliation", ""),
                )
                for o in p.get("opinions", [])
            ]
            quotes = [
                Quote(
                    content=q.get("content", ""),
                    source=q.get("source", ""),
                    role=q.get("role", ""),
                )
                for q in p.get("quotes", [])
            ]
            perspectives.append(Perspective(
                perspective=p.get("perspective", "Neutral"),
                label=p.get("label", p.get("perspective", "Neutral")),
                opinions=opinions,
                quotes=quotes,
            ))

        story.facts = facts
        story.perspectives = perspectives
        return story

    def process_articles(self, articles: List[Dict[str, Any]]) -> List[Story]:
        """Full pipeline: cluster articles and extract grids for each story."""
        logger.info("Clustering %d articles into stories...", len(articles))

        # Step 1: Cluster
        cluster_result = self.cluster_articles(articles)
        logger.info(
            "Found %d stories, %d unclustered articles",
            len(cluster_result.stories),
            cluster_result.unclustered_count,
        )

        # Step 2: Extract grid for each story
        stories = []
        for story in cluster_result.stories:
            logger.info("Extracting perspectives for story: %s", story.name)
            enriched_story = self.extract_story_grid(story)
            stories.append(enriched_story)

        return stories
