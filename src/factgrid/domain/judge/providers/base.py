"""Base judge provider interface."""

from abc import ABC, abstractmethod
from typing import Any, Dict


class BaseJudgeProvider(ABC):
    """Abstract base class for judge providers."""

    @abstractmethod
    def judge(self, article: Dict[str, Any]) -> Dict[str, Any]:
        """Judge an article and return structured grid."""
        pass
