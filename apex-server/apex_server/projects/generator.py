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
        """Generate 3 moodboard alternatives based on the brief"""
        self.log("moodboard", "Generating 3 moodboard alternatives...")

        # Define tool for structured output
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
                                "name": {"type": "string", "description": "Short style name"},
                                "palette": {"type": "array", "items": {"type": "string"}, "description": "5 hex colors"},
                                "fonts": {
                                    "type": "object",
                                    "properties": {
                                        "heading": {"type": "string"},
                                        "body": {"type": "string"}
                                    },
                                    "required": ["heading", "body"]
                                },
                                "mood": {"type": "array", "items": {"type": "string"}, "description": "3 mood keywords"},
                                "rationale": {"type": "string", "description": "Brief explanation"}
                            },
                            "required": ["name", "palette", "fonts", "mood", "rationale"]
                        }
                    }
                },
                "required": ["moodboards"]
            }
        }

        response = self.client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[
                {"role": "user", "content": f"""Create THREE different moodboard alternatives for this website brief:

Brief: {self.project.brief}

Each moodboard should have a DISTINCT style:
1. One minimalist/modern
2. One warm/organic
3. One bold/expressive

Use Google Fonts names. Choose 5 colors per palette that fit the brief."""}
            ]
        )

        self.track_usage(response)

        # Extract structured data from tool use
        moodboards = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])

        # Save all moodboards to project (as a list)
        self.project.moodboard = {"moodboards": moodboards}
        self.project.status = ProjectStatus.MOODBOARD
        self.db.commit()

        self.log("moodboard", f"Created {len(moodboards)} moodboard alternatives", {"count": len(moodboards)})
        return moodboards

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
            model="claude-sonnet-4-20250514",
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
            # Save HTML file
            file_path = self.project_dir / f"layout_{i}.html"
            file_path.parent.mkdir(parents=True, exist_ok=True)
            file_path.write_text(layout["html"])

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
        """Select a layout and move to editing phase"""
        page = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == variant
        ).first()

        if not page:
            raise ValueError(f"Layout {variant} not found")

        # Save as index.html
        file_path = self.project_dir / "index.html"
        file_path.write_text(page.html)

        # Update page to be the main page
        page.name = "Home"
        page.layout_variant = None  # No longer a variant

        # Remove other layout variants
        self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant != None,
            Page.id != page.id
        ).delete()

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
            model="claude-sonnet-4-20250514",
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

        # Save to file
        file_name = "index.html" if page.name == "Home" else f"{page.name.lower()}.html"
        file_path = self.project_dir / file_name
        file_path.write_text(page.html)

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
            model="claude-sonnet-4-20250514",
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

        # Save to file
        file_path = self.project_dir / f"{name.lower()}.html"
        file_path.write_text(page.html)

        self.log("edit", f"Page '{name}' created")
        return page
