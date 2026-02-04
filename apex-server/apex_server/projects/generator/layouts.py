"""Layout generation mixin - creates 3 layouts inspired by 3 different sites"""
import json
import re
import time
from typing import TYPE_CHECKING

from .utils import MODEL_SONNET, MODEL_OPUS, inject_google_fonts
from .tool_policy import build_layout_tools, resolve_image_source

if TYPE_CHECKING:
    from .base import Generator


class LayoutsMixin:
    """Mixin for layout generation methods"""

    def generate_layouts(self: "Generator") -> list[dict]:
        """
        Generate layout alternatives, each inspired by an inspiration site.
        Routes to Anthropic (Claude) or OpenAI based on layout_provider config.
        """
        layout_provider = self.get_config("layout_provider", "anthropic")
        print(f"[GENERATE_LAYOUTS] Provider: {layout_provider}", flush=True)

        if layout_provider == "openai":
            return self._generate_layouts_openai()
        else:
            return self._generate_layouts_anthropic()

    def _generate_layouts_anthropic(self: "Generator") -> list[dict]:
        """
        Generate layouts using Anthropic Claude (Sonnet/Opus).
        """
        from ..models import Page, PageVersion, ProjectStatus

        layouts_start = time.time()
        print("[GENERATE_LAYOUTS] Starting (Anthropic)...", flush=True)

        # Resolve layout model from config
        layout_model_key = self.get_config("layout_model", "sonnet")
        layout_model = {"sonnet": MODEL_SONNET, "opus": MODEL_OPUS}.get(layout_model_key, MODEL_SONNET)
        layout_count = self.get_config("layout_count", 1)
        allow_web_search = self.get_config("web_search_during_layout", True)
        print(f"[GENERATE_LAYOUTS] Model: {layout_model}, count: {layout_count}, web_search: {allow_web_search}", flush=True)

        self.log("layouts", f"Generating {layout_count} layout(s)...")

        # Get research markdown from pipeline file
        research_md = self.fs.read_pipeline_file("03-research.md") or ""

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

        # Get company images from 04-design-brief.md
        company_images = []
        design_brief_md = self.fs.read_pipeline_file("04-design-brief.md")
        if design_brief_md and "## Company Images" in design_brief_md:
            import re as _re
            paths = _re.findall(r'\*\*Path:\*\*\s*(.+)', design_brief_md)
            for p in paths:
                company_images.append({"path": p.strip(), "description": "Company image"})

        image_source, did_fallback = resolve_image_source(self.project.image_source, bool(company_images))
        if did_fallback:
            print("[GENERATE_LAYOUTS] No company images found, falling back to AI generation", flush=True)
        print(f"[GENERATE_LAYOUTS] Image source preference: {image_source}", flush=True)

        # Get existing site analysis (Haiku vision analysis of their current website)
        existing_site_analysis = research_data.get("existing_site_analysis", "")

        # Build existing site analysis section for prompt
        existing_site_section = ""
        if existing_site_analysis:
            existing_site_section = f"""
═══════════════════════════════════════════════════════════════
EXISTING WEBSITE ANALYSIS (their current site):
═══════════════════════════════════════════════════════════════
{existing_site_analysis}

Your layout should feel like a PREMIUM UPGRADE of their current site.
Keep what works. Fix what doesn't. Elevate the overall quality.
"""

        print(f"[GENERATE_LAYOUTS] Research markdown: {len(research_md)} chars", flush=True)
        print(f"[GENERATE_LAYOUTS] Brand colors: {brand_colors}", flush=True)
        print(f"[GENERATE_LAYOUTS] Fonts: {fonts}", flush=True)
        print(f"[GENERATE_LAYOUTS] Inspiration sites: {[s.get('name') for s in inspiration_sites]}", flush=True)
        print(f"[GENERATE_LAYOUTS] Company images: {len(company_images)} available", flush=True)

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

        model_start = time.time()
        print(f"[GENERATE_LAYOUTS] Calling Sonnet with research markdown context...", flush=True)

        tools_for_layouts = build_layout_tools(
            generator=self,
            layout_tool=layout_tool,
            image_source=image_source,
            has_company_images=bool(company_images),
            allow_web_search=allow_web_search,
        )

        # Build the initial prompt using research markdown as primary context
        count_word = {1: "ONE", 2: "TWO", 3: "THREE"}.get(layout_count, str(layout_count))
        if layout_count == 1:
            count_intro = f"Create {count_word} world-class landing page with a hero section, inspired by the BEST reference website from the research report."
            count_scope = "SCOPE: Build ONLY a single hero/start page. This is a ONE-PAGE design — just the hero section and navigation. Keep it focused. We will add more sections later."
        else:
            count_intro = f"Create {count_word} world-class hero section designs, each inspired by a different reference website."
            count_scope = "SCOPE: Build ONLY hero/start pages. Each design is a ONE-PAGE layout — just the hero section and navigation. Keep them focused."

        initial_prompt = f"""{count_intro}

{count_scope}

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
{existing_site_section}
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
YOUR TASK: Create {layout_count} layout(s), {"inspired by the BEST inspiration site from the research report above." if layout_count == 1 else "each inspired by a different inspiration site from the research report above."}
═══════════════════════════════════════════════════════════════
{"Pick the inspiration site with the best design quality and most relevant style." if layout_count == 1 else "Each layout should be clearly inspired by a different reference site."}
Use the DETAILED design analysis from the research report above. {"The layout" if layout_count == 1 else "Each layout"} should clearly
borrow the design style, layout patterns, typography approach, and key elements described
for {"that" if layout_count == 1 else "its corresponding"} inspiration site.

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
IMAGES — YOU ARE THE ART DIRECTOR:
═══════════════════════════════════════════════════════════════
{self._format_image_tools_prompt(company_images, image_source)}

Each tool returns a path like "images/hero1.png" — use that path in your HTML.
{self._image_usage_note(image_source)}

═══════════════════════════════════════════════════════════════
IMPORTANT: Each layout must:
═══════════════════════════════════════════════════════════════
1. Use the EXACT brand colors above (no variations!)
2. Be clearly inspired by the chosen reference site's design style
3. Borrow specific design elements mentioned for that site
4. Be a COMPLETE HTML file with all CSS in <style> tag
{"5. Be unique and different from the other layouts" if layout_count > 1 else ""}

The layouts should look like they came from a professional design agency."""

        response = self.client.beta.messages.create(
            model=layout_model,
            max_tokens=20000,
            betas=["web-search-2025-03-05"],
            tools=tools_for_layouts,
            messages=[{"role": "user", "content": initial_prompt}]
        )

        self.track_usage(response)

        # Initialize filesystem early (needed for image generation)
        self.fs.init_project()

        def serialize_assistant_content(content_blocks):
            """Serialize assistant content blocks, filtering out web search internals that cause API errors."""
            serialized = []
            for block in content_blocks:
                if block.type in ("server_tool_use", "web_search_tool_result"):
                    # Skip web search internal blocks — API rejects them on re-send
                    continue
                dumped = block.model_dump()
                # Remove 'caller' field from tool_use blocks (beta artifact)
                if block.type == "tool_use" and "caller" in dumped:
                    del dumped["caller"]
                # Remove citations from text blocks — they reference filtered web search results
                if block.type == "text" and "citations" in dumped:
                    del dumped["citations"]
                serialized.append(dumped)
            return serialized

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
                        # Execute image generation — use img2img if reference_image provided
                        ref_path = block.input.get("reference_image")
                        print(f"[GENERATE_LAYOUTS] Generating image: {block.input.get('filename')} (ref={ref_path})", flush=True)

                        if ref_path and company_images:
                            # img2img: read reference bytes from filesystem and use edit endpoint
                            ref_full = f"public/{ref_path}"
                            ref_bytes = self.fs.read_binary(ref_full)
                            if ref_bytes:
                                edit_result = self.edit_image_from_reference(
                                    reference_bytes=ref_bytes,
                                    prompt=block.input.get("prompt", ""),
                                    filename=block.input.get("filename", "hero.png"),
                                    size=block.input.get("size", "1536x1024"),
                                    quality=block.input.get("quality", "medium"),
                                )
                                result = json.dumps(edit_result)
                            else:
                                print(f"[GENERATE_LAYOUTS] Reference image not found: {ref_full}, falling back to generate", flush=True)
                                result = self.execute_image_tool(block.name, block.input)
                        else:
                            result = self.execute_image_tool(block.name, block.input)

                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": block.id,
                            "content": result
                        })
                    elif block.name == "stock_photo":
                        # Execute stock photo search
                        print(f"[GENERATE_LAYOUTS] Stock photo: {block.input.get('query')} → {block.input.get('filename')}", flush=True)
                        result = self.execute_stock_photo(block.input)
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
                conversation_messages.append({"role": "assistant", "content": serialize_assistant_content(response.content)})
                conversation_messages.append({"role": "user", "content": f"Great! Now please create the {layout_count} layout(s) using the save_layouts tool."})

                response = self.client.beta.messages.create(
                    model=layout_model,
                    max_tokens=20000,
                    betas=["web-search-2025-03-05"],
                    tools=tools_for_layouts,
                    messages=conversation_messages
                )
                self.track_usage(response)
                continue

            # If we have tool results to send back (image generation)
            if tool_results:
                conversation_messages.append({"role": "assistant", "content": serialize_assistant_content(response.content)})
                conversation_messages.append({"role": "user", "content": tool_results})

                response = self.client.beta.messages.create(
                    model=layout_model,
                    max_tokens=20000,
                    betas=["web-search-2025-03-05"],
                    tools=tools_for_layouts,
                    messages=conversation_messages
                )
                self.track_usage(response)
                continue

            # If stop_reason is "tool_use" but we didn't find any tools we handle, break
            if response.stop_reason == "tool_use" and not tool_results and not has_web_search:
                print("[GENERATE_LAYOUTS] Unknown tool use, breaking", flush=True)
                break

        print(f"[TIMING] Sonnet layout generation: {time.time() - model_start:.1f}s", flush=True)

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

    def _format_image_tools_prompt(self: "Generator", company_images: list[dict], image_source: str) -> str:
        """Build the image tools section of the prompt, adapting to available resources."""
        if image_source == "none":
            return """Do NOT use any images. Do not add <img> tags or background images.
Use typography, layout, gradients, shapes, and color blocks for visual interest."""

        if image_source == "existing_images":
            if company_images:
                img_list = "\n".join(
                    f"  - {img['path']}: {img.get('description', 'Company image')}"
                    for img in company_images
                )
                return f"""You must ONLY use existing company images (no generation).
Use the image paths below directly in HTML.

AVAILABLE COMPANY IMAGES:
{img_list}"""
            return """No usable company images were found.
Fallback: Use generate_image (AI) only."""

        if image_source == "img2img":
            if company_images:
                img_list = "\n".join(
                    f"  - {img['path']}: {img.get('description', 'Company image')}"
                    for img in company_images
                )
                return f"""You may ONLY use generate_image WITH reference_image (img2img).

TOOL: "generate_image" with reference_image
  Uses a real photo from the company's website as starting point.
  The result KEEPS the feel of the original but is restyled.
  → Best for: hero images that should look like the company's real venue/environment.
  Parameters: prompt, filename, size ("1536x1024" landscape, "1024x1536" portrait, "1024x1024" square), reference_image (path from list below)

AVAILABLE COMPANY IMAGES (scraped from their real website):
{img_list}"""
            return """No usable company images were found.
Fallback: Use generate_image (AI) only."""

        if image_source == "stock":
            return """You may ONLY use the stock_photo tool for images.

TOOL: "stock_photo" (real photography from Pexels)
  Downloads a real, high-quality photograph.
  → Best for: people, venues, nature, food, professional environments — anything where photorealism matters.
  → IMPORTANT: query must be SHORT (2-4 words). Pexels is a search engine, not a prompt.
    ✅ Good: "farm sunset landscape", "hotel lobby luxury", "conference room modern"
    ❌ Bad: "scandinavian countryside farm golden hour pastoral landscape with rolling hills"
  Parameters: query (2-4 words!), filename, orientation ("landscape", "portrait", "square"), size ("large", "medium", "small")"""

        # Default: AI-only
        return """You may ONLY use generate_image (AI).

TOOL: "generate_image"
  Generates an image from scratch using GPT-Image.
  → Best for: abstract backgrounds, artistic illustrations, stylized brand visuals.
  Parameters: prompt, filename, size ("1536x1024" landscape, "1024x1536" portrait, "1024x1024" square), quality ("low", "medium", "high")"""

    def _image_usage_note(self: "Generator", image_source: str) -> str:
        """Add a short rule about image usage to the prompt."""
        if image_source == "none":
            return "IMPORTANT: Do not use any images."
        if image_source == "existing_images":
            return "IMPORTANT: Use at most 1 existing company image. Do not generate new images."
        if image_source == "img2img":
            return "IMPORTANT: Generate only 1 image (the hero) using reference_image."
        if image_source == "stock":
            return "IMPORTANT: Use only 1 stock image (the hero)."
        return "IMPORTANT: Generate only 1 image (the hero)."

    def _generate_layouts_openai(self: "Generator") -> list[dict]:
        """
        Generate layouts using OpenAI (GPT-4o).
        Simpler flow: one completion call, extract HTML from response.
        No web search or image tool support — just layout HTML.
        """
        from ..models import Page, PageVersion, ProjectStatus
        from openai import OpenAI
        from apex_server.config import get_settings

        settings = get_settings()

        layouts_start = time.time()
        print("[GENERATE_LAYOUTS] Starting (OpenAI)...", flush=True)

        layout_count = self.get_config("layout_count", 1)
        print(f"[GENERATE_LAYOUTS] OpenAI, count: {layout_count}", flush=True)

        self.log("layouts", f"Generating {layout_count} layout(s) with OpenAI...")

        # Get research data from pipeline file
        research_md = self.fs.read_pipeline_file("03-research.md") or ""
        research_data = self.project.moodboard
        if not research_data:
            raise ValueError("Research data missing - run research_brand first")

        brand_colors = research_data.get("brand_colors", ["#1a1a1a", "#ffffff", "#0066cc"])
        while len(brand_colors) < 3:
            brand_colors.append("#0066cc")
        primary_color, secondary_color, accent_color = brand_colors[0], brand_colors[1], brand_colors[2]

        fonts = research_data.get("fonts", {"heading": "Inter", "body": "Inter"})

        # Company images from 04-design-brief.md
        company_images = []
        design_brief_md = self.fs.read_pipeline_file("04-design-brief.md")
        if design_brief_md and "## Company Images" in design_brief_md:
            import re as _re
            paths = _re.findall(r'\*\*Path:\*\*\s*(.+)', design_brief_md)
            for p in paths:
                company_images.append({"path": p.strip(), "description": "Company image"})

        # Build image instructions (no tool use, just reference paths)
        image_instruction = "Do NOT include any <img> tags. Use CSS gradients, shapes, and color blocks for visual interest instead."
        if company_images:
            img_path = company_images[0].get("path", "")
            image_instruction = f'Use this image for the hero: <img src="{img_path}">. Only use this one image.'

        count_word = {1: "ONE", 2: "TWO", 3: "THREE"}.get(layout_count, str(layout_count))

        prompt = f"""Create {count_word} world-class landing page layout(s) as complete HTML files with inline CSS.

RESEARCH REPORT:
{research_md}

BRAND COLORS:
PRIMARY: {primary_color}
SECONDARY: {secondary_color}
ACCENT: {accent_color}

TYPOGRAPHY:
Heading font: {fonts.get('heading', 'Inter')}
Body font: {fonts.get('body', 'Inter')}

PROJECT BRIEF:
{self.project.brief}

IMAGES:
{image_instruction}

REQUIREMENTS:
- Each layout is a COMPLETE HTML file (<!DOCTYPE html> through </html>)
- All CSS must be in a <style> tag (no external stylesheets except Google Fonts)
- Include a Google Fonts <link> for the specified fonts
- Use the EXACT brand colors above
- Responsive design with clamp() for typography
- Generous whitespace, elegant micro-interactions (hover effects)
- Professional agency quality

{"Each layout must be inspired by a different design approach (e.g., one minimal, one bold, one image-heavy)." if layout_count > 1 else ""}

Return your response as a JSON object with this structure:
{{
  "layouts": [
    {{
      "name": "Layout name",
      "inspired_by": "Inspiration source",
      "description": "Short description",
      "html": "<!DOCTYPE html>..."
    }}
  ]
}}

Return ONLY the JSON. No markdown code fences, no explanation text."""

        # Call OpenAI
        openai_client = OpenAI(api_key=settings.openai_api_key)

        model_start = time.time()
        print("[GENERATE_LAYOUTS] Calling OpenAI GPT-4o...", flush=True)

        completion = openai_client.chat.completions.create(
            model="gpt-4o",
            max_tokens=16000,
            temperature=0.7,
            messages=[
                {"role": "system", "content": "You are a world-class web designer. You create beautiful, production-ready HTML layouts. Always respond with valid JSON only."},
                {"role": "user", "content": prompt}
            ]
        )

        # Track usage (approximate cost for GPT-4o)
        usage = completion.usage
        if usage:
            self.project.input_tokens += usage.prompt_tokens
            self.project.output_tokens += usage.completion_tokens
            cost = (usage.prompt_tokens * 0.0025 + usage.completion_tokens * 0.01) / 1000
            self.project.cost_usd += cost
            self.db.commit()

        raw_text = completion.choices[0].message.content or ""
        print(f"[GENERATE_LAYOUTS] OpenAI response: {len(raw_text)} chars", flush=True)
        print(f"[TIMING] OpenAI call: {time.time() - model_start:.1f}s", flush=True)

        # Parse JSON response
        layouts = []
        try:
            # Strip markdown code fences if present
            clean = raw_text.strip()
            if clean.startswith("```"):
                clean = re.sub(r'^```(?:json)?\s*', '', clean)
                clean = re.sub(r'\s*```$', '', clean)
            parsed = json.loads(clean)
            layouts = parsed.get("layouts", [])
        except json.JSONDecodeError as e:
            print(f"[GENERATE_LAYOUTS] JSON parse failed: {e}, trying HTML extraction fallback", flush=True)
            layouts = self._extract_layouts_fallback(raw_text)

        if not layouts:
            raise ValueError("OpenAI returned no layouts")

        print(f"[GENERATE_LAYOUTS] Got {len(layouts)} layouts from OpenAI", flush=True)

        # Initialize filesystem
        self.fs.init_project()

        # Save layouts as pages
        for i, layout in enumerate(layouts, 1):
            html = layout.get("html", "")
            html = inject_google_fonts(html, fonts)

            page = Page(
                project_id=self.project.id,
                name=layout.get("name", f"Layout {i}"),
                html=html,
                layout_variant=i
            )
            self.db.add(page)
            self.db.flush()

            file_name = f"layout_{i}.html"
            self.fs.write_file(f"public/{file_name}", html)
            self.fs.save_version(str(page.id), 1, html)

            page_version = PageVersion(
                page_id=page.id,
                version=1,
                html=html,
                instruction=f"Generated by OpenAI — {layout.get('inspired_by', 'AI design')}"
            )
            self.db.add(page_version)

            print(f"[GENERATE_LAYOUTS] Saved {file_name} (OpenAI)", flush=True)

        self.fs.git_commit("Generated layouts (OpenAI)")
        self.project.status = ProjectStatus.LAYOUTS
        self.db.commit()

        print(f"[TIMING] TOTAL OpenAI layout generation: {time.time() - layouts_start:.1f}s", flush=True)
        self.log("layouts", f"Created {len(layouts)} layouts (OpenAI)", {"count": len(layouts), "provider": "openai"})
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
