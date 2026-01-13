"""Base news source interface."""

from abc import ABC, abstractmethod
from typing import Any, Dict


class BaseNewsSource(ABC):
    """Abstract base class for news sources."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Return source name."""
        pass

    @abstractmethod
    def fetch(self) -> Dict[str, Any]:
        """Fetch news articles."""
        pass
