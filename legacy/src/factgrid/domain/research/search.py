"""Webbsokning via Brave och extrahering av artikeltext."""

from dataclasses import dataclass
import logging
import re
from typing import Dict, List
from urllib.parse import urlparse

import requests

logger = logging.getLogger(__name__)


@dataclass
class SearchResult:
    """En strukturerad soktraff for en artikel."""
    url: str
    title: str
    snippet: str
    source_domain: str
    bias_category: str

    def to_dict(self) -> Dict[str, str]:
        """Konvertera till dict for vidare hantering."""
        return {
            "url": self.url,
            "title": self.title,
            "snippet": self.snippet,
            "source_domain": self.source_domain,
            "bias_category": self.bias_category,
        }


class WebSearchService:
    """Service for att sokka kallsidor och hamta artikeltext."""

    BIAS_SOURCES = {
        "right": ["foxnews.com", "nypost.com"],
        "left": ["cnn.com", "msnbc.com"],
        "center": ["reuters.com", "apnews.com"],
        "international": ["bbc.com", "aljazeera.com"],
    }

    def __init__(
        self,
        base_url: str = "https://api.search.brave.com/res/v1/web/search",
        timeout_seconds: int = 10,
    ):
        self.base_url = base_url
        self.timeout_seconds = timeout_seconds

    def search_sources(self, headline: str, api_key: str) -> List[dict]:
        """Sok per bias-kategori med site-filter och returnera traeffar."""
        if not headline:
            logger.warning("Ingen rubrik angiven for sokning.")
            return []
        if not api_key:
            logger.warning("Ingen API-nyckel angiven for Brave-sokning.")
            return []

        headers = {
            "Accept": "application/json",
            "X-Subscription-Token": api_key,
            "User-Agent": "factgrid/1.0",
        }

        results: List[dict] = []
        seen_urls = set()

        for bias_category, domains in self.BIAS_SOURCES.items():
            site_filter = " OR ".join([f"site:{domain}" for domain in domains])
            query = f"{headline} {site_filter}"

            params = {
                "q": query,
                "count": 5,
            }

            try:
                response = requests.get(
                    self.base_url,
                    headers=headers,
                    params=params,
                    timeout=self.timeout_seconds,
                )
            except requests.RequestException as exc:
                logger.warning(
                    "Misslyckades att anropa Brave for kategori=%s: %s",
                    bias_category,
                    exc,
                )
                continue

            if response.status_code != 200:
                logger.warning(
                    "Brave svarade med %s for kategori=%s: %s",
                    response.status_code,
                    bias_category,
                    response.text[:200],
                )
                continue

            try:
                payload = response.json()
            except ValueError as exc:
                logger.warning(
                    "Kunde inte tolka JSON for kategori=%s: %s",
                    bias_category,
                    exc,
                )
                continue

            web_results = payload.get("web", {}).get("results", [])
            logger.info(
                "Brave gav %d traeffar for kategori=%s",
                len(web_results),
                bias_category,
            )

            for item in web_results:
                url = item.get("url", "")
                if not url or url in seen_urls:
                    continue

                title = item.get("title", "") or ""
                description = item.get("description", "") or ""
                extra_snippets = item.get("extra_snippets") or []
                snippet = description or (extra_snippets[0] if extra_snippets else "")

                domain = urlparse(url).netloc or ""
                if domain.startswith("www."):
                    domain = domain[4:]

                result = SearchResult(
                    url=url,
                    title=title,
                    snippet=snippet,
                    source_domain=domain,
                    bias_category=bias_category,
                )
                results.append(result.to_dict())
                seen_urls.add(url)

        return results

    def fetch_article_text(self, url: str) -> str:
        """Hamta artikeltext med requests och readability-lxml."""
        if not url:
            logger.warning("Ingen URL angiven for artikelhamtning.")
            return ""

        try:
            response = requests.get(
                url,
                headers={"User-Agent": "factgrid/1.0"},
                timeout=self.timeout_seconds,
            )
            response.raise_for_status()
        except requests.RequestException as exc:
            logger.warning("Misslyckades att hamta artikel: %s", exc)
            return ""

        try:
            from readability import Document
        except ImportError:
            logger.error("readability-lxml ar inte installerat.")
            return ""

        try:
            doc = Document(response.text)
            summary_html = doc.summary()
        except Exception as exc:
            logger.exception("Kunde inte extrahera artikel via readability: %s", exc)
            return ""

        text = ""
        try:
            from lxml import html as lxml_html

            tree = lxml_html.fromstring(summary_html)
            text = tree.text_content()
        except Exception:
            # Enkel fallback om lxml-tolkning misslyckas.
            text = re.sub(r"<[^>]+>", " ", summary_html)

        text = " ".join(text.split())
        if not text:
            logger.info("Ingen artikeltext kunde extraheras fran %s", url)
        return text
