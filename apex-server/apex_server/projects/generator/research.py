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

        # ============================================
        # STEP 2: Fetch company website and extract colors
        # ============================================
        step2_start = time.time()
        print("[STEP 2] Extracting colors from company website...", flush=True)

        brand_colors = []
        company_content = None

        if company_urls:
            # Fetch the first (most likely official) URL
            main_url = company_urls[0]["url"]
            print(f"[STEP 2] Fetching: {main_url}", flush=True)

            try:
                company_content = fetch_page_content(main_url)
                brand_colors = company_content.get("brand_colors", []) or company_content.get("colors_found", [])
                print(f"[STEP 2] Colors from {main_url}: {brand_colors}", flush=True)
            except Exception as e:
                print(f"[STEP 2] Error fetching: {e}", flush=True)

        # If no colors found, try additional URLs
        if not brand_colors and len(company_urls) > 1:
            for url_info in company_urls[1:3]:
                try:
                    content = fetch_page_content(url_info["url"])
                    colors = content.get("brand_colors", []) or content.get("colors_found", [])
                    if colors:
                        brand_colors = colors
                        company_content = content
                        print(f"[STEP 2] Colors from {url_info['url']}: {brand_colors}", flush=True)
                        break
                except Exception as e:
                    continue

        print(f"[TIMING] Step 2 (extract colors): {time.time() - step2_start:.1f}s", flush=True)

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
        # STEP 5: Have Opus select 3 best inspiration sites
        # ============================================
        step5_start = time.time()
        print("[STEP 5] Selecting best inspiration sites...", flush=True)

        # Format fetched content for analysis
        sites_for_analysis = "\n\n".join([
            f"URL: {c.get('url', 'unknown')}\nTitle: {c.get('title', 'unknown')}\nDescription: {c.get('text', '')[:300]}"
            for c in inspiration_content if not c.get("error")
        ])

        select_tool = {
            "name": "select_inspiration",
            "description": "Select the 3 best inspiration websites for this project",
            "input_schema": {
                "type": "object",
                "properties": {
                    "inspiration_sites": {
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 3,
                        "items": {
                            "type": "object",
                            "properties": {
                                "url": {"type": "string", "description": "Full URL to the website"},
                                "name": {"type": "string", "description": "Website/company name"},
                                "design_style": {"type": "string", "description": "Description of the design style (e.g., 'minimal with bold typography', 'full-bleed imagery with dark overlays')"},
                                "why": {"type": "string", "description": "Why this site is inspiring for this project (1 sentence)"},
                                "key_elements": {"type": "array", "items": {"type": "string"}, "description": "2-3 specific design elements to borrow (e.g., 'large hero image', 'animated text', 'floating cards')"}
                            },
                            "required": ["url", "name", "design_style", "why", "key_elements"]
                        }
                    },
                    "recommended_fonts": {
                        "type": "object",
                        "properties": {
                            "heading": {"type": "string", "description": "Recommended Google Font for headings"},
                            "body": {"type": "string", "description": "Recommended Google Font for body text"}
                        },
                        "description": "Based on the inspiration sites, recommend fonts that would work well"
                    }
                },
                "required": ["inspiration_sites", "recommended_fonts"]
            }
        }

        selection_response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=2000,
            tools=[select_tool],
            tool_choice={"type": "tool", "name": "select_inspiration"},
            messages=[{
                "role": "user",
                "content": f"""Select the 3 BEST inspiration websites for this web design project.

PROJECT: {self.project.brief}

BRAND COLORS WE'LL USE: {brand_colors[:5] if brand_colors else 'Not found - will need to create'}

WEBSITES FOUND:
{sites_for_analysis}

═══════════════════════════════════════════════════════════════
SELECTION CRITERIA:
═══════════════════════════════════════════════════════════════
1. VISUAL QUALITY: Sites with stunning, modern design
2. RELEVANCE: Sites in same or similar industry
3. DIVERSITY: Pick 3 sites with DIFFERENT design styles:
   - One with bold imagery/photography focus
   - One with typography-focused minimal design
   - One with unique layout/structure
4. PRACTICALITY: Designs we can actually implement

For each site, describe:
- The design style in detail
- Why it's inspiring for this specific project
- 2-3 specific design elements we should borrow

Also recommend Google Fonts that would match these inspiration sites."""
            }]
        )
        self.track_usage(selection_response)

        # Extract selected sites
        selected_sites = []
        recommended_fonts = {"heading": "Inter", "body": "Inter"}

        for block in selection_response.content:
            if block.type == "tool_use" and block.name == "select_inspiration":
                selected_sites = block.input.get("inspiration_sites", [])
                recommended_fonts = block.input.get("recommended_fonts", recommended_fonts)
                break

        print(f"[STEP 5] Selected {len(selected_sites)} inspiration sites", flush=True)
        for site in selected_sites:
            print(f"  - {site.get('name')}: {site.get('design_style')[:50]}...", flush=True)

        print(f"[TIMING] Step 5 (select best): {time.time() - step5_start:.1f}s", flush=True)

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

        # Store in project (reusing moodboard field for now)
        self.project.moodboard = {
            "research": research_data,
            "brand_colors": brand_colors,
            "fonts": recommended_fonts,
            "inspiration_sites": selected_sites
        }
        self.project.selected_moodboard = 1  # Not used anymore, but keep for compatibility
        self.project.status = ProjectStatus.MOODBOARD  # Will rename to RESEARCH later
        self.db.commit()

        print(f"[RESEARCH DATA] Full JSON:", flush=True)
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
