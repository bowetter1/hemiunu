"""Application configuration"""
import os
from typing import Optional
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "Apex Server"
    debug: bool = True
    allow_dev_token: Optional[bool] = None

    # Database (SQLite for dev, PostgreSQL for prod)
    # Railway sets DATABASE_URL automatically when you add PostgreSQL
    database_url: str = "sqlite:///./apex.db"

    # File storage (Railway Volume)
    # Railway: Mount volume at /data
    data_dir: str = "/data"

    # Auth
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 1 week

    # LLM
    anthropic_api_key: str = ""
    google_api_key: str = ""  # For Gemini
    openai_api_key: str = ""  # For Mem0 embeddings
    pexels_api_key: str = ""  # For stock photos

    # Storage
    storage_path: str = "/app/storage"

    # Qdrant (for Mem0)
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333

    class Config:
        env_file = ".env"

    @property
    def dev_token_enabled(self) -> bool:
        """Allow dev token by default in debug mode unless explicitly overridden."""
        if self.allow_dev_token is None:
            return self.debug
        return self.allow_dev_token


@lru_cache
def get_settings() -> Settings:
    return Settings()
