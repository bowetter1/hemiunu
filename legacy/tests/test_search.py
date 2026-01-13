"""
Tester för WebSearchService i FactGrid.

Testar sökning via Brave API och artikelextraktion med readability-lxml.
"""

import pytest
from unittest.mock import Mock, patch
import requests

from factgrid.domain.research.search import WebSearchService, SearchResult


class TestSearchResult:
    """Tester för SearchResult dataclass."""

    def test_search_result_creation(self):
        """Testa att SearchResult kan skapas med alla fält."""
        result = SearchResult(
            url="https://foxnews.com/article",
            title="Test Article",
            snippet="This is a test snippet",
            source_domain="foxnews.com",
            bias_category="right",
        )

        assert result.url == "https://foxnews.com/article"
        assert result.title == "Test Article"
        assert result.snippet == "This is a test snippet"
        assert result.source_domain == "foxnews.com"
        assert result.bias_category == "right"

    def test_search_result_to_dict(self):
        """Testa att to_dict returnerar korrekt dictionary."""
        result = SearchResult(
            url="https://cnn.com/news",
            title="CNN News",
            snippet="Breaking news",
            source_domain="cnn.com",
            bias_category="left",
        )

        d = result.to_dict()

        assert d["url"] == "https://cnn.com/news"
        assert d["title"] == "CNN News"
        assert d["bias_category"] == "left"


class TestWebSearchServiceBiasSources:
    """Tester för BIAS_SOURCES konfiguration."""

    def test_bias_sources_has_all_categories(self):
        """Verifiera att alla bias-kategorier finns."""
        service = WebSearchService()
        categories = set(service.BIAS_SOURCES.keys())

        assert "right" in categories
        assert "left" in categories
        assert "center" in categories
        assert "international" in categories

    def test_bias_sources_contain_expected_domains(self):
        """Verifiera att förväntade domäner finns."""
        service = WebSearchService()

        assert "foxnews.com" in service.BIAS_SOURCES["right"]
        assert "cnn.com" in service.BIAS_SOURCES["left"]
        assert "reuters.com" in service.BIAS_SOURCES["center"]
        assert "bbc.com" in service.BIAS_SOURCES["international"]


