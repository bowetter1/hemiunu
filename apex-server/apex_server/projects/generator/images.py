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
                "description": "Generate an AI image using GPT-Image. Best for: stylized hero images, custom illustrations, brand-specific visuals that don't exist as stock photos.",
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

    def get_stock_photo_tool(self: "Generator"):
        """Define stock photo search tool"""
        return {
            "name": "stock_photo",
            "description": "Search and download a real stock photo from Pexels. Best for: realistic people, professional portraits, nature/landscape backgrounds, office environments, food, travel — anything where photorealism matters more than brand-specific content.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Short search query, 2-4 words (e.g., 'luxury hotel lobby', 'farm sunset landscape', 'team meeting office'). Keep it simple — Pexels works best with concise queries. Do NOT write long descriptive sentences."
                    },
                    "filename": {
                        "type": "string",
                        "description": "Filename to save as (e.g., 'hero-bg.jpg', 'team-photo.jpg')"
                    },
                    "orientation": {
                        "type": "string",
                        "enum": ["landscape", "portrait", "square"],
                        "description": "Photo orientation. Use 'landscape' for hero/banner images, 'portrait' for tall sections, 'square' for cards/thumbnails."
                    },
                    "size": {
                        "type": "string",
                        "enum": ["small", "medium", "large"],
                        "description": "Photo size. 'large' for hero images (full-width), 'medium' for section images, 'small' for thumbnails. Default: large."
                    }
                },
                "required": ["query", "filename"]
            }
        }

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

    def execute_stock_photo(self: "Generator", tool_input: dict) -> str:
        """Execute stock photo search and download from Pexels"""
        import json

        query = tool_input.get("query", "")
        filename = tool_input.get("filename", "stock.jpg")
        orientation = tool_input.get("orientation", "landscape")
        size_pref = tool_input.get("size", "large")

        if not filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
            filename = f"{filename}.jpg"
        filename = re.sub(r'[^a-zA-Z0-9._-]', '-', filename)

        # Map orientation to generate_image size for fallback
        size_map = {"landscape": "1536x1024", "portrait": "1024x1536", "square": "1024x1024"}
        fallback_size = size_map.get(orientation, "1536x1024")

        def _fallback(reason: str) -> str:
            print(f"[STOCK] {reason}, falling back to AI generation", flush=True)
            return self.execute_image_tool("generate_image", {
                "prompt": query, "filename": filename,
                "size": fallback_size, "quality": "medium"
            })

        print(f"[STOCK] Searching Pexels: '{query}' ({orientation}, {size_pref})", flush=True)

        if not settings.pexels_api_key:
            return _fallback("No Pexels API key configured")

        try:
            headers = {"Authorization": settings.pexels_api_key}
            params = {
                "query": query,
                "orientation": orientation,
                "per_page": 5,
                "size": "large",
            }

            with httpx.Client(headers=headers, timeout=15) as client:
                resp = client.get("https://api.pexels.com/v1/search", params=params)
                resp.raise_for_status()
                data = resp.json()

            photos = data.get("photos", [])
            if not photos:
                return _fallback(f"No results for '{query}'")

            # Pick the first photo (Pexels returns relevance-sorted)
            photo = photos[0]
            photographer = photo.get("photographer", "Unknown")

            # Select download size: large2x > large > original
            src = photo.get("src", {})
            if size_pref == "large":
                download_url = src.get("large2x") or src.get("large") or src.get("original")
            elif size_pref == "medium":
                download_url = src.get("large") or src.get("medium")
            else:
                download_url = src.get("medium") or src.get("small")

            if not download_url:
                download_url = src.get("original", "")

            print(f"[STOCK] Downloading: {photo.get('alt', query)[:50]} by {photographer}", flush=True)

            # Download the image
            with httpx.Client(timeout=30, follow_redirects=True) as client:
                img_resp = client.get(download_url)
                img_resp.raise_for_status()
                image_data = img_resp.content

            image_path = f"public/images/{filename}"
            self.fs.write_binary(image_path, image_data)

            print(f"[STOCK] Saved: {image_path} ({len(image_data) // 1024}KB) — Photo by {photographer} on Pexels", flush=True)
            self.log("image", f"Stock photo: {filename} by {photographer}")

            return json.dumps({
                "status": "success",
                "path": f"images/{filename}",
                "full_path": image_path,
                "size": len(image_data),
                "method": "stock_photo",
                "photographer": photographer,
                "pexels_url": photo.get("url", ""),
                "alt": photo.get("alt", query)
            })

        except Exception as e:
            return _fallback(f"Error: {e}")

    def edit_image_from_reference(self: "Generator", reference_bytes: bytes, prompt: str, filename: str, size: str = "1024x1024", quality: str = "medium") -> dict:
        """
        Generate a new image using img2img (OpenAI images.edit endpoint).

        Uses a reference image from the company's website as input, producing
        a styled version that retains the feel of the original.

        Args:
            reference_bytes: Raw bytes of the reference image
            prompt: Description of the desired output style
            filename: Filename to save as
            size: Image dimensions (1536x1024, 1024x1536, 1024x1024)
            quality: 'low', 'medium', or 'high'

        Returns:
            dict with path and metadata (same format as generate_image)
        """
        import json
        import io

        if not filename.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
            filename = f"{filename}.png"
        filename = re.sub(r'[^a-zA-Z0-9._-]', '-', filename)

        print(f"[IMAGE] img2img edit with {IMAGE_MODEL}: {prompt[:50]}... ({size}, ref={len(reference_bytes) // 1024}KB)", flush=True)

        try:
            client = OpenAI(api_key=settings.openai_api_key)

            # OpenAI images.edit expects a file-like object
            image_file = io.BytesIO(reference_bytes)
            image_file.name = "reference.png"

            response = client.images.edit(
                model=IMAGE_MODEL,
                image=image_file,
                prompt=prompt,
                size=size,
            )

            # Get image data
            if response.data[0].b64_json:
                image_data = base64.b64decode(response.data[0].b64_json)
            else:
                image_url = response.data[0].url
                print(f"[IMAGE] Downloading edited image from URL...", flush=True)
                with httpx.Client() as http_client:
                    img_response = http_client.get(image_url, timeout=60)
                    img_response.raise_for_status()
                    image_data = img_response.content

            image_path = f"public/images/{filename}"
            self.fs.write_binary(image_path, image_data)

            print(f"[IMAGE] img2img saved: {image_path} ({len(image_data)} bytes)", flush=True)
            self.log("image", f"img2img edited {filename}")

            return {
                "status": "success",
                "path": f"images/{filename}",
                "full_path": image_path,
                "size": len(image_data),
                "method": "img2img_edit"
            }

        except Exception as e:
            print(f"[IMAGE] img2img edit failed: {e}", flush=True)
            print(f"[IMAGE] Falling back to generate (no reference)...", flush=True)
            # Fallback to standard generation
            return self.generate_image(prompt=prompt, filename=filename, size=size, quality=quality)

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
