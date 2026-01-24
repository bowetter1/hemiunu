"""Project generator - Simple Opus calls for moodboard and layouts"""
import json
from pathlib import Path
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from .models import Project, Page, ProjectLog, ProjectStatus

settings = get_settings()


class Generator:
    """Generates moodboards, layouts, and page edits using Opus"""

    def __init__(self, project: Project, db: Session):
        self.project = project
        self.db = db
        self.project_dir = Path(project.project_dir)
        self.client = Anthropic(api_key=settings.anthropic_api_key)

    def log(self, phase: str, message: str, data: dict = None):
        """Add a log entry"""
        entry = ProjectLog(
            project_id=self.project.id,
            phase=phase,
            message=message,
            data=data
        )
        self.db.add(entry)
        self.db.commit()

    def track_usage(self, response):
        """Track token usage"""
        self.project.input_tokens += response.usage.input_tokens
        self.project.output_tokens += response.usage.output_tokens
        # Approximate cost for claude-sonnet-4
        cost = (response.usage.input_tokens * 0.003 + response.usage.output_tokens * 0.015) / 1000
        self.project.cost_usd += cost
        self.db.commit()

    def generate_moodboard(self) -> list:
        """Generate 3 moodboard alternatives based on the brief, with web research"""
        print(f"[MOODBOARD] Starting for project {self.project.id}", flush=True)
        print(f"[MOODBOARD] Brief: {self.project.brief[:100]}...", flush=True)
        self.log("moodboard", "Starting moodboard generation with web research...")

        # Anthropic's built-in web search tool
        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5  # Limit searches per request
        }
        print("[MOODBOARD] Web search tool configured", flush=True)

        # Tool for saving moodboards (structured output)
        moodboard_tool = {
            "name": "save_moodboards",
            "description": "Save the final moodboard alternatives after research is complete",
            "input_schema": {
                "type": "object",
                "properties": {
                    "moodboards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "description": "Short style name"},
                                "palette": {"type": "array", "items": {"type": "string"}, "description": "3-5 hex colors"},
                                "fonts": {
                                    "type": "object",
                                    "properties": {
                                        "heading": {"type": "string"},
                                        "body": {"type": "string"}
                                    },
                                    "required": ["heading", "body"]
                                },
                                "mood": {"type": "array", "items": {"type": "string"}, "description": "3 mood keywords"},
                                "rationale": {"type": "string", "description": "Why this direction fits, referencing research"}
                            },
                            "required": ["name", "palette", "fonts", "mood", "rationale"]
                        }
                    }
                },
                "required": ["moodboards"]
            }
        }

        system_prompt = """You are an expert web designer at a premium design agency.

IMPORTANT: Before creating moodboards, USE WEB SEARCH to research:
1. If a brand/company is mentioned → search for their brand colors and visual identity
2. Search for competitor websites in the same industry
3. Search for current design trends relevant to the project

Your design philosophy:
- Clean, purposeful layouts with clear hierarchy
- Strategic use of whitespace
- Typography that enhances readability and brand voice
- Color palettes that evoke the right emotions

When creating moodboards:
- Use ACTUAL brand colors if researched (don't guess!)
- Reference what you learned from research
- Offer genuinely different creative directions"""

        # Use beta API for web search
        print("[MOODBOARD] Calling Anthropic API with web search...", flush=True)
        self.log("moodboard", "Calling Claude with web search enabled...")

        response = self.client.beta.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=4000,
            system=system_prompt,
            tools=[web_search_tool, moodboard_tool],
            betas=["web-search-2025-03-05"],
            messages=[
                {"role": "user", "content": f"""Create THREE distinct moodboard alternatives for this website:

PROJECT BRIEF:
{self.project.brief}

STEPS:
1. First, use web_search to research:
   - If a company/brand is mentioned, search for their brand colors
   - Search for design inspiration in this industry

2. Then, call save_moodboards with 3 moodboards that offer DIFFERENT creative directions

Each moodboard needs:
- A memorable style name
- 3-5 colors (use researched brand colors!)
- Google Fonts (heading + body)
- 3 mood keywords
- Rationale explaining the direction"""}
            ]
        )

        print(f"[MOODBOARD] API response received, stop_reason: {response.stop_reason}", flush=True)
        self.track_usage(response)

        # Extract web search results and moodboards from response
        web_searches = []
        moodboards = []
        current_search_query = None

        for block in response.content:
            print(f"[MOODBOARD] Block type: {block.type}", flush=True)

            # Capture search query from server_tool_use
            if block.type == "server_tool_use" and getattr(block, 'name', '') == "web_search":
                current_search_query = getattr(block, 'input', {}).get('query', 'unknown')
                print(f"[MOODBOARD] Search query: {current_search_query}", flush=True)

            # Capture web search results
            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                search_data = {
                    "query": current_search_query or "unknown",
                    "results": []
                }

                # content is a list of search result objects
                if isinstance(content, list):
                    for item in content[:5]:
                        if hasattr(item, 'title'):
                            search_data["results"].append({
                                "title": getattr(item, 'title', ''),
                                "url": getattr(item, 'url', ''),
                                "snippet": str(getattr(item, 'snippet', getattr(item, 'page_content', '')))[:200]
                            })

                if search_data["results"]:
                    web_searches.append(search_data)
                    print(f"[MOODBOARD] Got {len(search_data['results'])} results for: {current_search_query}", flush=True)
                    self.log("moodboard", f"Searched: {current_search_query} ({len(search_data['results'])} results)")

                current_search_query = None  # Reset for next search

            # Capture moodboards
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                print(f"[MOODBOARD] Got {len(moodboards)} moodboards", flush=True)

        if moodboards:
            # Save moodboards WITH search data
            self.project.moodboard = {
                "moodboards": moodboards,
                "web_searches": web_searches  # Save search results!
            }
            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()
            self.log("moodboard", f"Created {len(moodboards)} moodboards with {len(web_searches)} searches")
            print(f"[MOODBOARD] Success! {len(moodboards)} moodboards, {len(web_searches)} searches saved", flush=True)
            return moodboards

        # Fallback if no tool use found
        print("[MOODBOARD] No moodboards found, using fallback", flush=True)
        self.log("moodboard", "Warning: Using fallback moodboard generation")
        return self._generate_moodboard_fallback()

    def _generate_moodboard_fallback(self) -> list:
        """Fallback moodboard generation without web search"""
        moodboard_tool = {
            "name": "save_moodboards",
            "description": "Save the generated moodboard alternatives",
            "input_schema": {
                "type": "object",
                "properties": {
                    "moodboards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "palette": {"type": "array", "items": {"type": "string"}},
                                "fonts": {"type": "object", "properties": {"heading": {"type": "string"}, "body": {"type": "string"}}},
                                "mood": {"type": "array", "items": {"type": "string"}},
                                "rationale": {"type": "string"}
                            },
                            "required": ["name", "palette", "fonts", "mood", "rationale"]
                        }
                    }
                },
                "required": ["moodboards"]
            }
        }

        response = self.client.messages.create(
            model="claude-sonnet-4-5-20250929",
            max_tokens=4000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[{"role": "user", "content": f"Create 3 moodboards for: {self.project.brief}"}]
        )

        self.track_usage(response)

        for block in response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                self.project.moodboard = {"moodboards": moodboards}
                self.project.status = ProjectStatus.MOODBOARD
                self.db.commit()
                return moodboards

        return []

    def generate_layouts(self) -> list[dict]:
        """Generate 3 layout alternatives using the selected moodboard"""
        self.log("layouts", "Generating 3 layout alternatives...")

        # Get the selected moodboard
        moodboard_data = self.project.moodboard
        if not moodboard_data:
            raise ValueError("Moodboard missing")

        selected_idx = (self.project.selected_moodboard or 1) - 1
        moodboards = moodboard_data.get("moodboards", [moodboard_data])

        if selected_idx >= len(moodboards):
            selected_idx = 0

        moodboard = moodboards[selected_idx]

        # Define tool for structured output
        layout_tool = {
            "name": "save_layouts",
            "description": "Save the generated HTML layouts",
            "input_schema": {
                "type": "object",
                "properties": {
                    "layouts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "description": "Layout name"},
                                "description": {"type": "string", "description": "Short description"},
                                "html": {"type": "string", "description": "Complete HTML with inline CSS"}
                            },
                            "required": ["name", "description", "html"]
                        }
                    }
                },
                "required": ["layouts"]
            }
        }

        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
            max_tokens=16000,
            tools=[layout_tool],
            tool_choice={"type": "tool", "name": "save_layouts"},
            messages=[
                {"role": "user", "content": f"""Create THREE different hero section designs for a landing page:

Brief: {self.project.brief}

Moodboard:
- Colors: {', '.join(moodboard.get('palette', []))}
- Fonts: {moodboard.get('fonts', {})}
- Mood: {', '.join(moodboard.get('mood', []))}

Rules:
- Create ONLY a hero section (above-the-fold content)
- Each must be a COMPLETE HTML file with ALL CSS in <style> tag
- Use EXACTLY the colors from the moodboard
- Import Google Fonts in <head>
- Make it responsive and visually striking
- Include: headline, subheadline, CTA button, and optional decorative elements
- Each hero should have a DIFFERENT visual approach:
  1. Centered text with gradient background
  2. Split layout (text left, visual element right)
  3. Bold typography with minimal design"""}
            ]
        )

        self.track_usage(response)

        # Extract structured data from tool use
        layouts = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_layouts":
                layouts = block.input.get("layouts", [])

        # Save layouts as pages
        for i, layout in enumerate(layouts, 1):
            # Try to save HTML file (optional - may fail on Railway)
            try:
                file_path = self.project_dir / f"layout_{i}.html"
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(layout["html"])
            except Exception:
                pass  # File storage is optional, DB is the source of truth

            # Create page record
            page = Page(
                project_id=self.project.id,
                name=layout.get("name", f"Layout {i}"),
                html=layout["html"],
                layout_variant=i
            )
            self.db.add(page)

        self.project.status = ProjectStatus.LAYOUTS
        self.db.commit()

        self.log("layouts", f"Created {len(layouts)} layouts", {"count": len(layouts)})
        return layouts

    def _extract_layouts_fallback(self, text: str) -> list[dict]:
        """Fallback: extract HTML blocks when JSON parsing fails"""
        import re
        layouts = []

        # Find all <!DOCTYPE html> ... </html> blocks
        html_pattern = r'(<!DOCTYPE html>.*?</html>)'
        matches = re.findall(html_pattern, text, re.DOTALL | re.IGNORECASE)

        for i, html in enumerate(matches[:3], 1):  # Max 3 layouts
            layouts.append({
                "name": f"Layout {i}",
                "description": f"Layout variant {i}",
                "html": html.strip()
            })

        if not layouts:
            raise ValueError("Could not extract any HTML layouts from response")

        return layouts

    def select_layout(self, variant: int):
        """Select a layout and move to editing phase (keeps all 3 alternatives)"""
        page = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == variant
        ).first()

        if not page:
            raise ValueError(f"Layout {variant} not found")

        # Try to save as index.html (optional - may fail on Railway)
        try:
            self.project_dir.mkdir(parents=True, exist_ok=True)
            file_path = self.project_dir / "index.html"
            file_path.write_text(page.html)
        except Exception as e:
            print(f"Could not save file (non-critical): {e}", flush=True)

        # Keep all 3 layouts - just mark which one is selected
        # (Previously we deleted alternatives - now we keep them for browsing)
        self.project.selected_layout = variant
        self.project.status = ProjectStatus.EDITING
        self.db.commit()

        self.log("layouts", f"Selected layout {variant}")

    def edit_page(self, page_id: str, instruction: str) -> str:
        """Edit a page based on instruction"""
        page = self.db.query(Page).filter(Page.id == page_id).first()
        if not page:
            raise ValueError("Page not found")

        self.log("edit", f"Editing: {instruction}")

        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
            max_tokens=8000,
            system="""You are a web developer. Modify the HTML code based on the instruction.
Respond ONLY with the updated HTML code, nothing else.""",
            messages=[
                {"role": "user", "content": f"Current HTML:\n```html\n{page.html}\n```\n\nInstruction: {instruction}"}
            ]
        )

        self.track_usage(response)

        # Extract HTML from response
        new_html = response.content[0].text
        if "```html" in new_html:
            new_html = new_html.split("```html")[1].split("```")[0]
        elif "```" in new_html:
            new_html = new_html.split("```")[1].split("```")[0]

        # Update page
        page.html = new_html.strip()
        self.db.commit()

        # Try to save to file (optional)
        try:
            file_name = "index.html" if page.name == "Home" else f"{page.name.lower()}.html"
            file_path = self.project_dir / file_name
            self.project_dir.mkdir(parents=True, exist_ok=True)
            file_path.write_text(page.html)
        except Exception:
            pass  # File storage optional

        self.log("edit", "Edit complete")
        return page.html

    def add_page(self, name: str, description: str = None) -> Page:
        """Add a new page to the project"""
        # Get existing pages for context
        existing = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == None
        ).first()

        self.log("edit", f"Creating new page: {name}")

        prompt = f"Create a new page '{name}' in the same style as the main page."
        if description:
            prompt += f" Description: {description}"

        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
            max_tokens=8000,
            system=f"""You are a web developer. Create a new HTML page that matches the style.

Moodboard: {json.dumps(self.project.moodboard)}

Existing page for reference:
```html
{existing.html if existing else ''}
```

Respond ONLY with complete HTML code.""",
            messages=[
                {"role": "user", "content": prompt}
            ]
        )

        self.track_usage(response)

        html = response.content[0].text
        if "```html" in html:
            html = html.split("```html")[1].split("```")[0]
        elif "```" in html:
            html = html.split("```")[1].split("```")[0]

        # Create page
        page = Page(
            project_id=self.project.id,
            name=name,
            html=html.strip()
        )
        self.db.add(page)
        self.db.commit()

        # Try to save to file (optional)
        try:
            self.project_dir.mkdir(parents=True, exist_ok=True)
            file_path = self.project_dir / f"{name.lower()}.html"
            file_path.write_text(page.html)
        except Exception:
            pass  # File storage optional

        self.log("edit", f"Page '{name}' created")
        return page
