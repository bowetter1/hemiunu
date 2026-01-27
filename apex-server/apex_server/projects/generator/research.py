"""Brand research mixin - extracts real colors from company website + finds inspiration sites"""
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import TYPE_CHECKING

from .utils import MODEL_OPUS, MODEL_HAIKU, fetch_page_content

if TYPE_CHECKING:
    from .base import Generator


class ResearchMixin:
    """Mixin for brand research - finds real colors + inspiration sites"""

    def research_brand(self: "Generator") -> dict:
        """
        Research the brand and find inspiration sites.

        Steps:
        1. Find company's ACTUAL website
        2. Extract REAL colors from their site
        3. Search for 6 beautiful inspiration websites in same industry
        4. Pick 3 best inspiration sites

        Returns:
            dict with brand_colors, fonts, and 3 inspiration_sites
        """
        from ..models import ProjectStatus

        phase_start = time.time()
        print(f"[RESEARCH] Starting brand research for project {self.project.id}", flush=True)

        # Get clarification data if available
        clarification = self.project.clarification or {}
        user_answer = clarification.get("answer", "")

        # Build search context
        search_context = self.project.brief
        if user_answer:
            search_context = f"{self.project.brief}\n\nUser clarification: {user_answer}"
            print(f"[RESEARCH] Using clarification: {user_answer}", flush=True)

        self.log("research", "Starting brand research...")

        # ============================================
        # STEP 1: Find company's official website
        # ============================================
        step1_start = time.time()
        print("[STEP 1] Finding company's official website...", flush=True)

        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 3
        }

        find_site_response = self.client.beta.messages.create(
            model=MODEL_HAIKU,
            max_tokens=800,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool],
            messages=[{
                "role": "user",
                "content": f"""Find the OFFICIAL website for this company/brand:

"{search_context}"

IMPORTANT: Search for the company's ACTUAL official website domain (e.g., "forex.se", "saltsjobadengk.se").
We need to find their real site to extract their actual brand colors.

Do 1-2 searches to find the official company website."""
            }]
        )
        self.track_usage(find_site_response)

        # Extract company website URL
        company_urls = []
        for block in find_site_response.content:
            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                if isinstance(content, list):
                    for item in content[:3]:
                        url = getattr(item, 'url', '')
                        title = getattr(item, 'title', '')
                        if url:
                            company_urls.append({"url": url, "title": title})
                            print(f"[STEP 1] Found: {url[:60]}", flush=True)

        print(f"[TIMING] Step 1 (find company site): {time.time() - step1_start:.1f}s", flush=True)

        # Log to database for app visibility
        if company_urls:
            self.log("research", f"Found company site: {company_urls[0]['url']}", {"urls": company_urls})

        # ============================================
        # STEP 2: Have Opus analyze the website and identify brand colors
        # ============================================
        step2_start = time.time()
        print("[STEP 2] Having Opus analyze website for brand colors...", flush=True)

        brand_colors = []
        company_content = None

        if company_urls:
            main_url = company_urls[0]["url"]
            print(f"[STEP 2] Fetching: {main_url}", flush=True)

            try:
                company_content = fetch_page_content(main_url)
                raw_colors = company_content.get("colors_found", [])
                print(f"[STEP 2] Raw colors found on page: {raw_colors[:10]}", flush=True)

                # Have Opus analyze and pick the REAL brand colors
                color_tool = {
                    "name": "identify_brand_colors",
                    "description": "Identify the real brand colors from the website",
                    "input_schema": {
                        "type": "object",
                        "properties": {
                            "primary": {"type": "string", "description": "Primary brand color hex (usually from logo or headers)"},
                            "secondary": {"type": "string", "description": "Secondary color hex (backgrounds, cards)"},
                            "accent": {"type": "string", "description": "Accent color hex (CTAs, buttons, links)"}
                        },
                        "required": ["primary", "secondary", "accent"]
                    }
                }

                color_analysis = self.client.messages.create(
                    model=MODEL_HAIKU,
                    max_tokens=500,
                    tools=[color_tool],
                    tool_choice={"type": "tool", "name": "identify_brand_colors"},
                    messages=[{
                        "role": "user",
                        "content": f"""Analyze this website and identify its REAL brand colors.

WEBSITE: {main_url}
TITLE: {company_content.get('title', 'Unknown')}

COLORS FOUND ON PAGE: {raw_colors[:15]}

YOUR TASK: Pick the 3 colors that are the ACTUAL BRAND colors.

⚠️ IGNORE THESE (they are from social media widgets, NOT the brand):
- #1877F2, #4267B2, #3b5998 = Facebook blue
- #1DA1F2, #1D9BF0 = Twitter/X blue
- #FF0000, #CC0000, #c4302b = YouTube red
- #E1306C, #C13584, #833AB4, #F77737 = Instagram colors
- #0077B5, #0A66C2 = LinkedIn blue
- #25D366, #128C7E = WhatsApp green
- #000000 = Pure black (too generic)
- #ffffff = Pure white (too generic)
- Very light grays (#f5f5f5, #fafafa, #eeeeee, #e5e5e5)

✅ LOOK FOR COLORS FROM:
- The company LOGO (most important!)
- Navigation bar / header background
- CTA buttons ("Book now", "Contact us", etc.)
- Section backgrounds with brand personality
- Footer with brand colors

Pick colors that feel like THIS SPECIFIC BRAND, not generic web colors."""
                    }]
                )
                self.track_usage(color_analysis)

                for block in color_analysis.content:
                    if block.type == "tool_use" and block.name == "identify_brand_colors":
                        colors = block.input
                        brand_colors = [
                            colors.get("primary", "#1a1a1a"),
                            colors.get("secondary", "#ffffff"),
                            colors.get("accent", "#0066cc")
                        ]
                        print(f"[STEP 2] Opus identified brand colors: {brand_colors}", flush=True)
                        break

            except Exception as e:
                print(f"[STEP 2] Error: {e}", flush=True)

        print(f"[TIMING] Step 2 (analyze colors): {time.time() - step2_start:.1f}s", flush=True)

        # ============================================
        # STEP 3: Search for REAL inspiration websites (not template galleries)
        # ============================================
        step3_start = time.time()
        print("[STEP 3] Searching for real inspiration websites...", flush=True)

        inspiration_search_response = self.client.beta.messages.create(
            model=MODEL_HAIKU,
            max_tokens=1500,
            betas=["web-search-2025-03-05"],
            tools=[{
                "type": "web_search_20250305",
                "name": "web_search",
                "max_uses": 5
            }],
            messages=[{
                "role": "user",
                "content": f"""Find 6+ REAL, LIVE websites that we can use as design inspiration for this project:

Project: {search_context}
Company URL: {company_urls[0]['url'] if company_urls else 'unknown'}

YOUR GOAL: Find the most BEAUTIFUL, high-budget websites in this industry and adjacent premium industries. Expensive brands spend more on design — so always look UPMARKET for inspiration, regardless of the client's actual market segment.

SEARCH STRATEGY (do all of these):
1. Search: "[industry] site:awwwards.com" — find award-winning sites in this industry
2. Search: "[industry] site:siteinspire.com" — find curated design inspiration
3. Search: The MOST PREMIUM brands in this industry (e.g., for a hotel → Four Seasons, Aman, Rosewood; for golf → Augusta National, TPC Scottsdale; for fintech → Stripe, Wise)
4. Search: Luxury/premium brands in ADJACENT industries with overlapping audiences (e.g., for a conference hotel → luxury travel brands, premium event venues, high-end restaurants)

KEY PRINCIPLE: Always aim ABOVE the client's price tier. A budget hotel should be inspired by a luxury hotel's website. A local golf club should look at world-class resorts. Premium brands have bigger design budgets — their websites are simply better designed, and we can adapt that quality for any client.

CRITICAL RULES:
- We need the ACTUAL website URLs (like "wise.com", "stripe.com", "fourseasons.com")
- NOT articles about design (no "best X website design 2024" listicles)
- NOT template marketplaces
- Think: "What website would I open in a browser to study its design?"

Search now."""
            }]
        )
        self.track_usage(inspiration_search_response)

        # Collect inspiration URLs — aggressively filter out non-website results
        inspiration_urls = []
        search_queries = []

        # Domains that are template galleries / articles, NOT real design inspiration
        skip_domains = [
            "awwwards.com", "behance.net", "dribbble.com", "pinterest.com",
            "medium.com", "wordpress.com", "themeforest.net", "templatemonster.com",
            "99designs.com", "subframe.com", "motocms.com", "instapage.com",
            "wix.com", "squarespace.com", "hubspot.com", "colorlib.com",
            "siteinspire.com", "bestwebsite.gallery", "onepagelove.com",
            "designspiration.com", "webdesign-inspiration.com", "land-book.com",
            "godaddy.com", "shopify.com/blog", "brandcrowd.com", "flaticon.com",
            "youtube.com", "wikipedia.org", "reddit.com", "quora.com",
            "mycodelesswebsite.com", "clubmarketing.com/blog",
        ]

        for block in inspiration_search_response.content:
            if block.type == "server_tool_use" and getattr(block, 'name', '') == "web_search":
                query = getattr(block, 'input', {}).get('query', '')
                if query:
                    search_queries.append(query)
                    print(f"[STEP 3] Search: {query}", flush=True)

            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                if isinstance(content, list):
                    for item in content[:5]:
                        url = getattr(item, 'url', '')
                        title = getattr(item, 'title', '')
                        if url and url not in [u["url"] for u in inspiration_urls]:
                            if not any(skip in url.lower() for skip in skip_domains):
                                inspiration_urls.append({"url": url, "title": title})
                                print(f"[STEP 3] Found: {url[:60]}", flush=True)
                            else:
                                print(f"[STEP 3] Skipped (gallery/article): {url[:60]}", flush=True)

        print(f"[STEP 3] Total real sites found: {len(inspiration_urls)}", flush=True)
        print(f"[TIMING] Step 3 (search inspiration): {time.time() - step3_start:.1f}s", flush=True)

        # ============================================
        # STEP 4: Fetch inspiration sites in parallel
        # ============================================
        step4_start = time.time()
        print("[STEP 4] Fetching inspiration site content...", flush=True)

        inspiration_content = []
        with ThreadPoolExecutor(max_workers=4) as executor:
            future_to_url = {executor.submit(fetch_page_content, u["url"]): u for u in inspiration_urls[:8]}
            for future in as_completed(future_to_url):
                url_info = future_to_url[future]
                try:
                    content = future.result()
                    content["title"] = url_info.get("title", "Unknown")
                    inspiration_content.append(content)
                    print(f"[STEP 4] Fetched: {url_info['url'][:50]}", flush=True)
                except Exception as e:
                    print(f"[STEP 4] Error: {url_info['url'][:40]}: {e}", flush=True)

        print(f"[TIMING] Step 4 (fetch inspiration): {time.time() - step4_start:.1f}s", flush=True)

        # ============================================
        # STEP 5: Opus writes comprehensive markdown research report
        # ============================================
        step5_start = time.time()
        print("[STEP 5] Having Opus write research markdown report...", flush=True)

        # Format fetched content for analysis (2000 chars per site for richer context)
        sites_for_analysis = "\n\n".join([
            f"URL: {c.get('url', 'unknown')}\nTitle: {c.get('title', 'unknown')}\nCSS/Styles: {json.dumps(c.get('colors_found', []))}\nContent: {c.get('text', '')[:2000]}"
            for c in inspiration_content if not c.get("error")
        ])

        # Tool for Opus to return structured metadata alongside the markdown
        save_research_tool = {
            "name": "save_research_metadata",
            "description": "Save the research metadata (fonts, site names) alongside the markdown report",
            "input_schema": {
                "type": "object",
                "properties": {
                    "heading_font": {"type": "string", "description": "Recommended Google Font for headings"},
                    "body_font": {"type": "string", "description": "Recommended Google Font for body text"},
                    "inspiration_sites": {
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
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
                "required": ["heading_font", "body_font", "inspiration_sites"]
            }
        }

        company_url_str = company_urls[0]["url"] if company_urls else "unknown"

        research_response = self.client.messages.create(
            model=MODEL_HAIKU,
            max_tokens=8000,
            tools=[save_research_tool],
            messages=[{
                "role": "user",
                "content": f"""You are a senior web designer creating a design brief for a layout developer. Your report will be handed DIRECTLY to the person building the HTML/CSS — so it must be specific and actionable.

DESIGN PHILOSOPHY: Always design as if the client has a premium budget. Study the inspiration sites for their high-end design techniques — generous whitespace, elegant typography, refined animations, premium photography treatment — and bring that level of polish to every blueprint, regardless of the client's actual market segment. Beautiful design is universal.

PROJECT BRIEF: {self.project.brief}
COMPANY URL: {company_url_str}
BRAND COLORS FOUND: {brand_colors if brand_colors else 'None found — you must suggest appropriate colors'}

═══════════════════════════════════════════════════════════════
INSPIRATION WEBSITES (with their actual content/styles):
═══════════════════════════════════════════════════════════════
{sites_for_analysis}

═══════════════════════════════════════════════════════════════
INSTRUCTIONS:
═══════════════════════════════════════════════════════════════

Write your report as FREE TEXT (markdown), then call the save_research_metadata tool.

Pick the 3 BEST real websites from above (skip any that are template galleries or design articles — those are useless as inspiration). If fewer than 3 real sites exist, use your knowledge of well-designed sites in this industry.

Use this EXACT structure:

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
- **What they do well:** [2-3 sentences about their design approach]
- **Key design patterns:** [bullet list of specific techniques: navigation style, hero layout, section transitions, card styles, etc.]

### → Layout Blueprint 1 (inspired by [Name])
Build a hero section and landing page with these specifics:
- **Hero structure:** [exact layout — e.g. "full-width background image with centered text overlay" or "split 50/50 with image left, text right"]
- **Navigation:** [e.g. "sticky transparent nav, becomes solid white on scroll, logo left, links center, CTA button right"]
- **Hero content:** [what goes in it — headline, subline, CTA button, maybe stats or trust badges]
- **Sections below hero (in order):**
  1. [Section name] — [layout: e.g. "3-column card grid with icons"] — [content: e.g. "key services/features"]
  2. [Section name] — [layout] — [content]
  3. [Section name] — [layout] — [content]
- **Visual style:** [padding, border-radius, shadows, background colors for sections]
- **What makes this layout unique:** [1 sentence]

## Inspiration Site 2: [Name]
[same structure as above]

### → Layout Blueprint 2 (inspired by [Name])
[same blueprint structure]

## Inspiration Site 3: [Name]
[same structure as above]

### → Layout Blueprint 3 (inspired by [Name])
[same blueprint structure]

## Design Direction
[2-3 sentences: overall direction combining brand identity with the best elements]

CRITICAL RULES:
- The 3 inspiration sites MUST be from 3 DIFFERENT domains (e.g. oanda.com + bloomberg.com + wise.com — NEVER 3 pages from the same site)
- Each blueprint must describe a DIFFERENT layout approach (e.g. one image-heavy, one minimal/typographic, one bold/dark)
- Be specific enough that a developer could build the HTML without guessing
- Include real section names relevant to THIS company (e.g. for a golf club: "Tee Times", "Course Overview", "Membership"; for a bank: "Services", "Rates", "Download App")
- The 3 layouts must all use the same brand colors but feel distinctly different

After writing the markdown, call the save_research_metadata tool with fonts + the 3 sites."""
            }]
        )
        self.track_usage(research_response)

        # Extract markdown from text blocks and metadata from tool call
        research_md = ""
        selected_sites = []
        recommended_fonts = {"heading": "Inter", "body": "Inter"}

        for block in research_response.content:
            if block.type == "text":
                research_md += block.text
            elif block.type == "tool_use" and block.name == "save_research_metadata":
                metadata = block.input
                recommended_fonts = {
                    "heading": metadata.get("heading_font", "Inter"),
                    "body": metadata.get("body_font", "Inter")
                }
                selected_sites = metadata.get("inspiration_sites", [])

        print(f"[STEP 5] Research markdown: {len(research_md)} chars", flush=True)
        print(f"[STEP 5] Selected {len(selected_sites)} inspiration sites", flush=True)
        for site in selected_sites:
            print(f"  - {site.get('name')}: {site.get('design_style', '')[:50]}...", flush=True)
        print(f"[STEP 5] Fonts: {recommended_fonts}", flush=True)

        print(f"[TIMING] Step 5 (research markdown): {time.time() - step5_start:.1f}s", flush=True)

        # ============================================
        # STEP 6: Finalize brand colors (or create if not found)
        # ============================================
        step6_start = time.time()

        # If we didn't find brand colors, have Opus create appropriate ones
        if not brand_colors or len(brand_colors) < 3:
            print("[STEP 6] No brand colors found, creating palette...", flush=True)

            color_tool = {
                "name": "create_colors",
                "description": "Create a color palette for the brand",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "primary": {"type": "string", "description": "Primary color hex (e.g., #1a1a1a)"},
                        "secondary": {"type": "string", "description": "Secondary color hex"},
                        "accent": {"type": "string", "description": "Accent color hex for CTAs"}
                    },
                    "required": ["primary", "secondary", "accent"]
                }
            }

            color_response = self.client.messages.create(
                model=MODEL_HAIKU,
                max_tokens=500,
                tools=[color_tool],
                tool_choice={"type": "tool", "name": "create_colors"},
                messages=[{
                    "role": "user",
                    "content": f"""Create a color palette for this project.

PROJECT: {self.project.brief}

INSPIRATION SITES:
{json.dumps([{"name": s.get("name"), "style": s.get("design_style")} for s in selected_sites], indent=2)}

Create colors that:
1. Feel appropriate for this industry
2. Match the mood of the inspiration sites
3. Work well together (good contrast)"""
                }]
            )
            self.track_usage(color_response)

            for block in color_response.content:
                if block.type == "tool_use" and block.name == "create_colors":
                    colors = block.input
                    brand_colors = [colors.get("primary", "#1a1a1a"), colors.get("secondary", "#ffffff"), colors.get("accent", "#0066cc")]
                    break
        else:
            # Use first 3 colors from the site
            brand_colors = brand_colors[:3]
            # Ensure we have 3 colors
            while len(brand_colors) < 3:
                brand_colors.append("#0066cc")

        print(f"[STEP 6] Final brand colors: {brand_colors}", flush=True)
        print(f"[TIMING] Step 6 (finalize colors): {time.time() - step6_start:.1f}s", flush=True)

        # ============================================
        # Save research results
        # ============================================
        research_data = {
            "brand_colors": brand_colors,
            "fonts": recommended_fonts,
            "inspiration_sites": selected_sites,
            "company_url": company_urls[0]["url"] if company_urls else None,
            "search_queries": search_queries
        }

        # Store markdown report on project
        self.project.research_md = research_md

        # Store structured data in moodboard (brand_colors for swatches, fonts for inject_google_fonts)
        self.project.moodboard = {
            "research": research_data,
            "brand_colors": brand_colors,
            "fonts": recommended_fonts,
            "inspiration_sites": selected_sites
        }
        self.project.selected_moodboard = 1  # Not used anymore, but keep for compatibility
        self.project.status = ProjectStatus.MOODBOARD
        self.db.commit()

        print(f"[RESEARCH DATA] Markdown saved ({len(research_md)} chars)", flush=True)
        print(json.dumps(research_data, indent=2, ensure_ascii=False), flush=True)

        print(f"[TIMING] TOTAL research: {time.time() - phase_start:.1f}s", flush=True)
        self.log("research", f"Found {len(brand_colors)} colors, {len(selected_sites)} inspiration sites")

        return research_data

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

