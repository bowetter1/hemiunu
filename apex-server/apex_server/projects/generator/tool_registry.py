"""Tool registry helpers for AI tool definitions."""
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .base import Generator


def build_web_search_tool(max_uses: int = 2) -> dict:
    return {
        "type": "web_search_20250305",
        "name": "web_search",
        "max_uses": max_uses
    }


def build_generate_image_tool(generator: "Generator", allow_reference: bool = False) -> dict:
    tool = generator.get_image_tools()[0]
    if allow_reference:
        tool = dict(tool)  # shallow copy
        schema = dict(tool["input_schema"])
        props = dict(schema["properties"])
        props["reference_image"] = {
            "type": "string",
            "description": (
                "Path to a company reference image to use as img2img input "
                "(e.g., 'images/company/img_1.jpg'). When provided, the image "
                "generation will use the reference as a starting point, "
                "producing a result that retains the feel of the original photo."
            )
        }
        schema["properties"] = props
        tool["input_schema"] = schema
    return tool


def build_stock_photo_tool(generator: "Generator") -> dict:
    return generator.get_stock_photo_tool()
