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

        # Get research markdown (primary source of design context)
        research_md = self.project.research_md or ""

        # Get structured data from moodboard (for colors, fonts, site names)
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

        # Get fonts (needed for inject_google_fonts)
        fonts = research_data.get("fonts", {"heading": "Inter", "body": "Inter"})

        # Get inspiration site names (for layout naming)
        inspiration_sites = research_data.get("inspiration_sites", [])

        print(f"[GENERATE_LAYOUTS] Research markdown: {len(research_md)} chars", flush=True)
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

        opus_start = time.time()
        print(f"[GENERATE_LAYOUTS] Calling Opus with research markdown context...", flush=True)

        # Give Opus web search (reduced - backup only), layout tool, AND image generation tool
        image_tool = self.get_image_tools()[0]
        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 2  # Backup only - research markdown has the details
        }

        # Build the initial prompt using research markdown as primary context
        initial_prompt = f"""Create THREE world-class hero section designs, each inspired by a different reference website.

═══════════════════════════════════════════════════════════════
RESEARCH REPORT (from our brand researcher):
═══════════════════════════════════════════════════════════════
{research_md}

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
PROJECT BRIEF:
═══════════════════════════════════════════════════════════════
{self.project.brief}

═══════════════════════════════════════════════════════════════
YOUR TASK: Create 3 layouts, each inspired by one of the 3 inspiration sites described above.
═══════════════════════════════════════════════════════════════
Use the DETAILED design analysis from the research report above. Each layout should clearly
borrow the design style, layout patterns, typography approach, and key elements described
for its corresponding inspiration site.

You have web_search available as backup if you need to verify something, but the research
report above should contain everything you need.

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
IMAGES - USE generate_image TOOL:
═══════════════════════════════════════════════════════════════
Generate real images using the generate_image tool.
For each layout that needs a hero image, call generate_image first.
Use size "1536x1024" for hero/landscape images.
The tool returns a path like "images/hero1.png" - use that in your HTML.

═══════════════════════════════════════════════════════════════
IMPORTANT: Each layout must:
═══════════════════════════════════════════════════════════════
1. Use the EXACT brand colors above (no variations!)
2. Be clearly inspired by its reference site's design style
3. Borrow specific design elements mentioned for each site
4. Be a COMPLETE HTML file with all CSS in <style> tag
5. Be unique and different from the other layouts

The layouts should look like they came from a professional design agency."""

        response = self.client.beta.messages.create(
            model=MODEL_OPUS,
            max_tokens=20000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool, layout_tool, image_tool],
            messages=[{"role": "user", "content": initial_prompt}]
        )

        self.track_usage(response)

        # Initialize filesystem early (needed for image generation)
        self.fs.init_project()

        # Agentic loop - process tool calls until we get save_layouts
        layouts = []
        max_iterations = 15  # More iterations since web search takes extra turns
        # Start with the initial user message for context in continuations
        conversation_messages = [{"role": "user", "content": initial_prompt}]

        for iteration in range(max_iterations):
            print(f"[GENERATE_LAYOUTS] Iteration {iteration + 1}, stop_reason: {response.stop_reason}", flush=True)

            # Check for tool use and web search results
            tool_results = []
            has_web_search = False

            for block in response.content:
                # Log web search activity
                if block.type == "server_tool_use" and getattr(block, 'name', '') == "web_search":
                    query = getattr(block, 'input', {}).get('query', '')
                    print(f"[GENERATE_LAYOUTS] Web search: {query}", flush=True)
                    has_web_search = True

                if block.type == "web_search_tool_result":
                    print(f"[GENERATE_LAYOUTS] Got web search results", flush=True)
                    has_web_search = True

                if block.type == "tool_use":
                    if block.name == "save_layouts":
                        # Done! Extract layouts
                        layouts = block.input.get("layouts", [])
                        print(f"[GENERATE_LAYOUTS] Got {len(layouts)} layouts", flush=True)
                        break
                    elif block.name == "generate_image":
                        # Execute image generation
                        print(f"[GENERATE_LAYOUTS] Generating image: {block.input.get('filename')}", flush=True)
                        result = self.execute_image_tool(block.name, block.input)
                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": result
                        })

            # If we got layouts, we're done
            if layouts:
                break

            # If stop_reason is "end_turn" and no tool calls, Opus is done (web search complete)
            if response.stop_reason == "end_turn" and not tool_results and not has_web_search:
                print("[GENERATE_LAYOUTS] End turn without layouts - prompting to continue", flush=True)
                # Prompt Opus to now create the layouts
                conversation_messages.append({"role": "assistant", "content": [b.model_dump() for b in response.content]})
                conversation_messages.append({"role": "user", "content": "Great! Now that you've studied the inspiration sites, please create the 3 layouts using the save_layouts tool."})

                response = self.client.beta.messages.create(
                    model=MODEL_OPUS,
                    max_tokens=20000,
                    betas=["web-search-2025-03-05"],
                    tools=[web_search_tool, layout_tool, image_tool],
                    messages=conversation_messages
                )
                self.track_usage(response)
                continue

            # If we have tool results to send back (image generation)
            if tool_results:
                conversation_messages.append({"role": "assistant", "content": [b.model_dump() for b in response.content]})
                conversation_messages.append({"role": "user", "content": tool_results})

                response = self.client.beta.messages.create(
                    model=MODEL_OPUS,
                    max_tokens=20000,
                    betas=["web-search-2025-03-05"],
                    tools=[web_search_tool, layout_tool, image_tool],
                    messages=conversation_messages
                )
                self.track_usage(response)
                continue

            # If stop_reason is "tool_use" but we didn't find any tools we handle, break
            if response.stop_reason == "tool_use" and not tool_results and not has_web_search:
                print("[GENERATE_LAYOUTS] Unknown tool use, breaking", flush=True)
                break

        print(f"[TIMING] Opus layout generation: {time.time() - opus_start:.1f}s", flush=True)

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
