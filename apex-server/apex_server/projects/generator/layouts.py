"""Layout generation mixin - creates 3 layouts inspired by 3 different sites"""
import re
import time
from typing import TYPE_CHECKING

from .utils import MODEL_OPUS, inject_google_fonts

if TYPE_CHECKING:
    from .base import Generator


class LayoutsMixin:
    """Mixin for layout generation methods"""

    def generate_layouts(self: "Generator") -> list[dict]:
        """
        Generate 3 layout alternatives, each inspired by one of the 3 inspiration sites.

        Uses:
        - REAL brand colors from company's actual website
        - 3 different inspiration sites for 3 different designs
        """
        from ..models import Page, PageVersion, ProjectStatus

        layouts_start = time.time()
        print("[GENERATE_LAYOUTS] Starting...", flush=True)
        self.log("layouts", "Generating 3 layouts from inspiration sites...")

        # Get research data
        research_data = self.project.moodboard
        if not research_data:
            raise ValueError("Research data missing - run research_brand first")

        # Extract brand colors (from company's actual site)
        brand_colors = research_data.get("brand_colors", [])
        if not brand_colors or len(brand_colors) < 3:
            brand_colors = ["#1a1a1a", "#ffffff", "#0066cc"]

        primary_color = brand_colors[0]
        secondary_color = brand_colors[1]
        accent_color = brand_colors[2]

        # Get fonts
        fonts = research_data.get("fonts", {"heading": "Inter", "body": "Inter"})

        # Get inspiration sites
        inspiration_sites = research_data.get("inspiration_sites", [])
        if len(inspiration_sites) < 3:
            raise ValueError("Need at least 3 inspiration sites")

        print(f"[GENERATE_LAYOUTS] Brand colors: {brand_colors}", flush=True)
        print(f"[GENERATE_LAYOUTS] Fonts: {fonts}", flush=True)
        print(f"[GENERATE_LAYOUTS] Inspiration sites: {[s.get('name') for s in inspiration_sites]}", flush=True)

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
                                "inspired_by": {"type": "string", "description": "Name of the inspiration site"},
                                "description": {"type": "string", "description": "Short description"},
                                "html": {"type": "string", "description": "Complete HTML with inline CSS"}
                            },
                            "required": ["name", "inspired_by", "description", "html"]
                        }
                    }
                },
                "required": ["layouts"]
            }
        }

        # Format inspiration sites for prompt
        inspiration_details = ""
        for i, site in enumerate(inspiration_sites[:3], 1):
            inspiration_details += f"""
═══════════════════════════════════════════════════════════════
LAYOUT {i} - Inspired by: {site.get('name', 'Unknown')}
═══════════════════════════════════════════════════════════════
Website: {site.get('url', '')}
Design Style: {site.get('design_style', '')}
Why inspiring: {site.get('why', '')}
Key elements to borrow: {', '.join(site.get('key_elements', []))}
"""

        opus_start = time.time()
        print(f"[GENERATE_LAYOUTS] Calling Opus...", flush=True)

        response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=20000,
            tools=[layout_tool],
            tool_choice={"type": "tool", "name": "save_layouts"},
            messages=[
                {"role": "user", "content": f"""Create THREE world-class hero section designs, each inspired by a different reference website.

Brief: {self.project.brief}

═══════════════════════════════════════════════════════════════
MANDATORY BRAND COLORS (from the company's REAL website):
═══════════════════════════════════════════════════════════════
PRIMARY:   {primary_color}  ← Use for: backgrounds, main text, headers
SECONDARY: {secondary_color}  ← Use for: backgrounds, cards, contrast areas
ACCENT:    {accent_color}  ← Use for: CTA buttons, links, highlights

These are the ACTUAL brand colors from the company's website.
You MUST use these exact hex codes. Do NOT change them.

═══════════════════════════════════════════════════════════════
TYPOGRAPHY:
═══════════════════════════════════════════════════════════════
Heading font: {fonts.get('heading', 'Inter')}
Body font: {fonts.get('body', 'Inter')}

═══════════════════════════════════════════════════════════════
YOUR TASK: Create 3 layouts, each inspired by one reference site
═══════════════════════════════════════════════════════════════
{inspiration_details}

═══════════════════════════════════════════════════════════════
DESIGN PRINCIPLES:
═══════════════════════════════════════════════════════════════
1. WHITESPACE: Generous padding and margins. Let elements breathe.
   - Hero padding: at least 80-120px vertical
   - Text max-width: 600-800px for readability

2. TYPOGRAPHY HIERARCHY: Create clear visual hierarchy
   - Headline: clamp(2.5rem, 6vw, 5rem) - bold and impactful
   - Subheadline: 1.125-1.25rem - lighter weight, good line-height (1.6-1.8)

3. MICRO-INTERACTIONS: Subtle hover effects
   - Buttons: transform, box-shadow on hover
   - Links: smooth color transitions
   - transition: all 0.3s ease

4. VISUAL POLISH:
   - Subtle shadows for depth (box-shadow with low opacity)
   - Border-radius for modern feel (8-16px for cards, 4-8px for buttons)
   - Gradient overlays on images for text readability

5. RESPONSIVE: Use clamp() for fluid typography, mobile-first approach

═══════════════════════════════════════════════════════════════
IMAGE USAGE:
═══════════════════════════════════════════════════════════════
For placeholder images, use Unsplash Source with relevant keywords:
https://source.unsplash.com/1600x900/?[keyword]

Examples based on industry:
- Golf: https://source.unsplash.com/1600x900/?golf,green
- Restaurant: https://source.unsplash.com/1600x900/?restaurant,food
- Tech/SaaS: https://source.unsplash.com/1600x900/?technology,minimal
- Business: https://source.unsplash.com/1600x900/?office,professional

Choose keywords that match the brand!

═══════════════════════════════════════════════════════════════
IMPORTANT: Each layout must:
═══════════════════════════════════════════════════════════════
1. Use the EXACT brand colors above (no variations!)
2. Be clearly inspired by its reference site's design style
3. Borrow specific design elements mentioned for each site
4. Be a COMPLETE HTML file with all CSS in <style> tag
5. Be unique and different from the other layouts

The layouts should look like they came from a professional design agency."""}
            ]
        )

        self.track_usage(response)
        print(f"[TIMING] Opus layout generation: {time.time() - opus_start:.1f}s", flush=True)
        print(f"[GENERATE_LAYOUTS] Opus response received, stop_reason: {response.stop_reason}", flush=True)

        # Extract structured data from tool use
        layouts = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_layouts":
                layouts = block.input.get("layouts", [])

        print(f"[GENERATE_LAYOUTS] Extracted {len(layouts)} layouts", flush=True)

        # Initialize filesystem for project
        self.fs.init_project()

        # Save layouts as pages
        for i, layout in enumerate(layouts, 1):
            # Inject Google Fonts based on fonts config
            html = layout["html"]
            html = inject_google_fonts(html, fonts)

            # Create page record in PostgreSQL
            page = Page(
                project_id=self.project.id,
                name=layout.get("name", f"Layout {i}"),
                html=html,  # Keep in DB during migration
                layout_variant=i
            )
            self.db.add(page)
            self.db.flush()  # Get page ID

            # Save to filesystem
            file_name = f"layout_{i}.html"
            self.fs.write_file(f"public/{file_name}", html)

            # Save v1 to versions (both filesystem and PostgreSQL)
            self.fs.save_version(str(page.id), 1, html)

            # Create PageVersion record in PostgreSQL
            page_version = PageVersion(
                page_id=page.id,
                version=1,
                html=html,
                instruction=f"Inspired by {layout.get('inspired_by', 'reference site')}"
            )
            self.db.add(page_version)

            print(f"[GENERATE_LAYOUTS] Saved {file_name} - inspired by {layout.get('inspired_by', 'unknown')}", flush=True)

        # Git commit
        self.fs.git_commit("Generated layouts")

        self.project.status = ProjectStatus.LAYOUTS
        self.db.commit()

        print(f"[TIMING] TOTAL layout generation: {time.time() - layouts_start:.1f}s", flush=True)
        self.log("layouts", f"Created {len(layouts)} layouts", {"count": len(layouts)})
        return layouts

    def _extract_layouts_fallback(self: "Generator", text: str) -> list[dict]:
        """Fallback: extract HTML blocks when JSON parsing fails"""
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

    def select_layout(self: "Generator", variant: int):
        """Select a layout and move to editing phase (keeps all 3 alternatives)"""
        from ..models import Page, ProjectStatus

        page = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == variant
        ).first()

        if not page:
            raise ValueError(f"Layout {variant} not found")

        # Keep all 3 layouts - just mark which one is selected
        self.project.selected_layout = variant
        self.project.status = ProjectStatus.EDITING
        self.db.commit()

        self.log("layouts", f"Selected layout {variant}")