class TestSearchSources:
    """Tester för search_sources metoden."""

    @patch("requests.get")
    def test_search_sources_returns_empty_on_missing_headline(self, mock_get):
        """Testa att tom lista returneras utan rubrik."""
        service = WebSearchService()
        results = service.search_sources("", "test-api-key")

        assert results == []
        mock_get.assert_not_called()

    @patch("requests.get")
    def test_search_sources_returns_empty_on_missing_api_key(self, mock_get):
        """Testa att tom lista returneras utan API-nyckel."""
        service = WebSearchService()
        results = service.search_sources("Test headline", "")

        assert results == []
        mock_get.assert_not_called()

    @patch("requests.get")
    def test_search_sources_builds_correct_query(self, mock_get):
        """Verifiera att site:-filter byggs korrekt."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"web": {"results": []}}
        mock_get.return_value = mock_response

        service = WebSearchService()
        service.search_sources("Trump tariffs", "test-api-key")

        # Verifiera att Brave API anropades för varje kategori
        assert mock_get.call_count == 4  # 4 bias-kategorier

        # Kontrollera att site:-filter finns i query
        for call in mock_get.call_args_list:
            params = call.kwargs.get("params") or call[1].get("params")
            assert "site:" in params["q"]

    @patch("requests.get")
    def test_search_sources_parses_brave_response(self, mock_get):
        """Testa att Brave API-svar parsas korrekt."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "web": {
                "results": [
                    {
                        "url": "https://foxnews.com/article",
                        "title": "Fox News Article",
                        "description": "Article description",
                    }
                ]
            }
        }
        mock_get.return_value = mock_response

        service = WebSearchService()
        results = service.search_sources("Test", "api-key")

        assert len(results) > 0
        # Första resultat borde vara från right-kategorin (foxnews)
        fox_results = [r for r in results if r["source_domain"] == "foxnews.com"]
        assert len(fox_results) > 0

    @patch("requests.get")
    def test_search_sources_handles_api_error(self, mock_get):
        """Testa att API-fel hanteras gracefully."""
        mock_get.side_effect = requests.RequestException("Connection failed")

        service = WebSearchService()
        results = service.search_sources("Test", "api-key")

        # Ska returnera tom lista istället för att krascha
        assert results == []

    @patch("requests.get")
    def test_search_sources_handles_bad_status_code(self, mock_get):
        """Testa att icke-200 status hanteras."""
        mock_response = Mock()
        mock_response.status_code = 429  # Rate limit
        mock_response.text = "Rate limit exceeded"
        mock_get.return_value = mock_response

        service = WebSearchService()
        results = service.search_sources("Test", "api-key")

        # Ska fortsätta med andra kategorier
        assert isinstance(results, list)

    @patch("requests.get")
    def test_search_sources_deduplicates_urls(self, mock_get):
        """Verifiera att samma URL inte returneras flera gånger."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "web": {
                "results": [
                    {"url": "https://reuters.com/article1", "title": "Article", "description": "Desc"},
                    {"url": "https://reuters.com/article1", "title": "Article", "description": "Desc"},  # Duplicate
                ]
            }
        }
        mock_get.return_value = mock_response

        service = WebSearchService()
        results = service.search_sources("Test", "api-key")

        urls = [r["url"] for r in results]
        assert len(urls) == len(set(urls))  # Inga duplicates


class TestFetchArticleText:
    """Tester för fetch_article_text metoden."""

    @patch("requests.get")
    def test_fetch_article_text_returns_empty_on_missing_url(self, mock_get):
        """Testa att tom sträng returneras utan URL."""
        service = WebSearchService()
        text = service.fetch_article_text("")

        assert text == ""
        mock_get.assert_not_called()

    @patch("requests.get")
    def test_fetch_article_text_handles_network_error(self, mock_get):
        """Testa att nätverksfel hanteras."""
        mock_get.side_effect = requests.RequestException("Connection failed")

        service = WebSearchService()
        text = service.fetch_article_text("https://example.com/article")

        assert text == ""

    @patch("requests.get")
    def test_fetch_article_text_uses_correct_user_agent(self, mock_get):
        """Verifiera att korrekt User-Agent används."""
        mock_response = Mock()
        mock_response.text = "<html><body><p>Article text</p></body></html>"
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        service = WebSearchService()
        service.fetch_article_text("https://example.com/article")

        call_args = mock_get.call_args
        headers = call_args.kwargs.get("headers") or call_args[1].get("headers")

        assert "factgrid" in headers.get("User-Agent", "").lower()


class TestIntegration:
    """Integrationstester för vanliga användningsfall."""

    @patch("requests.get")
    def test_full_search_workflow(self, mock_get):
        """Testa ett komplett sökarbetsflöde."""
        # Mock Brave API-svar
        brave_response = Mock()
        brave_response.status_code = 200
        brave_response.json.return_value = {
            "web": {
                "results": [
                    {
                        "url": "https://reuters.com/us-tariffs",
                        "title": "US Imposes New Tariffs",
                        "description": "The United States announced new tariffs...",
                    }
                ]
            }
        }
        mock_get.return_value = brave_response

        service = WebSearchService()
        results = service.search_sources("US tariffs China", "test-api-key")

        assert len(results) > 0
        assert all("url" in r for r in results)
        assert all("bias_category" in r for r in results)


# ============================================================================
# Fixtures
# ============================================================================

@pytest.fixture
def web_search_service():
    """Skapar en WebSearchService-instans för tester."""
    return WebSearchService()


@pytest.fixture
def mock_brave_response():
    """Returnerar ett exempel på Brave API-svar."""
    return {
        "web": {
            "results": [
                {
                    "url": "https://foxnews.com/politics/tariffs",
                    "title": "Trump Tariffs Policy",
                    "description": "Analysis of the tariff policy...",
                },
                {
                    "url": "https://cnn.com/economy/trade-war",
                    "title": "Trade War Impacts",
                    "description": "Economic analysis of trade tensions...",
                },
            ]
        }
    }
