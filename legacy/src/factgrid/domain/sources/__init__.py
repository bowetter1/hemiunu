"""News sources with bias labels."""

from dataclasses import dataclass
from typing import List


@dataclass
class NewsSource:
    """A news source with its properties."""
    name: str
    bias: str  # left, right, center
    rss_url: str
    country: str = "US"
    language: str = "en"
    enabled: bool = True


# Predefined news sources
SOURCES: List[NewsSource] = [
    # US - Right-leaning
    NewsSource(
        name="Fox News",
        bias="right",
        rss_url="https://moxie.foxnews.com/google-publisher/politics.xml",
        country="US",
    ),
    # US - Left-leaning
    NewsSource(
        name="CNN",
        bias="left",
        rss_url="http://rss.cnn.com/rss/cnn_allpolitics.rss",
        country="US",
    ),
    NewsSource(
        name="NPR",
        bias="left",
        rss_url="https://feeds.npr.org/1001/rss.xml",
        country="US",
    ),
    # US/UK - Center
    NewsSource(
        name="Reuters",
        bias="center",
        rss_url="https://www.reutersagency.com/feed/?best-topics=political-general&post_type=best",
        country="US",
    ),
    NewsSource(
        name="BBC News",
        bias="center",
        rss_url="http://feeds.bbci.co.uk/news/world/rss.xml",
        country="UK",
    ),
    NewsSource(
        name="AP News",
        bias="center",
        rss_url="https://rsshub.app/apnews/topics/apf-politics",
        country="US",
    ),
    # UK - Left-leaning
    NewsSource(
        name="The Guardian",
        bias="left",
        rss_url="https://www.theguardian.com/world/rss",
        country="UK",
    ),
    # International
    NewsSource(
        name="Al Jazeera",
        bias="center",
        rss_url="https://www.aljazeera.com/xml/rss/all.xml",
        country="QA",
    ),
    # Sweden
    NewsSource(
        name="SVT Nyheter",
        bias="center",
        rss_url="https://www.svt.se/nyheter/rss.xml",
        country="SE",
        language="sv",
    ),
]


def get_enabled_sources(
    language: str = None,
    country: str = None,
    bias: str = None,
) -> List[NewsSource]:
    """Get enabled sources, optionally filtered."""
    sources = [s for s in SOURCES if s.enabled]

    if language:
        sources = [s for s in sources if s.language == language]
    if country:
        sources = [s for s in sources if s.country == country]
    if bias:
        sources = [s for s in sources if s.bias == bias]

    return sources


def get_balanced_sources(limit_per_bias: int = 2) -> List[NewsSource]:
    """Get a balanced mix of sources from different biases."""
    result = []
    for bias in ["left", "center", "right"]:
        bias_sources = [s for s in SOURCES if s.enabled and s.bias == bias]
        result.extend(bias_sources[:limit_per_bias])
    return result
