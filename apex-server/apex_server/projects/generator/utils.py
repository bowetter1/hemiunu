"""Utility functions for the generator"""
import re
import time
import httpx
from typing import Callable, TypeVar
from bs4 import BeautifulSoup

from apex_server.config import get_settings

settings = get_settings()

# Model constants - easy to switch
MODEL_OPUS = "claude-opus-4-5-20251101"
MODEL_SONNET = "claude-sonnet-4-20250514"
MODEL_HAIKU = "claude-haiku-4-5-20251101"
MODEL_DEFAULT = MODEL_SONNET  # Use Sonnet by default (faster, cheaper)
MODEL_QUALITY = MODEL_OPUS    # Use Opus for quality-critical tasks

T = TypeVar('T')


def with_retry(fn: Callable[[], T], max_retries: int = 3, base_delay: float = 2.0) -> T:
    """Execute function with exponential backoff retry on overload errors"""
    last_error = None
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as e:
            error_str = str(e).lower()
            # Retry on overload (529) or rate limit errors
            if 'overloaded' in error_str or '529' in error_str or 'rate' in error_str:
                last_error = e
                delay = base_delay * (2 ** attempt)  # Exponential backoff
                print(f"[RETRY] Attempt {attempt + 1}/{max_retries} failed (overloaded), waiting {delay}s...", flush=True)
                time.sleep(delay)
            else:
                # Non-retryable error, raise immediately
                raise
    # All retries exhausted
    raise last_error


def fetch_page_content(url: str, timeout: float = 10.0) -> dict:
    """Fetch and extract content from a URL"""
    try:
        headers = {"User-Agent": "Mozilla/5.0 (compatible; ApexBot/1.0)"}
        response = httpx.get(url, headers=headers, timeout=timeout, follow_redirects=True)

        if response.status_code != 200:
            return {"url": url, "error": f"HTTP {response.status_code}"}

        soup = BeautifulSoup(response.text, 'html.parser')

        # Remove script and style elements
        for element in soup(['script', 'style', 'nav', 'footer', 'header']):
            element.decompose()

        # Extract title
        title = soup.title.string if soup.title else ""

        # Extract text content (limited)
        text = soup.get_text(separator=' ', strip=True)[:2000]

        # Try to find colors (hex codes)
        colors = re.findall(r'#[0-9A-Fa-f]{6}\b', response.text)
        unique_colors = list(dict.fromkeys(colors))[:10]  # Top 10 unique

        # Look for brand-specific patterns
        brand_colors = []
        if 'brandfetch' in url.lower():
            # Brandfetch has structured color data
            color_matches = re.findall(r'"hex":\s*"([^"]+)"', response.text)
            brand_colors = list(dict.fromkeys(color_matches))[:5]

        return {
            "url": url,
            "title": title,
            "text": text,
            "colors_found": unique_colors,
            "brand_colors": brand_colors
        }
    except Exception as e:
        return {"url": url, "error": str(e)}


def inject_google_fonts(html: str, fonts: dict) -> str:
    """Inject Google Fonts link into HTML head based on moodboard fonts"""
    if not fonts:
        return html

    font_families = []

    # Extract font names from moodboard fonts dict
    heading_font = fonts.get("heading") or fonts.get("primary") or fonts.get("title")
    body_font = fonts.get("body") or fonts.get("secondary") or fonts.get("text")

    if heading_font and isinstance(heading_font, str):
        # Clean font name and format for Google Fonts URL
        font_name = heading_font.split(",")[0].strip().strip("'\"")
        font_families.append(font_name.replace(" ", "+"))

    if body_font and isinstance(body_font, str):
        font_name = body_font.split(",")[0].strip().strip("'\"")
        if font_name.replace(" ", "+") not in font_families:
            font_families.append(font_name.replace(" ", "+"))

    if not font_families:
        return html

    # Build Google Fonts link with multiple weights
    families_param = "&family=".join([f"{f}:wght@300;400;500;600;700" for f in font_families])
    link_tag = f'<link href="https://fonts.googleapis.com/css2?family={families_param}&display=swap" rel="stylesheet">'

    # Remove any existing Google Fonts links to avoid duplicates
    html = re.sub(r'<link[^>]*fonts\.googleapis\.com[^>]*>', '', html)

    # Inject after <head> tag
    if "<head>" in html:
        html = html.replace("<head>", f"<head>\n    {link_tag}")
    elif "<HEAD>" in html:
        html = html.replace("<HEAD>", f"<HEAD>\n    {link_tag}")

    return html
