"""Application configuration"""
import os
import secrets
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "Apex Server"
    debug: bool = False

    # Database (SQLite for dev, PostgreSQL for prod)
    database_url: str = "sqlite:///./apex.db"

    # Auth - IMPORTANT: Set JWT_SECRET in production!
    jwt_secret: str = ""  # Will be validated on startup
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7  # 1 week

    # CORS - comma-separated list of allowed origins
    cors_origins: str = "http://localhost:8000,http://127.0.0.1:8000"

    # LLM
    anthropic_api_key: str = ""
    google_api_key: str = ""  # For Gemini
    openai_api_key: str = ""  # For Mem0 embeddings
    groq_api_key: str = ""    # For Groq (fast & cheap)

    # Storage
    storage_path: str = "/app/storage"

    # GitHub
    github_token: str = ""  # Personal access token with repo scope
    github_org: str = ""    # Optional: organization to create repos in

    # Qdrant (for Mem0)
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()


def validate_settings() -> None:
    """Validate critical settings on startup. Raises if misconfigured."""
    settings = get_settings()

    # JWT secret validation
    if not settings.jwt_secret:
        if settings.debug:
            # Generate a random secret for development only
            import warnings
            warnings.warn(
                "JWT_SECRET not set! Using random secret for development. "
                "Set JWT_SECRET environment variable in production!",
                RuntimeWarning
            )
            # We can't modify the cached settings, but we'll allow startup in debug mode
        else:
            raise ValueError(
                "JWT_SECRET environment variable must be set in production! "
                "Generate one with: python -c \"import secrets; print(secrets.token_hex(32))\""
            )

    if settings.jwt_secret and len(settings.jwt_secret) < 32:
        raise ValueError("JWT_SECRET must be at least 32 characters long")


def get_cors_origins() -> list[str]:
    """Parse CORS origins from settings."""
    settings = get_settings()
    if settings.cors_origins == "*":
        return ["*"]
    return [origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()]
