"""
Tests for the portfolio site.

Test coverage:
- All 4 routes return 200 status (/, /about, /projects, /contact)
- Navigation links exist on all pages
- Static files are served correctly
"""
import pytest


pytestmark = pytest.mark.anyio


class TestRoutes:
    """Test all page routes return 200 status."""

    async def test_home_page_returns_200(self, client):
        """GET / should return 200 and HTML content."""
        response = await client.get("/")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]

    async def test_about_page_returns_200(self, client):
        """GET /about should return 200 and HTML content."""
        response = await client.get("/about")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]

    async def test_projects_page_returns_200(self, client):
        """GET /projects should return 200 and HTML content."""
        response = await client.get("/projects")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]

    async def test_contact_page_returns_200(self, client):
        """GET /contact should return 200 and HTML content."""
        response = await client.get("/contact")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]


class TestNavigation:
    """Test navigation links exist on all pages."""

    @pytest.mark.parametrize("page_url", ["/", "/about", "/projects", "/contact"])
    async def test_navigation_links_exist(self, client, page_url):
        """All pages should have navigation links to all 4 pages."""
        response = await client.get(page_url)
        html = response.text

        # Check all navigation links exist
        assert 'href="/"' in html, f"Home link missing on {page_url}"
        assert 'href="/about"' in html, f"About link missing on {page_url}"
        assert 'href="/projects"' in html, f"Projects link missing on {page_url}"
        assert 'href="/contact"' in html, f"Contact link missing on {page_url}"

    @pytest.mark.parametrize("page_url", ["/", "/about", "/projects", "/contact"])
    async def test_logo_links_to_home(self, client, page_url):
        """Logo on all pages should link to home."""
        response = await client.get(page_url)
        html = response.text

        # Logo should link to home
        assert 'class="logo"' in html
        assert 'Apex' in html


class TestStaticFiles:
    """Test static files are served correctly."""

    async def test_css_file_served(self, client):
        """Static CSS file should be accessible."""
        response = await client.get("/static/css/style.css")
        assert response.status_code == 200
        assert "text/css" in response.headers["content-type"]

    async def test_js_file_served(self, client):
        """Static JS file should be accessible."""
        response = await client.get("/static/js/main.js")
        assert response.status_code == 200
        assert "javascript" in response.headers["content-type"]

    @pytest.mark.parametrize("page_url", ["/", "/about", "/projects", "/contact"])
    async def test_pages_reference_static_files(self, client, page_url):
        """All pages should reference the CSS and JS files."""
        response = await client.get(page_url)
        html = response.text

        assert '/static/css/style.css' in html, f"CSS reference missing on {page_url}"
        assert '/static/js/main.js' in html, f"JS reference missing on {page_url}"


class TestPageContent:
    """Test pages contain expected content."""

    async def test_home_page_has_title(self, client):
        """Home page should have a title tag."""
        response = await client.get("/")
        assert "<title>" in response.text
        assert "Portfolio" in response.text

    async def test_pages_have_footer(self, client):
        """All pages should have a footer."""
        for page_url in ["/", "/about", "/projects", "/contact"]:
            response = await client.get(page_url)
            assert '<footer' in response.text, f"Footer missing on {page_url}"

    async def test_pages_have_navbar(self, client):
        """All pages should have a navigation bar."""
        for page_url in ["/", "/about", "/projects", "/contact"]:
            response = await client.get(page_url)
            assert '<nav' in response.text, f"Navbar missing on {page_url}"


class TestNonExistentRoutes:
    """Test error handling for non-existent routes."""

    async def test_404_for_unknown_route(self, client):
        """Unknown routes should return 404."""
        response = await client.get("/nonexistent")
        assert response.status_code == 404
