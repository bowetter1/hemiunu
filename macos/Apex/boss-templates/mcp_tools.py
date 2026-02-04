#!/usr/bin/env python3
"""
Apex Boss Agent MCP Tools

Exposes deployment + image tools for the Boss Agent via MCP stdio protocol.
Talks directly to Daytona cloud sandboxes and image APIs.

Run with: uv run --with mcp --with httpx --with openai --with playwright mcp_tools.py

Reads API keys from .env file in the same directory as this script.
Boss writes .env before launching workers so both Claude and Codex can read it.
"""

import os
import json
import base64
import re
from datetime import datetime, timezone
from pathlib import Path
from mcp.server.fastmcp import FastMCP
# from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams  # TODO: re-enable for deploy

mcp = FastMCP("apex-tools")


# ──────────────────────────────────────────────
# Chat tool — agent-to-user communication
# ──────────────────────────────────────────────


@mcp.tool()
def apex_chat(message: str) -> dict:
    """Send a message to the user. Use this for ALL communication with the user.

    Any text you want the user to see in the chat must go through this tool.
    Do not write chat messages as plain text — only use this tool.

    Args:
        message: The message to display to the user.

    Returns:
        dict with status "sent"
    """
    entry = {"role": "assistant", "content": message}
    chat_file = Path.cwd() / "chat.jsonl"
    with open(chat_file, "a") as f:
        f.write(json.dumps(entry) + "\n")
    return {"status": "sent"}


def _load_env():
    """Load .env file from script directory into os.environ."""
    env_path = Path(__file__).resolve().parent / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ.setdefault(key.strip(), val.strip())

_load_env()

def _get_key(name: str) -> str:
    """Get API key from environment (loaded from .env at startup)."""
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} not set — add it to .env")
    return value


# ──────────────────────────────────────────────
# Sandbox tools — DISABLED (Daytona not needed during dev)
# ──────────────────────────────────────────────

# Sandbox tools (apex_create_sandbox, apex_upload_file, apex_start_preview,
# apex_exec_command) are disabled while Daytona is commented out.
# Re-enable the daytona import above when deploy is needed.


# ──────────────────────────────────────────────
# Image tools
# ──────────────────────────────────────────────


@mcp.tool()
def apex_search_photos(
    query: str,
    orientation: str = "landscape",
    count: int = 3,
) -> dict:
    """Search for real stock photos on Pexels. Returns URLs you can use directly in HTML.

    Use short, specific queries (2-4 words) for best results.

    Args:
        query: Search query (e.g. "modern office", "coffee shop interior", "team meeting")
        orientation: "landscape" (default), "portrait", or "square"
        count: Number of results to return (1-5, default 3)

    Returns:
        dict with photos list, each containing: url, photographer, alt, width, height
    """
    import httpx

    api_key = _get_key("PEXELS_API_KEY")

    count = max(1, min(5, count))

    resp = httpx.get(
        "https://api.pexels.com/v1/search",
        headers={"Authorization": api_key},
        params={
            "query": query,
            "orientation": orientation,
            "per_page": count,
            "size": "large",
        },
        timeout=15,
    )
    resp.raise_for_status()
    data = resp.json()

    photos = []
    for photo in data.get("photos", []):
        src = photo.get("src", {})
        photos.append({
            "url": src.get("large2x") or src.get("large") or src.get("original"),
            "url_medium": src.get("medium"),
            "url_small": src.get("small"),
            "photographer": photo.get("photographer", ""),
            "alt": photo.get("alt", query),
            "width": photo.get("width"),
            "height": photo.get("height"),
            "pexels_url": photo.get("url"),
        })

    return {
        "query": query,
        "total_results": data.get("total_results", 0),
        "photos": photos,
    }


