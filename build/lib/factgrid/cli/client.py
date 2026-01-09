"""HTTP client for FactGrid API."""

from typing import Any, Dict, List, Optional
import httpx

DEFAULT_BASE_URL = "https://api-production-d232.up.railway.app"


class FactGridClient:
    """Client for interacting with FactGrid API."""

    def __init__(self, base_url: str = DEFAULT_BASE_URL, timeout: float = 120.0):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def _request(
        self,
        method: str,
        path: str,
        params: Optional[Dict] = None,
        json: Optional[Dict] = None,
    ) -> Dict[str, Any]:
        """Make HTTP request to API."""
        url = f"{self.base_url}{path}"
        with httpx.Client(timeout=self.timeout) as client:
            response = client.request(method, url, params=params, json=json)
            response.raise_for_status()
            return response.json()

    def health(self) -> Dict[str, Any]:
        """Check API health."""
        return self._request("GET", "/health")

    def ingest(self, store_raw: bool = True) -> Dict[str, Any]:
        """Fetch news from NewsAPI."""
        return self._request("POST", "/ingest", params={"store_raw": store_raw})

    def judge(self) -> Dict[str, Any]:
        """Fetch, judge with AI, and store articles."""
        return self._request("POST", "/judge")

    def pipeline(self) -> Dict[str, Any]:
        """Run full pipeline: ingest -> judge -> store."""
        return self._request("POST", "/pipeline")

    def list_articles(self, limit: int = 10, skip: int = 0) -> List[Dict[str, Any]]:
        """List all articles."""
        return self._request("GET", "/articles", params={"limit": limit, "skip": skip})

    def get_article(self, article_id: str) -> Dict[str, Any]:
        """Get specific article by ID."""
        return self._request("GET", f"/articles/{article_id}")

    def get_article_history(self, article_id: str) -> Dict[str, Any]:
        """Get article version history."""
        return self._request("GET", f"/articles/{article_id}/history")

    def get_stories(self) -> Dict[str, Any]:
        """Get clustered stories with fact grids."""
        return self._request("GET", "/stories")
