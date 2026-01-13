"""RSS feed parser for fetching news from multiple sources."""

import logging
from dataclasses import dataclass
from typing import List, Optional
from datetime import datetime

import feedparser

logger = logging.getLogger(__name__)


@dataclass
class RSSArticle:
    """An article from an RSS feed."""
    title: str
    description: str
    url: str
    source_name: str
    source_bias: str
    published: Optional[str] = None
    content: str = ""
    image_url: Optional[str] = None


def parse_rss_feed(
    feed_url: str,
    source_name: str,
    source_bias: str,
    limit: int = 10
) -> List[RSSArticle]:
    """Parse an RSS feed and return articles."""
    try:
        feed = feedparser.parse(feed_url)

        if feed.bozo and not feed.entries:
            logger.warning(f"Failed to parse RSS feed: {feed_url}")
            return []

        articles = []
        for entry in feed.entries[:limit]:
            # Get content
            content = ""
            if hasattr(entry, 'content') and entry.content:
                content = entry.content[0].get('value', '')
            elif hasattr(entry, 'summary'):
                content = entry.summary

            # Get published date
            published = None
            if hasattr(entry, 'published'):
                published = entry.published
            elif hasattr(entry, 'updated'):
                published = entry.updated

            # Get image URL
            image_url = None
            if hasattr(entry, 'media_content') and entry.media_content:
                image_url = entry.media_content[0].get('url')
            elif hasattr(entry, 'media_thumbnail') and entry.media_thumbnail:
                image_url = entry.media_thumbnail[0].get('url')
            elif hasattr(entry, 'enclosures') and entry.enclosures:
                for enc in entry.enclosures:
                    if enc.get('type', '').startswith('image/'):
                        image_url = enc.get('href') or enc.get('url')
                        break
            # Try to find image in content
            if not image_url and content:
                import re
                img_match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', content)
                if img_match:
                    image_url = img_match.group(1)

            articles.append(RSSArticle(
                title=entry.get('title', ''),
                description=entry.get('summary', '')[:500] if entry.get('summary') else '',
                url=entry.get('link', ''),
                source_name=source_name,
                source_bias=source_bias,
                published=published,
                content=content[:2000] if content else '',
                image_url=image_url,
            ))

        logger.info(f"Fetched {len(articles)} articles from {source_name}")
        return articles

    except Exception as e:
        logger.error(f"Error parsing RSS feed {feed_url}: {e}")
        return []


def rss_to_newsapi_format(articles: List[RSSArticle]) -> List[dict]:
    """Convert RSS articles to NewsAPI-compatible format."""
    return [
        {
            "title": a.title,
            "description": a.description,
            "url": a.url,
            "content": a.content,
            "publishedAt": a.published,
            "urlToImage": a.image_url,
            "source": {
                "name": a.source_name,
                "bias": a.source_bias,
            }
        }
        for a in articles
    ]
