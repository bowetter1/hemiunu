"""Brand research mixin - scrape site + 1 Claude call with web search"""
import json
import time
from typing import TYPE_CHECKING

from .utils import MODEL_SONNET, MODEL_HAIKU, fetch_page_content, scrape_images

if TYPE_CHECKING:
    from .base import Generator


class ResearchMixin:
    """Mixin for brand research - scrape + 1 Claude call"""

    def research_brand(self: "Generator") -> dict:
        """
        Research the brand: scrape site (no AI) + 1 Claude call (with web search).

        Steps:
        A. Scrape company site (no AI, fast)
        B. ONE Claude call with web search — finds inspiration, picks colors/fonts, writes markdown

        Returns:
            dict with brand_colors, fonts, inspiration_sites, company_url
        """
        from ..models import ProjectStatus

        phase_start = time.time()
        print(f"[RESEARCH] Starting brand research for project {self.project.id}", flush=True)

        # Initialize filesystem early (needed for saving scraped images)
        self.fs.init_project()

        # Set status to RESEARCHING
        self.project.status = ProjectStatus.RESEARCHING
        self.db.commit()

        # Get clarification data if available
        clarification = self.project.clarification or {}
        user_answer = clarification.get("answer", "")

        self.log("research", "Starting brand research...")

        # Resolve research model from config
        research_model_key = self.get_config("research_model", "haiku")
        research_model = {"haiku": MODEL_HAIKU, "sonnet": MODEL_SONNET}.get(research_model_key, MODEL_HAIKU)
        print(f"[RESEARCH] Using model: {research_model}", flush=True)

        # ── Step A: Get company URL ──
        company_url = self._get_company_url()
        print(f"[RESEARCH] Company URL: {company_url}", flush=True)

        # ── Step B: Scrape (no AI) ──
        company_content = None
        company_images = []
        raw_colors = []

        if company_url and self.get_config("scrape_company_site", True):
            print(f"[RESEARCH] Scraping {company_url}...", flush=True)

            try:
                company_content = fetch_page_content(company_url)
                raw_colors = company_content.get("colors_found", [])
                print(f"[RESEARCH] Raw colors found: {raw_colors[:10]}", flush=True)
            except Exception as e:
                print(f"[RESEARCH] Error fetching page content: {e}", flush=True)

            # Scrape hero image
            try:
                print(f"[RESEARCH] Scraping hero image from {company_url}...", flush=True)
                scraped = scrape_images(company_url, max_images=1)
                print(f"[RESEARCH] Found {len(scraped)} candidate images", flush=True)

                if scraped:
                    best_url, best_bytes = scraped[0]
                    lower_url = best_url.lower()
                    if lower_url.endswith(".png"):
                        media_type, ext = "image/png", ".png"
                    elif lower_url.endswith(".webp"):
                        media_type, ext = "image/webp", ".webp"
                    else:
                        media_type, ext = "image/jpeg", ".jpg"

                    filename = f"hero{ext}"
                    save_path = f"public/images/company/{filename}"
                    self.fs.write_binary(save_path, best_bytes)

                    company_images = [{
                        "path": f"images/company/{filename}",
                        "description": "Hero image from company website",
                        "source_url": best_url,
                        "size_kb": len(best_bytes) // 1024
                    }]
                    print(f"[RESEARCH] Saved hero image: {best_url[:80]} ({len(best_bytes) // 1024}KB)", flush=True)
                    self.log("research", f"Scraped hero image from {company_url} ({len(best_bytes) // 1024}KB)")

            except Exception as e:
                print(f"[RESEARCH] Image scraping error: {e}", flush=True)

        print(f"[TIMING] Scrape phase: {time.time() - phase_start:.1f}s", flush=True)

        # ── Step C: ONE Claude call (with web search) ──
        claude_start = time.time()
        print("[RESEARCH] Making ONE Claude call with web search...", flush=True)

        site_text = ""
        site_title = ""
        if company_content:
            site_text = company_content.get("text", "")[:3000]
            site_title = company_content.get("title", "Unknown")

        # Build context for Claude
        search_context = self.project.brief
        if user_answer:
            search_context = f"{self.project.brief}\n\nUser clarification: {user_answer}"

        inspiration_count = self.get_config("inspiration_site_count", 3)

        # Tool for Claude to return structured research data
        save_research_tool = {
            "name": "save_research",
            "description": "Save the complete research results — colors, fonts, inspiration sites, and markdown report",
            "input_schema": {
                "type": "object",
                "properties": {
                    "research_markdown": {
                        "type": "string",
                        "description": "Complete design brief in markdown format"
                    },
                    "brand_colors": {
                        "type": "object",
                        "properties": {
                            "primary": {"type": "string", "description": "Primary brand color hex"},
                            "secondary": {"type": "string", "description": "Secondary color hex"},
                            "accent": {"type": "string", "description": "Accent color hex for CTAs"}
                        },
                        "required": ["primary", "secondary", "accent"]
                    },
                    "heading_font": {"type": "string", "description": "Recommended Google Font for headings"},
                    "body_font": {"type": "string", "description": "Recommended Google Font for body text"},
                    "inspiration_sites": {
                        "type": "array",
                        "minItems": inspiration_count,
                        "maxItems": inspiration_count,
                        "items": {
                            "type": "object",
                            "properties": {
                                "url": {"type": "string"},
                                "name": {"type": "string"},
                                "design_style": {"type": "string"},
                                "why": {"type": "string"},
                                "key_elements": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["url", "name", "design_style", "why", "key_elements"]
                        }
                    }
                },
                "required": ["research_markdown", "brand_colors", "heading_font", "body_font", "inspiration_sites"]
            }
        }

        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5
        }

        company_url_str = company_url or "unknown"

        response = self.client.beta.messages.create(
            model=research_model,
            max_tokens=8000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool, save_research_tool],
            messages=[{
                "role": "user",
                "content": f"""You are a senior web designer researching a brand to create a design brief.

PROJECT BRIEF: {search_context}
COMPANY URL: {company_url_str}
SITE TITLE: {site_title}
SITE TEXT (first 3000 chars): {site_text}
RAW COLORS FOUND ON SITE: {raw_colors[:15]}

YOUR TASKS:
1. Use web search to find {inspiration_count} beautiful, REAL inspiration websites in the same or adjacent premium industry. Search on awwwards.com, siteinspire.com, or for premium brands directly. We need ACTUAL website URLs (like "stripe.com", "fourseasons.com"), NOT articles or template galleries.

2. Analyze the brand identity. Pick 3 brand colors:
   - The raw HTML colors above may include WordPress/framework defaults (like #cf2e2e, #1877F2 for Facebook, etc.)
   - Use your judgment to identify the ACTUAL brand colors vs framework noise
   - If the raw colors don't seem right, pick colors that match the brand's identity
   - Primary: main brand color (logo, headers)
   - Secondary: backgrounds, cards, contrast
   - Accent: CTAs, buttons, links

3. Pick a heading font and body font (Google Fonts).

4. Write a comprehensive design brief in markdown with this structure:

# Brand Research: [Company Name]

## Brand Identity
- Primary: [hex] — [usage]
- Secondary: [hex] — [usage]
- Accent: [hex] — [usage]
- Brand feel: [2-3 words]

## Typography
- Heading: [Google Font] — [why]
- Body: [Google Font] — [why]

## Inspiration Site 1: [Name]
- **URL:** [actual website url]
- **What they do well:** [2-3 sentences]
- **Key design patterns:** [bullet list]

### → Layout Blueprint 1 (inspired by [Name])
- **Hero structure:** [exact layout]
- **Navigation:** [style]
- **Hero content:** [what goes in it]
- **Sections below hero (in order):**
  1. [Section] — [layout] — [content]
  2. [Section] — [layout] — [content]
  3. [Section] — [layout] — [content]
- **Visual style:** [padding, shadows, etc.]
- **What makes this layout unique:** [1 sentence]

[Repeat for each inspiration site]

## Design Direction
[2-3 sentences overall direction]

CRITICAL RULES:
- The {inspiration_count} inspiration sites MUST be from DIFFERENT domains
- Each blueprint must describe a DIFFERENT layout approach
- Be specific enough that a developer could build HTML without guessing
- Include real section names relevant to THIS company
- Always aim ABOVE the client's price tier for design inspiration

After writing your analysis, call the save_research tool with ALL findings."""
            }]
        )
        self.track_usage(response)

        # Process response — handle agentic loop for web search
        max_iterations = 10
        research_md = ""
        brand_colors = []
        recommended_fonts = {"heading": "Inter", "body": "Inter"}
        selected_sites = []

        for iteration in range(max_iterations):
            print(f"[RESEARCH] Iteration {iteration + 1}, stop_reason: {response.stop_reason}", flush=True)

            # Check for save_research tool call
            found_research = False
            for block in response.content:
                if block.type == "text":
                    # Collect any text output (may contain markdown before tool call)
                    pass
                if block.type == "tool_use" and block.name == "save_research":
                    data = block.input
                    research_md = data.get("research_markdown", "")
                    colors = data.get("brand_colors", {})
                    brand_colors = [
                        colors.get("primary", "#1a1a1a"),
                        colors.get("secondary", "#ffffff"),
                        colors.get("accent", "#0066cc")
                    ]
                    recommended_fonts = {
                        "heading": data.get("heading_font", "Inter"),
                        "body": data.get("body_font", "Inter")
                    }
                    selected_sites = data.get("inspiration_sites", [])
                    found_research = True
                    print(f"[RESEARCH] Got save_research tool call", flush=True)
                    break

            if found_research:
                break

            # If end_turn without save_research, prompt to use the tool
            if response.stop_reason == "end_turn":
                # Collect any text that might be the markdown
                text_content = ""
                for block in response.content:
                    if block.type == "text":
                        text_content += block.text

                if text_content and not research_md:
                    research_md = text_content

                # Serialize assistant content for continuation
                serialized = []
                for block in response.content:
                    if block.type in ("server_tool_use", "web_search_tool_result"):
                        continue
                    dumped = block.model_dump()
                    if block.type == "tool_use" and "caller" in dumped:
                        del dumped["caller"]
                    if block.type == "text" and "citations" in dumped:
                        del dumped["citations"]
                    serialized.append(dumped)

                print("[RESEARCH] End turn without save_research — prompting to use tool", flush=True)
                response = self.client.beta.messages.create(
                    model=research_model,
                    max_tokens=8000,
                    betas=["web-search-2025-03-05"],
                    tools=[web_search_tool, save_research_tool],
                    messages=[
                        {"role": "user", "content": f"Research this brand and write a design brief.\n\nBrief: {search_context}\nCompany URL: {company_url_str}"},
                        {"role": "assistant", "content": serialized},
                        {"role": "user", "content": "Great research! Now please call the save_research tool with all your findings."}
                    ]
                )
                self.track_usage(response)
                continue

            # If tool_use for web_search, just let the API handle it (it auto-continues)
            if response.stop_reason == "tool_use":
                # Check if there's a non-web-search tool call we need to handle
                has_pending = False
                for block in response.content:
                    if block.type == "tool_use" and block.name != "web_search":
                        has_pending = True
                if not has_pending:
                    # Web search auto-continues, just wait
                    break

        print(f"[TIMING] Claude call: {time.time() - claude_start:.1f}s", flush=True)
        print(f"[RESEARCH] Markdown: {len(research_md)} chars", flush=True)
        print(f"[RESEARCH] Colors: {brand_colors}", flush=True)
        print(f"[RESEARCH] Fonts: {recommended_fonts}", flush=True)
        print(f"[RESEARCH] Sites: {[s.get('name') for s in selected_sites]}", flush=True)

        # Ensure we have 3 colors
        while len(brand_colors) < 3:
            brand_colors.append("#0066cc")

        # ── Save results ──
        research_data = {
            "brand_colors": brand_colors,
            "fonts": recommended_fonts,
            "inspiration_sites": selected_sites,
            "company_url": company_url,
        }

        self.project.research_md = research_md
        self.project.moodboard = {
            "research": research_data,
            "brand_colors": brand_colors,
            "fonts": recommended_fonts,
            "inspiration_sites": selected_sites,
            "company_images": company_images,
        }
        self.project.selected_moodboard = 1  # Compat
        self.project.status = ProjectStatus.RESEARCH_DONE
        self.db.commit()

        print(f"[TIMING] TOTAL research: {time.time() - phase_start:.1f}s", flush=True)
        self.log("research", f"Found {len(brand_colors)} colors, {len(selected_sites)} inspiration sites")

        return research_data

    def _get_company_url(self: "Generator") -> str | None:
        """Extract confirmed company URL from clarification answers or initial search."""
        clarification = self.project.clarification or {}

        # Try to get from initial research URLs
        initial_research = clarification.get("initial_research", {})
        urls_found = initial_research.get("urls_found", [])
        if urls_found:
            return urls_found[0].get("url")

        # Fallback: check if URL is in the brief
        import re
        brief = self.project.brief or ""
        url_match = re.search(r'https?://[^\s]+', brief)
        if url_match:
            return url_match.group(0)

        return None

    def _analyze_existing_site(self: "Generator", company_content: dict, company_images: list[dict]) -> str:
        """Analyze the existing website using Haiku vision with scraped images.

        Sends all kept images + page text to Haiku vision for a design analysis.
        Runs as a background Future parallel to Step 3 (inspiration search).
        """
        import base64 as _b64

        content_blocks = []

        # Add all kept images as base64
        for img in company_images:
            img_path = f"public/{img['path']}"
            full_path = self.fs.base_dir / img_path
            if full_path.exists():
                img_bytes = full_path.read_bytes()
                path_lower = img["path"].lower()
                if path_lower.endswith(".png"):
                    media_type = "image/png"
                elif path_lower.endswith(".webp"):
                    media_type = "image/webp"
                else:
                    media_type = "image/jpeg"

                content_blocks.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": media_type,
                        "data": _b64.b64encode(img_bytes).decode(),
                    }
                })

        if not content_blocks:
            return ""

        # Add text prompt with page context
        site_text = company_content.get("text", "")[:2000]
        site_title = company_content.get("title", "Unknown")
        site_url = company_content.get("url", "Unknown")
        colors = company_content.get("colors_found", [])

        content_blocks.append({
            "type": "text",
            "text": f"""Analyze this company's EXISTING website based on the images above and the page content below.

WEBSITE: {site_url}
TITLE: {site_title}
BRAND COLORS ON PAGE: {colors[:10]}
PAGE TEXT (first 2000 chars):
{site_text}

Provide a concise analysis covering:
1. Overall feel/tone (e.g., warm, corporate, rustic, playful, luxurious, dated)
2. Layout style (e.g., hero image, text-heavy, grid, split layout, single-column)
3. Image usage (photo-heavy, illustrations, minimal, stock vs real photography)
4. Typography feel (serif/classic, sans-serif/modern, decorative, mixed)
5. Color usage (dark/light theme, monochrome, colorful, accent usage)
6. What works well (2-3 bullet points)
7. What needs improvement (2-3 bullet points)

Keep it concise — this will be fed into a layout prompt as context. Write as a design expert evaluating the site."""
        })

        response = self.client.messages.create(
            model=MODEL_HAIKU,
            max_tokens=800,
            messages=[{"role": "user", "content": content_blocks}]
        )
        self.track_usage(response)

        return response.content[0].text.strip()

    def search_and_clarify(self: "Generator") -> dict:
        """
        PHASE 1: Initial search to identify if clarification is needed.

        Returns:
            dict with either:
            - {"needs_clarification": True, "question": "...", "options": [...]}
            - {"needs_clarification": False} (continue to research_brand)
        """
        from ..models import ProjectStatus

        phase1_start = time.time()
        print(f"[PHASE 1] Initial search for project {self.project.id}", flush=True)
        print(f"[PHASE 1] Brief: {self.project.brief[:100]}...", flush=True)
        self.log("research", "Phase 1: Initial search to identify brand...")

        search_start = time.time()
        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 3
        }

        # First, do a broad search
        search_response = self.client.beta.messages.create(
            model=MODEL_HAIKU,
            max_tokens=1000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool],
            messages=[{
                "role": "user",
                "content": f"""Search for the company/brand mentioned in this project brief:

"{self.project.brief}"

Do 1-2 searches to identify:
1. What company/brand is this about?
2. Is there any ambiguity (e.g., multiple companies with similar names)?

Search now."""
            }]
        )
        self.track_usage(search_response)

        # Collect search results for analysis
        search_results_text = []
        urls_found = []

        for block in search_response.content:
            if block.type == "text":
                search_results_text.append(block.text)
            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                if isinstance(content, list):
                    for item in content[:5]:
                        url = getattr(item, 'url', '')
                        title = getattr(item, 'title', '')
                        if url:
                            urls_found.append({"url": url, "title": title})
                            print(f"[PHASE 1] Found: {title[:50]} - {url[:40]}", flush=True)

        print(f"[TIMING] Phase 1 search: {time.time() - search_start:.1f}s", flush=True)

        # Now ask Opus to formulate 3 clarification questions.
        # ALWAYS ask — to understand what the user wants before building.
        analysis_start = time.time()
        clarify_tool = {
            "name": "clarification_questions",
            "description": "Formulate 3 questions to ask the user before we start designing",
            "input_schema": {
                "type": "object",
                "properties": {
                    "identified_brand": {
                        "type": "string",
                        "description": "The brand/company identified from search results"
                    },
                    "brand_is_ambiguous": {
                        "type": "boolean",
                        "description": "True if the brand/company is unclear and Q1 should ask about that"
                    },
                    "questions": {
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": {
                            "type": "object",
                            "properties": {
                                "question": {
                                    "type": "string",
                                    "description": "The question to ask"
                                },
                                "options": {
                                    "type": "array",
                                    "items": {"type": "string"},
                                    "minItems": 2,
                                    "maxItems": 4,
                                    "description": "2-4 clickable options (short, max 6 words each)"
                                }
                            },
                            "required": ["question", "options"]
                        }
                    }
                },
                "required": ["identified_brand", "brand_is_ambiguous", "questions"]
            }
        }

        analysis_response = self.client.messages.create(
            model=MODEL_HAIKU,
            max_tokens=800,
            tools=[clarify_tool],
            tool_choice={"type": "tool", "name": "clarification_questions"},
            messages=[{
                "role": "user",
                "content": f"""Analyze these search results and formulate exactly 3 questions for the user.

PROJECT BRIEF: "{self.project.brief}"

SEARCH RESULTS FOUND:
{json.dumps(urls_found, indent=2)}

ANALYSIS:
{chr(10).join(search_results_text)}

FORMULATE 3 QUESTIONS to understand what the user wants to build.

Q1 MUST ALWAYS verify the company/website. Include the URL you found.
  Example: "Is this the right company: Forex Bank (forex.se)?" → "Yes, forex.se", "No, forex.com (trading)", "No, different company"
  Example: "Is this the right company: Vår Gård (vargard.se)?" → "Yes, vargard.se", "No, different Vår Gård"

Q2: What should the site focus on? (industry-specific options)
  Example for a golf club: "What should the website focus on?" → "Tee time booking", "Membership recruitment", "Events & tournaments", "Full club experience"
  Example for a bank: "Main service to highlight?" → "Currency exchange", "Travel money & cards", "Personal banking", "All services"

Q3: What design style/tone? (with options)
  Example: "What design style fits best?" → "Classic & prestigious", "Modern & sporty", "Scandinavian minimal", "Warm & welcoming"

RULES:
- Q1 MUST always confirm the company with its URL — never skip this
- Questions must be specific to THIS company/industry
- Options must be short (max 6 words) and clickable
- Each question must have 2-4 options
- Write questions in the same language as the user's brief"""
            }]
        )
        self.track_usage(analysis_response)

        print(f"[TIMING] Phase 1 analysis: {time.time() - analysis_start:.1f}s", flush=True)

        # Extract questions — always ask
        for block in analysis_response.content:
            if block.type == "tool_use" and block.name == "clarification_questions":
                decision = block.input
                questions = decision.get("questions", [])
                print(f"[PHASE 1] Brand: {decision.get('identified_brand')}", flush=True)
                for i, q in enumerate(questions):
                    print(f"[PHASE 1] Q{i+1}: {q.get('question')} → {q.get('options')}", flush=True)
                print(f"[TIMING] TOTAL Phase 1: {time.time() - phase1_start:.1f}s", flush=True)

                self.project.clarification = {
                    "questions": questions,
                    "identified_brand": decision.get("identified_brand", ""),
                    "brand_is_ambiguous": decision.get("brand_is_ambiguous", False),
                    "initial_research": {
                        "urls_found": urls_found,
                        "analysis": search_results_text
                    }
                }
                self.project.status = ProjectStatus.CLARIFICATION
                self.db.commit()

                self.log("research", f"Asking user 3 questions about {decision.get('identified_brand')}")
                return {
                    "needs_clarification": True,
                    "questions": questions
                }

        # Fallback — ask 3 generic questions
        fallback_questions = [
            {"question": "What type of website?", "options": ["Landing page", "Full marketing site", "Web application", "Portfolio"]},
            {"question": "Primary audience?", "options": ["Consumers", "Businesses", "Both"]},
            {"question": "Design style?", "options": ["Modern & minimal", "Bold & colorful", "Classic & professional", "Warm & friendly"]}
        ]
        self.project.clarification = {
            "questions": fallback_questions,
            "identified_brand": "",
            "initial_research": {
                "urls_found": urls_found,
                "analysis": search_results_text
            }
        }
        self.project.status = ProjectStatus.CLARIFICATION
        self.db.commit()
        return {
            "needs_clarification": True,
            "questions": fallback_questions
        }
