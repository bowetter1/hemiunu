"""Image generation mixin using OpenAI GPT Image"""
import base64
import httpx
import re
from typing import TYPE_CHECKING
from openai import OpenAI

from apex_server.config import get_settings

if TYPE_CHECKING:
    from .base import Generator

settings = get_settings()

# Use GPT-Image-1 (latest OpenAI image model)
IMAGE_MODEL = "gpt-image-1"


class ImageGenerationMixin:
    """Mixin for generating images with OpenAI GPT-Image"""

    def get_image_tools(self: "Generator"):
        """Define image generation tool for agentic editing"""
        return [
            {
                "name": "generate_image",
                "description": "Generate an image using AI (GPT-Image). Returns the saved image path.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "prompt": {
                            "type": "string",
                            "description": "Detailed description of the image to generate. Be specific about style, colors, composition."
                        },
                        "filename": {
                            "type": "string",
                            "description": "Filename for the image (e.g., 'hero-background.png', 'logo.png')"
                        },
                        "size": {
                            "type": "string",
                            "enum": ["1024x1024", "1536x1024", "1024x1536"],
                            "description": "Image size. Use 1536x1024 for landscape/hero, 1024x1536 for portrait, 1024x1024 for square."
                        },
                        "quality": {
                            "type": "string",
                            "enum": ["low", "medium", "high"],
                            "description": "Image quality. 'high' for best quality, 'medium' for balanced, 'low' for fast."
                        }
                    },
                    "required": ["prompt", "filename"]
                }
            }
        ]

    def execute_image_tool(self: "Generator", tool_name: str, tool_input: dict) -> str:
        """Execute image generation tool"""
        import json

        if tool_name != "generate_image":
            return json.dumps({"error": f"Unknown tool: {tool_name}"})

        prompt = tool_input.get("prompt", "")
        filename = tool_input.get("filename", "generated.png")
        size = tool_input.get("size", "1024x1024")
        quality = tool_input.get("quality", "medium")

        print(f"[IMAGE] Generating with {IMAGE_MODEL}: {prompt[:50]}... ({size}, {quality})", flush=True)

        try:
            # Generate image with GPT-Image-1
            client = OpenAI(api_key=settings.openai_api_key)
            response = client.images.generate(
                model=IMAGE_MODEL,
                prompt=prompt,
                size=size,
                quality=quality,
                n=1
            )

            # Get image data - GPT-Image returns URL, we need to download it
            image_url = response.data[0].url
            if response.data[0].b64_json:
                # If base64 is available, use it directly
                image_data = base64.b64decode(response.data[0].b64_json)
            else:
                # Download from URL
                print(f"[IMAGE] Downloading from URL...", flush=True)
                with httpx.Client() as http_client:
                    img_response = http_client.get(image_url, timeout=60)
                    img_response.raise_for_status()
                    image_data = img_response.content

            # Save to filesystem
            # Ensure filename ends with .png
            if not filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                filename = f"{filename}.png"

            # Sanitize filename
            filename = re.sub(r'[^a-zA-Z0-9._-]', '-', filename)

            image_path = f"public/images/{filename}"
            self.fs.write_binary(image_path, image_data)

            # Get the revised prompt if available
            revised_prompt = getattr(response.data[0], 'revised_prompt', None) or prompt

            print(f"[IMAGE] Saved: {image_path} ({len(image_data)} bytes)", flush=True)
            self.log("image", f"Generated {filename}")

            return json.dumps({
                "status": "success",
                "path": f"images/{filename}",
                "full_path": image_path,
                "size": len(image_data),
                "revised_prompt": revised_prompt
            })

        except Exception as e:
            print(f"[IMAGE] Error: {e}", flush=True)
            return json.dumps({
                "status": "error",
                "error": str(e)
            })

    def generate_image(self: "Generator", prompt: str, filename: str, size: str = "1024x1024", quality: str = "medium") -> dict:
        """
        Generate an image and save it to the project.

        Args:
            prompt: Description of the image
            filename: Filename to save as
            size: Image dimensions (1024x1024, 1536x1024, 1024x1536)
            quality: 'low', 'medium', or 'high'

        Returns:
            dict with path and metadata
        """
        import json
        result = self.execute_image_tool("generate_image", {
            "prompt": prompt,
            "filename": filename,
            "size": size,
            "quality": quality
        })
        return json.loads(result)
