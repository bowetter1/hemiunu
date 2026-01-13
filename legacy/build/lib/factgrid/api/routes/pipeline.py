"""Pipeline routes for ingest, judge, and full pipeline."""

from typing import List, Any

from fastapi import APIRouter, HTTPException, Query

from factgrid.api.schemas import IngestResponse, JudgeResponse, PipelineResponse
from factgrid.domain.ingest import IngestService
from factgrid.domain.judge import JudgeService
from factgrid.domain.articles import ArticleService
from factgrid.domain.stories import StoryService
from factgrid.infrastructure import get_settings

router = APIRouter(tags=["Pipeline"])


@router.post("/ingest", response_model=IngestResponse)
async def ingest_news(store_raw: bool = Query(default=True)):
    """Fetch top headlines from NewsAPI."""
    try:
        service = IngestService()

        if store_raw:
            result = service.fetch_and_store_raw()
            return IngestResponse(
                message="Successfully fetched and stored news",
                articles_fetched=result.articles_count,
                raw_payload_id=result.raw_payload_id,
            )

        payload = service.fetch()
        return IngestResponse(
            message="Successfully fetched news",
            articles_fetched=len(payload.get("articles", [])),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/judge", response_model=JudgeResponse)
async def judge_and_store():
    """Fetch news, judge with AI, and store in MongoDB."""
    try:
        ingest_service = IngestService()
        judge_service = JudgeService()
        article_service = ArticleService()
        settings = get_settings()

        # Fetch
        payload = ingest_service.fetch()

        # Judge (pass category for topic classification)
        judged = judge_service.judge_payload(payload, category=settings.newsapi_category)

        # Validate
        for article in judged.get("articles", []):
            errors = judge_service.validate_result(article)
            if errors:
                raise HTTPException(
                    status_code=500,
                    detail=f"Validation errors: {errors}",
                )

        # Store
        article_ids = article_service.store_judged_articles(
            judged,
            source_label="NewsAPI",
            topic=settings.newsapi_category,
        )

        return JudgeResponse(
            message="Successfully judged and stored articles",
            articles_judged=len(article_ids),
            article_ids=article_ids,
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/pipeline", response_model=PipelineResponse)
async def run_full_pipeline():
    """Run full pipeline: ingest -> judge -> store."""
    try:
        ingest_service = IngestService()
        judge_service = JudgeService()
        article_service = ArticleService()
        settings = get_settings()

        # Fetch and store raw
        result = ingest_service.fetch_and_store_raw()
        payload = ingest_service.fetch()
        articles_fetched = len(payload.get("articles", []))

        # Judge (pass category for topic classification)
        judged = judge_service.judge_payload(payload, category=settings.newsapi_category)

        # Store judged
        article_ids = article_service.store_judged_articles(
            judged,
            source_label="NewsAPI",
            topic=settings.newsapi_category,
        )

        return PipelineResponse(
            message="Pipeline completed successfully",
            articles_fetched=articles_fetched,
            articles_judged=len(article_ids),
            article_ids=article_ids,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stories")
async def get_stories(
    source: str = Query(default="research", description="Source: 'research' (MongoDB), 'live' (real-time)"),
    multi_source: bool = Query(default=True, description="Use multiple sources with different biases"),
    limit_per_source: int = Query(default=5, description="Articles per source when using multi-source"),
):
    """
    Get news stories with facts and perspectives.

    source='research' - Returns AI-researched stories from MongoDB (recommended)
    source='live' - Fetches and processes in real-time (slower)
    """
    try:
        # Try research-based stories first (from MongoDB)
        if source == "research":
            from factgrid.domain.research import ResearchService
            research_service = ResearchService()
            result = research_service.get_stories_for_api()

            # If we have stories, return them
            if result.get("stories"):
                return {
                    "message": f"Found {len(result['stories'])} researched stories",
                    "articles_processed": result.get("articles_processed", 0),
                    "sources_used": result.get("sources_used", []),
                    "stories": result["stories"],
                }

        # Fallback to live processing
        ingest_service = IngestService()
        story_service = StoryService()

        # Fetch articles from multiple sources or single source
        if multi_source:
            payload = ingest_service.fetch_multi_source(limit_per_source=limit_per_source)
            sources_used = payload.get("sources_used", [])
        else:
            payload = ingest_service.fetch()
            sources_used = ["NewsAPI"]

        articles = payload.get("articles", [])

        if not articles:
            return {"stories": [], "message": "No articles found", "sources_used": sources_used}

        # Process into stories
        stories = story_service.process_articles(articles)

        return {
            "message": f"Found {len(stories)} stories",
            "articles_processed": len(articles),
            "sources_used": sources_used,
            "stories": [story.to_dict() for story in stories],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/research")
async def run_research(
    fetch: bool = Query(default=True, description="Fetch new headlines from NewsAPI"),
    limit: int = Query(default=5, description="Max headlines to research"),
):
    """
    Run AI research pipeline.

    1. Fetches headlines from NewsAPI
    2. Saves to MongoDB (raw_headlines collection)
    3. Researches each headline with Claude AI
    4. Saves stories to MongoDB (stories collection)
    """
    try:
        from factgrid.domain.research import ResearchPipeline

        pipeline = ResearchPipeline()
        result = pipeline.run(fetch_new=fetch, process_limit=limit)

        return {
            "message": "Research pipeline completed",
            "headlines_fetched": result.headlines_fetched,
            "headlines_saved": result.headlines_saved,
            "stories_created": result.stories_created,
            "stories": [s.to_api_dict() for s in result.stories],
            "errors": result.errors,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/research/status")
async def get_research_status():
    """Get status of the research pipeline."""
    try:
        from factgrid.domain.research import ResearchPipeline

        pipeline = ResearchPipeline()
        status = pipeline.get_status()

        return {
            "message": "Research pipeline status",
            **status,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
