"""Research domain for AI-powered news analysis."""

from factgrid.domain.research.models import (
    RawHeadline,
    ResearchedStory,
    ResearchFact,
    ResearchPerspective,
    ResearchQuote,
)
from factgrid.domain.research.service import ResearchService
from factgrid.domain.research.repository import HeadlineRepository, StoryRepository
from factgrid.domain.research.pipeline import ResearchPipeline, PipelineResult

__all__ = [
    "RawHeadline",
    "ResearchedStory",
    "ResearchFact",
    "ResearchPerspective",
    "ResearchQuote",
    "ResearchService",
    "HeadlineRepository",
    "StoryRepository",
    "ResearchPipeline",
    "PipelineResult",
]
