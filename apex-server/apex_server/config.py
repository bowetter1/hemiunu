"""Application configuration"""
import os
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "Apex Server"
    debug: bool = False

    # Database (SQLite for dev, PostgreSQL for prod)
    database_url: str = "sqlite:///./apex.db"

    # Auth
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 1 week

    # LLM
    anthropic_api_key: str = ""
    google_api_key: str = ""  # For Gemini
    openai_api_key: str = ""  # For Mem0 embeddings

    # Storage
    storage_path: str = "/app/storage"

    # Qdrant (for Mem0)
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
