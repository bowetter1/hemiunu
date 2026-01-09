"""News sources."""

from factgrid.domain.ingest.sources.base import BaseNewsSource
from factgrid.domain.ingest.sources.newsapi import NewsAPISource

__all__ = ["BaseNewsSource", "NewsAPISource"]
