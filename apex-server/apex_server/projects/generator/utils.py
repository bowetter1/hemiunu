"""Utility functions for the generator"""
import re
import time
import httpx
from typing import Callable, TypeVar
from urllib.parse import urljoin
from bs4 import BeautifulSoup

from apex_server.config import get_settings

settings = get_settings()

# Model constants - easy to switch
MODEL_OPUS = "claude-opus-4-5-20251101"
MODEL_SONNET = "claude-sonnet-4-20250514"
MODEL_HAIKU = "claude-haiku-4-5-20251001"
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


def scrape_images(url: str, timeout: float = 10.0, max_images: int = 5) -> list[tuple[str, bytes]]:
    """
    Scrape real images from a URL.

    Parses <img> tags and CSS background-image, filters out icons/logos,
    downloads candidates and keeps only images > 50KB (real photos).

    Returns:
        List of (image_url, image_bytes) tuples, max `max_images`.
    """
    SKIP_PATTERNS = ["icon", "logo", "favicon", "sprite", "avatar", "badge", "emoji", "pixel", "tracking", "1x1"]
    MIN_BYTES = 50 * 1024  # 50KB — skip tiny assets

    try:
        headers = {"User-Agent": "Mozilla/5.0 (compatible; ApexBot/1.0)"}
        response = httpx.get(url, headers=headers, timeout=timeout, follow_redirects=True)
        if response.status_code != 200:
            print(f"[SCRAPE] HTTP {response.status_code} for {url}", flush=True)
            return []

        soup = BeautifulSoup(response.text, "html.parser")
        base_url = str(response.url)  # After redirects
        candidate_urls: list[str] = []

        # 1. <img> tags — src and data-src (lazy-loaded)
        for img in soup.find_all("img"):
            src = img.get("src") or img.get("data-src") or ""
            if src:
                candidate_urls.append(urljoin(base_url, src))

        # 2. CSS background-image in inline styles
        bg_pattern = re.compile(r'background(?:-image)?\s*:\s*url\(["\']?(.*?)["\']?\)', re.IGNORECASE)
        for tag in soup.find_all(style=True):
            for match in bg_pattern.findall(tag["style"]):
                candidate_urls.append(urljoin(base_url, match))

        # 3. Also check <style> blocks
        for style_block in soup.find_all("style"):
            if style_block.string:
                for match in bg_pattern.findall(style_block.string):
                    candidate_urls.append(urljoin(base_url, match))

        # Deduplicate while preserving order
        seen = set()
        unique_urls = []
        for u in candidate_urls:
            if u not in seen:
                seen.add(u)
                unique_urls.append(u)

        # Filter out icons/logos by URL pattern and small-dimension hints
        def is_likely_icon(img_url: str) -> bool:
            lower = img_url.lower()
            if any(p in lower for p in SKIP_PATTERNS):
                return True
            # Skip SVGs (usually icons)
            if lower.endswith(".svg"):
                return True
            # Skip tiny dimension hints in URL (e.g., 50x50, 100w)
            dim_match = re.search(r'(\d+)x(\d+)', lower)
            if dim_match:
                w, h = int(dim_match.group(1)), int(dim_match.group(2))
                if w < 200 or h < 200:
                    return True
            return False

        filtered_urls = [u for u in unique_urls if not is_likely_icon(u)]
        print(f"[SCRAPE] Found {len(unique_urls)} image URLs, {len(filtered_urls)} after filtering", flush=True)

        # Download candidates and keep only large enough images
        results: list[tuple[str, bytes]] = []
        with httpx.Client(headers=headers, timeout=15, follow_redirects=True) as client:
            for img_url in filtered_urls:
                if len(results) >= max_images:
                    break
                try:
                    img_resp = client.get(img_url)
                    if img_resp.status_code == 200 and len(img_resp.content) >= MIN_BYTES:
                        content_type = img_resp.headers.get("content-type", "")
                        if "image" in content_type or img_url.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                            results.append((img_url, img_resp.content))
                            print(f"[SCRAPE] Kept: {img_url[:80]} ({len(img_resp.content) // 1024}KB)", flush=True)
                    else:
                        print(f"[SCRAPE] Skipped (too small or not 200): {img_url[:60]}", flush=True)
                except Exception as e:
                    print(f"[SCRAPE] Download error {img_url[:40]}: {e}", flush=True)

        print(f"[SCRAPE] Final: {len(results)} images from {url}", flush=True)
        return results

    except Exception as e:
        print(f"[SCRAPE] Error scraping {url}: {e}", flush=True)
        return []


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
