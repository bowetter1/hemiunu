"""Article routes."""

from fastapi import APIRouter, HTTPException, Query
from typing import List

from factgrid.api.schemas import ArticleResponse, HistoryResponse
from factgrid.domain.articles import ArticleService

router = APIRouter(prefix="/articles", tags=["Articles"])


@router.get("", response_model=List[ArticleResponse])
async def list_articles(
    limit: int = Query(default=10, le=100),
    skip: int = Query(default=0, ge=0),
):
    """List all articles with pagination."""
    try:
        service = ArticleService()
        articles = service.list_articles(limit=limit, skip=skip)

        return [
            ArticleResponse(
                id=article.id,
                article_metadata={
                    "original_url": article.metadata.original_url,
                    "title": article.metadata.title,
                    "source": article.metadata.source,
                    "topic": article.metadata.topic,
                    "initial_timestamp": article.metadata.initial_timestamp,
                },
                current_state={
                    "version": article.current_state.version,
                    "last_updated": article.current_state.last_updated,
                    "grid": [
                        {
                            "id": row.id,
                            "type": row.type,
                            "content": row.content,
                            "source": row.source,
                            "confidence": row.confidence,
                            "status": row.status,
                        }
                        for row in article.current_state.grid
                    ],
                },
                history=[
                    {
                        "version": entry.version,
                        "commit_msg": entry.commit_msg,
                        "diff": entry.diff,
                        "logic": entry.logic,
                        "timestamp": entry.timestamp,
                    }
                    for entry in article.history
                ],
            )
            for article in articles
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{article_id}", response_model=ArticleResponse)
async def get_article(article_id: str):
    """Get a specific article by ID."""
    try:
        service = ArticleService()
        article = service.get_article(article_id)

        if not article:
            raise HTTPException(status_code=404, detail="Article not found")

        return ArticleResponse(
            id=article.id,
            article_metadata={
                "original_url": article.metadata.original_url,
                "title": article.metadata.title,
                "source": article.metadata.source,
                "topic": article.metadata.topic,
                "initial_timestamp": article.metadata.initial_timestamp,
            },
            current_state={
                "version": article.current_state.version,
                "last_updated": article.current_state.last_updated,
                "grid": [
                    {
                        "id": row.id,
                        "type": row.type,
                        "content": row.content,
                        "source": row.source,
                        "confidence": row.confidence,
                        "status": row.status,
                    }
                    for row in article.current_state.grid
                ],
            },
            history=[
                {
                    "version": entry.version,
                    "commit_msg": entry.commit_msg,
                    "diff": entry.diff,
                    "logic": entry.logic,
                    "timestamp": entry.timestamp,
                }
                for entry in article.history
            ],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{article_id}/history", response_model=HistoryResponse)
async def get_article_history(article_id: str):
    """Get version history for a specific article."""
    try:
        service = ArticleService()
        history = service.get_article_history(article_id)

        if not history:
            raise HTTPException(status_code=404, detail="Article not found")

        return HistoryResponse(
            article_id=history["article_id"],
            current_version=history["current_version"],
            history=history["history"],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
