"""Configuration loader for FactGrid."""

from dataclasses import dataclass
from functools import lru_cache
import os
from typing import Optional

from dotenv import load_dotenv


@dataclass(frozen=True)
class Settings:
    """Application settings."""

    # NewsAPI
    newsapi_key: str
    newsapi_base_url: str
    newsapi_endpoint: str
    newsapi_language: str
    newsapi_country: str
    newsapi_category: str
    newsapi_page_size: int
    newsapi_timeout_seconds: int
    newsapi_user_agent: str

    # Judge
    judge_provider: str
    judge_model: str
    judge_temperature: float
    judge_max_tokens: int
    judge_timeout_seconds: int

    # OpenAI
    openai_api_key: str

    # MongoDB
    mongo_uri: str
    mongo_db: str
    mongo_raw_collection: str
    mongo_articles_collection: str
    mongo_headlines_collection: str
    mongo_stories_collection: str

    # Anthropic
    anthropic_api_key: str

    # Brave Search (optional - for multi-source analysis)
    brave_api_key: str


def _get_int(name: str, default: int) -> int:
    """Get integer from environment variable."""
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer") from exc


def _get_float(name: str, default: float) -> float:
    """Get float from environment variable."""
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return float(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be a float") from exc


def load_settings(dotenv_path: Optional[str] = None) -> Settings:
    """Load settings from environment with safe defaults."""
    load_dotenv(dotenv_path)

    newsapi_key = os.getenv("NEWSAPI_KEY", "").strip()
    if not newsapi_key:
        raise ValueError("NEWSAPI_KEY is required")

    return Settings(
        newsapi_key=newsapi_key,
        newsapi_base_url=os.getenv("NEWSAPI_BASE_URL", "https://newsapi.org/v2"),
        newsapi_endpoint=os.getenv("NEWSAPI_ENDPOINT", "top-headlines"),
        newsapi_language=os.getenv("NEWSAPI_LANGUAGE", "sv"),
        newsapi_country=os.getenv("NEWSAPI_COUNTRY", "se"),
        newsapi_category=os.getenv("NEWSAPI_CATEGORY", "business"),
        newsapi_page_size=_get_int("NEWSAPI_PAGE_SIZE", 10),
        newsapi_timeout_seconds=_get_int("NEWSAPI_TIMEOUT_SECONDS", 20),
        newsapi_user_agent=os.getenv("NEWSAPI_USER_AGENT", "FactGrid/0.1"),
        judge_provider=os.getenv("JUDGE_PROVIDER", "mock"),
        judge_model=os.getenv("JUDGE_MODEL", "gpt-4o-mini"),
        judge_temperature=_get_float("JUDGE_TEMPERATURE", 0.2),
        judge_max_tokens=_get_int("JUDGE_MAX_TOKENS", 1200),
        judge_timeout_seconds=_get_int("JUDGE_TIMEOUT_SECONDS", 30),
        openai_api_key=os.getenv("OPENAI_API_KEY", ""),
        mongo_uri=os.getenv("MONGO_URI", "mongodb://localhost:27017"),
        mongo_db=os.getenv("MONGO_DB", "factgrid"),
        mongo_raw_collection=os.getenv("MONGO_RAW_COLLECTION", "raw_payloads"),
        mongo_articles_collection=os.getenv("MONGO_ARTICLES_COLLECTION", "articles"),
        mongo_headlines_collection=os.getenv("MONGO_HEADLINES_COLLECTION", "raw_headlines"),
        mongo_stories_collection=os.getenv("MONGO_STORIES_COLLECTION", "stories"),
        anthropic_api_key=os.getenv("ANTHROPIC_API_KEY", ""),
        brave_api_key=os.getenv("BRAVE_API_KEY", ""),
    )


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return load_settings()