If the brand is AMBIGUOUS (e.g., "Forex" could mean different companies):
  Q1: Which company? (with specific options)
  Q2: What should the site focus on? (industry-specific options)
  Q3: What tone/style? (with options)

If the brand is CLEAR:
  Q1: What should the website focus on? (industry-specific)
  Q2: Who is the target audience?
  Q3: What tone/style should the design have?

EXAMPLES for a golf club:
  Q1: "What should the website focus on?" → "Tee time booking", "Membership recruitment", "Events & tournaments", "Full club experience"
  Q2: "Who is the primary audience?" → "Existing members", "New member prospects", "Casual visitors & tourists", "Corporate events"
  Q3: "What design style fits the club?" → "Classic & prestigious", "Modern & sporty", "Scandinavian minimal", "Warm & welcoming"

EXAMPLES for a bank:
  Q1: "What's the main service to highlight?" → "Currency exchange", "Travel money & cards", "Personal banking", "All services"
  Q2: "Target audience?" → "Travelers", "Expats & immigrants", "Business clients", "Everyone"
  Q3: "Brand personality?" → "Trustworthy & traditional", "Modern & digital-first", "Friendly & accessible", "Premium & exclusive"

RULES:
- Questions must be specific to THIS company/industry
- Options must be short (max 6 words) and clickable
- Each question must have 2-4 options
- The 3 questions together should give us enough context to design the right website"""
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
