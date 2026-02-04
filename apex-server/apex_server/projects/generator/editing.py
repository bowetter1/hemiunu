"""Page editing mixin"""
import json
from typing import TYPE_CHECKING

from .utils import MODEL_SONNET, with_retry, inject_google_fonts

if TYPE_CHECKING:
    from .base import Generator


class EditingMixin:
    """Mixin for page editing methods"""

    def edit_page(self: "Generator", page_id: str, instruction: str) -> str:
        """Edit a page based on instruction"""
        from ..models import Page

        page = self.db.query(Page).filter(Page.id == page_id).first()
        if not page:
            raise ValueError("Page not found")

        self.log("edit", f"Editing: {instruction}")

        def make_request():
            return self.client.messages.create(
                model=MODEL_SONNET,  # Sonnet for fast edits
                max_tokens=8000,
                system="""You are a web developer. Modify the HTML code based on the instruction.
Respond ONLY with the updated HTML code, nothing else.""",
                messages=[
                    {"role": "user", "content": f"Current HTML:\n```html\n{page.html}\n```\n\nInstruction: {instruction}"}
                ]
            )

        response = with_retry(make_request)
        self.track_usage(response)

        # Extract HTML from response
        new_html = response.content[0].text
        if "```html" in new_html:
            new_html = new_html.split("```html")[1].split("```")[0]
        elif "```" in new_html:
            new_html = new_html.split("```")[1].split("```")[0]

        new_html = new_html.strip()

        # Inject Google Fonts from moodboard.fonts
        moodboard = self.project.moodboard or {}
        if isinstance(moodboard, dict):
            fonts = moodboard.get("fonts")
            if fonts:
                new_html = inject_google_fonts(new_html, fonts)

        # Update page
        page.html = new_html
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

    def add_page(self: "Generator", name: str, description: str = None) -> "Page":
        """Add a new page to the project"""
        from ..models import Page

        # Get existing pages for context
        existing = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == None
        ).first()

        self.log("edit", f"Creating new page: {name}")

        prompt = f"Create a new page '{name}' in the same style as the main page."
        if description:
            prompt += f" Description: {description}"

        # Get design context from pipeline file
        design_brief_md = self.fs.read_pipeline_file("04-design-brief.md")
        design_context = f"Design Brief:\n{design_brief_md}" if design_brief_md else ""

        def make_request():
            return self.client.messages.create(
                model=MODEL_SONNET,  # Sonnet for new pages
                max_tokens=8000,
                system=f"""You are a web developer. Create a new HTML page that matches the style.

{design_context}

Existing page for reference:
```html
{existing.html if existing else ''}
```

Respond ONLY with complete HTML code.""",
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

        response = with_retry(make_request)
        self.track_usage(response)

        html = response.content[0].text
        if "```html" in html:
            html = html.split("```html")[1].split("```")[0]
        elif "```" in html:
            html = html.split("```")[1].split("```")[0]

        html = html.strip()

        # Inject Google Fonts from moodboard.fonts
        moodboard = self.project.moodboard or {}
        if isinstance(moodboard, dict):
            fonts = moodboard.get("fonts")
            if fonts:
                html = inject_google_fonts(html, fonts)

        # Create page
        page = Page(
            project_id=self.project.id,
            name=name,
            html=html
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