@mcp.tool()
def apex_generate_image(
    prompt: str,
    filename: str = "generated.png",
    size: str = "1536x1024",
    quality: str = "low",
) -> dict:
    """Generate an AI image using GPT-Image-1 and save it to the workspace.

    Best for hero images, custom illustrations, or brand-specific visuals
    that stock photos can't provide.

    Args:
        prompt: Detailed description of the image to generate
        filename: Output filename (saved to images/ in workspace, e.g. "hero.png")
        size: Image size — "1024x1024" (square), "1536x1024" (landscape), "1024x1536" (portrait)
        quality: "low", "medium" (default), or "high"

    Returns:
        dict with local_path (relative path for use in HTML src) and revised_prompt
    """
    from openai import OpenAI

    api_key = _get_key("OPENAI_API_KEY")

    client = OpenAI(api_key=api_key)

    response = client.images.generate(
        model="gpt-image-1",
        prompt=prompt,
        n=1,
        size=size,
        quality=quality,
    )

    image_data = response.data[0]

    # Sanitize filename
    safe_name = re.sub(r"[^a-zA-Z0-9._-]", "", filename)
    if not safe_name:
        safe_name = "generated.png"

    # Get image bytes
    if hasattr(image_data, "b64_json") and image_data.b64_json:
        image_bytes = base64.b64decode(image_data.b64_json)
    elif hasattr(image_data, "url") and image_data.url:
        import httpx
        img_resp = httpx.get(image_data.url, timeout=30)
        img_resp.raise_for_status()
        image_bytes = img_resp.content
    else:
        raise RuntimeError("No image data returned from OpenAI")

    # Save to workspace
    image_path = f"images/{safe_name}"
    full_path = os.path.join(os.getcwd(), image_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "wb") as f:
        f.write(image_bytes)

    return {
        "local_path": image_path,
        "html_src": image_path,
        "size_bytes": len(image_bytes),
        "revised_prompt": getattr(image_data, "revised_prompt", None),
    }


@mcp.tool()
def apex_img2img(
    reference_url: str,
    prompt: str,
    filename: str = "restyled.png",
    size: str = "1536x1024",
    quality: str = "low",
) -> dict:
    """Generate a new image based on a reference image from an existing website.

    Downloads the reference image, then uses OpenAI images.edit to create
    a new version that retains the feel/composition of the original but
    restyled according to the prompt.

    Perfect for: taking a hero image from the client's existing site and
    creating a fresh version that matches the new design direction.

    Args:
        reference_url: URL of the reference image to restyle (from the existing site)
        prompt: Description of the desired style (e.g. "warm golden lighting, luxury hotel, editorial photography style")
        filename: Output filename (saved to images/ in workspace, e.g. "hero-restyled.png")
        size: Image size — "1024x1024" (square), "1536x1024" (landscape), "1024x1536" (portrait)
        quality: "low", "medium" (default), or "high"

    Returns:
        dict with local_path (relative path for use in HTML src) and revised_prompt
    """
    import httpx
    import io
    from openai import OpenAI

    api_key = _get_key("OPENAI_API_KEY")

    # Download reference image
    img_resp = httpx.get(reference_url, timeout=30, follow_redirects=True)
    img_resp.raise_for_status()
    reference_bytes = img_resp.content

    client = OpenAI(api_key=api_key)

    # Use images.edit for img2img
    image_file = io.BytesIO(reference_bytes)
    image_file.name = "reference.png"

    response = client.images.edit(
        model="gpt-image-1",
        image=image_file,
        prompt=prompt,
        n=1,
        size=size,
    )

    image_data = response.data[0]

    # Get result bytes
    if hasattr(image_data, "b64_json") and image_data.b64_json:
        result_bytes = base64.b64decode(image_data.b64_json)
    elif hasattr(image_data, "url") and image_data.url:
        result_resp = httpx.get(image_data.url, timeout=30)
        result_resp.raise_for_status()
        result_bytes = result_resp.content
    else:
        raise RuntimeError("No image data returned from OpenAI")

    # Save to workspace
    safe_name = re.sub(r"[^a-zA-Z0-9._-]", "", filename)
    if not safe_name:
        safe_name = "restyled.png"
    image_path = f"images/{safe_name}"
    full_path = os.path.join(os.getcwd(), image_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "wb") as f:
        f.write(result_bytes)

    return {
        "local_path": image_path,
        "html_src": image_path,
        "size_bytes": len(result_bytes),
        "reference_url": reference_url,
        "revised_prompt": getattr(image_data, "revised_prompt", None),
    }


# ──────────────────────────────────────────────
# Browser tool — headless screenshots
# ──────────────────────────────────────────────


_browser_installed = False


