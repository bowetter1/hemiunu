"""Policy helpers for selecting which tools the AI may use."""
from typing import Tuple

from .tool_registry import (
    build_generate_image_tool,
    build_stock_photo_tool,
    build_web_search_tool,
)


def normalize_image_source(raw: str | None) -> str:
    value = (raw or "ai").strip().lower()
    legacy_map = {
        "existing_site": "img2img",
        "existing": "existing_images",
        "from_site": "existing_images",
        "no_images": "none",
        "none": "none",
    }
    value = legacy_map.get(value, value)
    if value not in {"none", "existing_images", "img2img", "ai", "stock"}:
        value = "ai"
    return value


def resolve_image_source(raw: str | None, has_company_images: bool) -> Tuple[str, bool]:
    """Return (effective_image_source, did_fallback_to_ai)."""
    image_source = normalize_image_source(raw)
    if image_source in {"existing_images", "img2img"} and not has_company_images:
        return "ai", True
    return image_source, False


def build_layout_tools(generator, layout_tool: dict, image_source: str, has_company_images: bool, allow_web_search: bool = True) -> list[dict]:
    tools = []
    if allow_web_search:
        tools.append(build_web_search_tool(max_uses=2))
    tools.append(layout_tool)

    if image_source in {"ai", "img2img"}:
        tools.append(
            build_generate_image_tool(
                generator,
                allow_reference=(image_source == "img2img" and has_company_images),
            )
        )
    elif image_source == "stock":
        tools.append(build_stock_photo_tool(generator))
    # none / existing_images -> no image tools

    return tools
