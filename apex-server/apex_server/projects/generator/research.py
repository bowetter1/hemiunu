"""Brand research mixin - extracts real colors from company website + finds inspiration sites"""
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import TYPE_CHECKING

from .utils import MODEL_OPUS, fetch_page_content

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
            model=MODEL_OPUS,
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
                    model=MODEL_OPUS,
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
        # STEP 3: Search for 6 beautiful inspiration websites
        # ============================================
        step3_start = time.time()
        print("[STEP 3] Searching for inspiration websites...", flush=True)

        # Determine industry from brief
        inspiration_search_response = self.client.beta.messages.create(
            model=MODEL_OPUS,
            max_tokens=1200,
            betas=["web-search-2025-03-05"],
            tools=[{
                "type": "web_search_20250305",
                "name": "web_search",
                "max_uses": 4
            }],
            messages=[{
                "role": "user",
                "content": f"""Search for 6 BEAUTIFUL, AWARD-WINNING websites that could inspire the design for this project:

Project: {search_context}

SEARCH STRATEGY:
1. First search: "best [industry] website design 2024 2025" (e.g., "best restaurant website design 2024")
2. Second search: "awwwards [industry] website" (e.g., "awwwards restaurant website")
3. Third search: "beautiful [industry] landing page inspiration"

We want to find REAL websites with stunning designs that we can use as visual inspiration.
NOT articles about design - actual LIVE websites we can look at."""
            }]
        )
        self.track_usage(inspiration_search_response)

        # Collect inspiration URLs
        inspiration_urls = []
        search_queries = []

        for block in inspiration_search_response.content:
            if block.type == "server_tool_use" and getattr(block, 'name', '') == "web_search":
                query = getattr(block, 'input', {}).get('query', '')
                if query:
                    search_queries.append(query)
                    print(f"[STEP 3] Search: {query}", flush=True)

            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                if isinstance(content, list):
                    for item in content[:5]:  # More results per search
                        url = getattr(item, 'url', '')
                        title = getattr(item, 'title', '')
                        if url and url not in [u["url"] for u in inspiration_urls]:
                            # Skip aggregator sites, keep actual company sites
                            skip_domains = ["awwwards.com", "behance.net", "dribbble.com", "pinterest.com", "medium.com", "wordpress.com"]
                            if not any(skip in url.lower() for skip in skip_domains):
                                inspiration_urls.append({"url": url, "title": title})
                                print(f"[STEP 3] Found: {url[:60]}", flush=True)

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
            model=MODEL_OPUS,
            max_tokens=6000,
            tools=[save_research_tool],
            messages=[{
                "role": "user",
                "content": f"""You are a senior web designer doing brand research. Analyze ALL the data below and write a comprehensive markdown research report.

PROJECT BRIEF: {self.project.brief}
COMPANY URL: {company_url_str}
BRAND COLORS FOUND: {brand_colors if brand_colors else 'None found - you must suggest appropriate colors'}

═══════════════════════════════════════════════════════════════
INSPIRATION WEBSITES FOUND (with their actual content):
═══════════════════════════════════════════════════════════════
{sites_for_analysis}

═══════════════════════════════════════════════════════════════
YOUR TASK:
═══════════════════════════════════════════════════════════════

1. FIRST: Write a detailed markdown report as FREE TEXT in your response (not in the tool call). Use this exact structure:

# Brand Research: [Company Name]

## Brand Identity
- Primary color: [hex] — [what it's used for]
- Secondary color: [hex] — [what it's used for]
- Accent color: [hex] — [what it's used for]
- Overall brand feel: [describe]

## Typography
- Heading font: [Google Font name] — [why this font fits]
- Body font: [Google Font name] — [why this font fits]

## Inspiration Site 1: [Name]
- **URL:** [url]
- **Design style:** [detailed description of visual style]
- **Layout:** [describe hero section, grid, spacing]
- **Typography:** [what fonts/sizes they use, how hierarchy works]
- **Colors:** [their color scheme and how they use it]
- **Key elements to borrow:** [specific CSS/design patterns]
- **Why inspiring:** [1-2 sentences]

## Inspiration Site 2: [Name]
[same structure]

## Inspiration Site 3: [Name]
[same structure]

## Design Direction
[2-3 sentences summarizing the overall design direction for this project, combining the best elements from the inspiration sites with the brand identity]

2. THEN: Call the save_research_metadata tool with the structured data (fonts + 3 inspiration sites).

IMPORTANT:
- Select the 3 BEST inspiration sites from those found. Pick diverse styles.
- Be very specific about CSS details (padding, font sizes, layout patterns)
- If no brand colors were found, suggest appropriate ones based on the industry
- The markdown report will be sent directly to the layout designer, so be thorough"""
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
                model=MODEL_OPUS,
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
            model=MODEL_OPUS,
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

        # Now ask Opus to analyze if clarification is needed
        analysis_start = time.time()
        clarify_tool = {
            "name": "clarification_decision",
            "description": "Decide if user clarification is needed",
            "input_schema": {
                "type": "object",
                "properties": {
                    "needs_clarification": {
                        "type": "boolean",
                        "description": "True if the brand/company is ambiguous and we need to ask the user"
                    },
                    "question": {
                        "type": "string",
                        "description": "Question to ask the user (if needs_clarification is true)"
                    },
                    "options": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "2-4 options for the user to choose from"
                    },
                    "identified_brand": {
                        "type": "string",
                        "description": "The brand/company identified (if clear)"
                    },
                    "confidence": {
                        "type": "string",
                        "enum": ["high", "medium", "low"],
                        "description": "Confidence in the identification"
                    }
                },
                "required": ["needs_clarification", "confidence"]
            }
        }

        analysis_response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=500,
            tools=[clarify_tool],
            tool_choice={"type": "tool", "name": "clarification_decision"},
            messages=[{
                "role": "user",
                "content": f"""Analyze these search results and decide if we need to ask the user for clarification.

PROJECT BRIEF: "{self.project.brief}"

SEARCH RESULTS FOUND:
{json.dumps(urls_found, indent=2)}

ANALYSIS:
{chr(10).join(search_results_text)}

DECIDE:
- If the company/brand is CLEAR (e.g., search found their official website), set needs_clarification=false
- If AMBIGUOUS (e.g., "Forex" could be forex.se OR forex trading sites), set needs_clarification=true and provide a question with options

Examples of when to ask:
- "Forex" → Could be Forex Bank Sweden (forex.se) or general forex trading
- "Apple" → Could be Apple Inc or a local business
- Generic terms that match multiple companies"""
            }]
        )
        self.track_usage(analysis_response)

        print(f"[TIMING] Phase 1 analysis: {time.time() - analysis_start:.1f}s", flush=True)

        # Extract decision
        for block in analysis_response.content:
            if block.type == "tool_use" and block.name == "clarification_decision":
                decision = block.input
                print(f"[PHASE 1] Decision: {decision}", flush=True)
                print(f"[TIMING] TOTAL Phase 1: {time.time() - phase1_start:.1f}s", flush=True)

                if decision.get("needs_clarification"):
                    # Save initial research and return question
                    self.project.clarification = {
                        "question": decision.get("question", "Which company do you mean?"),
                        "options": decision.get("options", []),
                        "initial_research": {
                            "urls_found": urls_found,
                            "analysis": search_results_text
                        }
                    }
                    self.project.status = ProjectStatus.CLARIFICATION
                    self.db.commit()

                    self.log("research", f"Needs clarification: {decision.get('question')}")
                    return {
                        "needs_clarification": True,
                        "question": decision.get("question"),
                        "options": decision.get("options", [])
                    }
                else:
                    # Clear to proceed
                    self.project.clarification = {
                        "identified_brand": decision.get("identified_brand", ""),
                        "confidence": decision.get("confidence", "high"),
                        "initial_research": {
                            "urls_found": urls_found
                        }
                    }
                    self.db.commit()

                    self.log("research", f"Brand identified: {decision.get('identified_brand')}")
                    return {"needs_clarification": False}

        # Fallback - proceed without clarification
        return {"needs_clarification": False}