@mcp.tool()
async def apex_browser(
    url: str,
    widths: list[int] | None = None,
    full_page: bool = False,
) -> dict:
    """Open a URL in a headless browser and take screenshots at specified widths.

    Args:
        url: URL or file path to open. File paths are converted to file:// URLs.
        widths: List of viewport widths to screenshot (default: [1200])
        full_page: Whether to capture full page or just viewport (default: False)

    Returns:
        dict with screenshots list, each containing: width, path
    """
    from playwright.async_api import async_playwright

    global _browser_installed

    if widths is None:
        widths = [1200]

    # Convert file paths to file:// URLs
    if not url.startswith(("http://", "https://", "file://")):
        file_path = Path(url)
        if not file_path.is_absolute():
            file_path = Path(os.getcwd()) / file_path
        file_path = file_path.resolve()
        url = f"file://{file_path}"

    screenshots = []
    async with async_playwright() as p:
        # Install browser on first use if needed
        if not _browser_installed:
            try:
                browser = await p.chromium.launch(headless=True)
            except Exception:
                import subprocess
                subprocess.run(
                    ["playwright", "install", "chromium"],
                    check=True,
                    capture_output=True,
                )
                _browser_installed = True
                browser = await p.chromium.launch(headless=True)
            else:
                _browser_installed = True
        else:
            browser = await p.chromium.launch(headless=True)

        try:
            for width in widths:
                page = await browser.new_page(viewport={"width": width, "height": 900})
                await page.goto(url, wait_until="networkidle")
                await page.wait_for_timeout(500)

                filename = f"screenshot-{width}px.png"
                out_path = os.path.join(os.getcwd(), filename)
                await page.screenshot(path=out_path, full_page=full_page)
                await page.close()

                screenshots.append({
                    "width": width,
                    "path": filename,
                })
        finally:
            await browser.close()

    return {"screenshots": screenshots}


# ──────────────────────────────────────────────
# Review tool — visual QA via Haiku
# ──────────────────────────────────────────────


@mcp.tool()
def apex_review_screenshot(
    screenshot_path: str,
    context: str = "",
) -> dict:
    """Review a screenshot of your proposal using fast visual AI (Haiku).

    Takes a screenshot image you already captured (via apex_browser)
    and sends it to a fast, cheap vision model for layout/design QA. Returns text feedback
    so you don't have to visually interpret the screenshot yourself — saving significant tokens.

    Workflow:
    1. Take screenshots with apex_browser
    2. Call this tool with each screenshot path
    3. Read the feedback and fix issues
    4. Repeat if needed

    Args:
        screenshot_path: Path to the screenshot image file (png or jpeg).
                         Can be absolute or relative to the workspace.
        context: Optional context about what to focus on (e.g. "just fixed hero image overlap")

    Returns:
        dict with "feedback" (detailed text review) and "issues" (list of specific problems found)
    """
    import anthropic

    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        raise RuntimeError("ANTHROPIC_API_KEY not set — add it to .env or environment")

    # Resolve path
    img_path = Path(screenshot_path)
    if not img_path.is_absolute():
        img_path = Path(os.getcwd()) / img_path
    if not img_path.exists():
        raise FileNotFoundError(f"Screenshot not found: {img_path}")

    # Read image and determine media type
    image_bytes = img_path.read_bytes()
    suffix = img_path.suffix.lower()
    media_type = "image/png" if suffix == ".png" else "image/jpeg"
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    review_prompt = "You are reviewing a website proposal screenshot. Be specific and actionable."
    if context:
        review_prompt += f"\n\nContext from the builder: {context}"

    review_prompt += """

Look at this screenshot critically and report:

1. **Layout** — Any overlapping elements, broken spacing, or alignment issues?
2. **Images** — Are all images visible and loading? Any broken/missing image placeholders?
3. **Typography** — Is the hierarchy clear? Readable font sizes? Proper contrast?
4. **Visual quality** — Does this look like a creative director made it, or generic?
5. **Responsiveness clues** — Anything that looks like it would break at other widths?

For each issue found, describe exactly what's wrong and where on the page it is.
If everything looks good, say so — don't invent problems.

Be concise. No fluff. Just the issues and what to fix."""

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": image_b64,
                        },
                    },
                    {
                        "type": "text",
                        "text": review_prompt,
                    },
                ],
            }
        ],
    )

    feedback = message.content[0].text if message.content else "No feedback generated."

    # Parse out individual issues (lines starting with - or numbered)
    issues = []
    for line in feedback.split("\n"):
        stripped = line.strip()
        if stripped and (stripped.startswith("- ") or (len(stripped) > 2 and stripped[0].isdigit() and stripped[1] in ".)")):
            issues.append(stripped.lstrip("- ").lstrip("0123456789.)").strip())

    # Log to review-log.jsonl in workspace
    usage = message.usage
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "model": "claude-haiku-4-5-20251001",
        "screenshot": str(img_path),
        "image_bytes": len(image_bytes),
        "input_tokens": usage.input_tokens if usage else 0,
        "output_tokens": usage.output_tokens if usage else 0,
        "issues_found": len(issues),
        "feedback": feedback,
    }
    try:
        log_path = Path(os.getcwd()) / "review-log.jsonl"
        with open(log_path, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
    except Exception:
        pass  # Don't fail the tool if logging fails

    return {
        "feedback": feedback,
        "issues": issues,
        "model_used": "claude-haiku-4-5-20251001",
    }


if __name__ == "__main__":
    mcp.run()
