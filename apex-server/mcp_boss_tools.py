#!/usr/bin/env python3
"""
Apex Boss Agent MCP Tools

Exposes deployment + image tools for the Boss Agent via MCP stdio protocol.
Talks directly to Daytona cloud sandboxes and image APIs.

Run with: uv run --with mcp --with httpx --with openai mcp_boss_tools.py

Environment variables (inherited from BossAgentService → Claude CLI):
  DAYTONA_API_KEY  — Daytona cloud API key
  PEXELS_API_KEY   — Pexels stock photo API key
  OPENAI_API_KEY   — OpenAI API key (for GPT-Image-1)
"""

import os
import base64
import re
from mcp.server.fastmcp import FastMCP
# from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams  # TODO: re-enable for deploy

mcp = FastMCP("apex-tools")


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

    api_key = os.environ.get("PEXELS_API_KEY", "")
    if not api_key:
        raise RuntimeError("PEXELS_API_KEY not set")

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
    quality: str = "medium",
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

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not set")

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
    quality: str = "medium",
) -> dict:
    """Restyle a reference image while keeping its content intact.

    Downloads the reference image, then uses OpenAI images.edit to create
    a new version with the same subject, composition, and elements but
    with a different visual style.

    IMPORTANT: The output preserves what's IN the image — same objects,
    same layout, same scene. Only the style changes. Do NOT describe
    new content in the prompt — only describe the desired visual style.

    Args:
        reference_url: URL of the reference image to restyle (from the existing site)
        prompt: Style description ONLY — e.g. "warm golden lighting, softer contrast, editorial photography". Do NOT describe objects or scene content.
        filename: Output filename (saved to images/ in workspace, e.g. "hero-restyled.png")
        size: Image size — "1024x1024" (square), "1536x1024" (landscape), "1024x1536" (portrait)
        quality: "low", "medium" (default), or "high"

    Returns:
        dict with local_path (relative path for use in HTML src) and revised_prompt
    """
    import httpx
    import io
    from openai import OpenAI

    api_key = os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not set")

    # Download reference image
    img_resp = httpx.get(reference_url, timeout=30, follow_redirects=True)
    img_resp.raise_for_status()
    reference_bytes = img_resp.content

    client = OpenAI(api_key=api_key)

    # Use images.edit for img2img
    image_file = io.BytesIO(reference_bytes)
    image_file.name = "reference.png"

    # Wrap the agent's prompt to keep the output faithful to the reference.
    # Without this, GPT-image-1 tends to hallucinate new elements.
    faithful_prompt = (
        "Recreate this image faithfully. Keep the same subject, composition, "
        "layout, objects, and overall scene. Do NOT add, remove, or change any "
        "objects or elements. Only adjust the visual style as follows: "
        f"{prompt}"
    )

    response = client.images.edit(
        model="gpt-image-1",
        image=image_file,
        prompt=faithful_prompt,
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


if __name__ == "__main__":
    mcp.run()
