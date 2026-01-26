"""Moodboard generation mixin with web research"""
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import TYPE_CHECKING

from .utils import MODEL_OPUS, fetch_page_content

if TYPE_CHECKING:
    from .base import Generator


class MoodboardMixin:
    """Mixin for moodboard generation methods"""

    def generate_moodboard(self: "Generator") -> list:
        """
        Generate 3 moodboard alternatives with deep web research.

        This is PHASE 2 - called after clarification (if needed).
        For Phase 1 (initial search), use search_and_clarify().
        """
        phase_start = time.time()
        print(f"[MOODBOARD PHASE 2] Starting for project {self.project.id}", flush=True)

        # Get clarification data if available
        clarification = self.project.clarification or {}
        user_answer = clarification.get("answer", "")
        initial_research = clarification.get("initial_research", {})

        # Build search context from clarification
        search_context = self.project.brief
        if user_answer:
            search_context = f"{self.project.brief}\n\nUser clarification: {user_answer}"
            print(f"[MOODBOARD] Using clarification: {user_answer}", flush=True)

        self.log("moodboard", "Starting targeted search with clarification...")

        # ============================================
        # STEP 1: Targeted search with clarification
        # ============================================
        step1_start = time.time()
        print("[STEP 1] Targeted search...", flush=True)

        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5
        }

        search_response = self.client.beta.messages.create(
            model=MODEL_OPUS,
            max_tokens=1000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool],
            messages=[{
                "role": "user",
                "content": f"""Find brand colors, visual identity, AND design inspiration for this web design project.

Project: {search_context}

IMPORTANT: Do these searches IN ORDER:
1. FIRST search for the company's official website directly (e.g. "site:forex.se" or just the domain)
2. THEN search for brand colors (e.g. "forex.se colors" or "company brandfetch")
3. THEN search for DESIGN INSPIRATION - beautiful websites in the same industry!
   Examples:
   - For a bakery: "best bakery website design 2024" or "beautiful cafe website examples"
   - For a restaurant: "best restaurant website design inspiration"
   - For a tech company: "best SaaS landing page design"
   - For a law firm: "best law firm website design modern"

The design inspiration search is CRITICAL - we want to see what the best websites in this industry look like so we can create something equally beautiful."""
            }]
        )
        self.track_usage(search_response)

        # Extract URLs from search results
        urls_to_fetch = []
        search_queries = []

        for block in search_response.content:
            if block.type == "server_tool_use" and getattr(block, 'name', '') == "web_search":
                query = getattr(block, 'input', {}).get('query', '')
                if query:
                    search_queries.append(query)
                    print(f"[STEP 1] Search: {query}", flush=True)

            if block.type == "web_search_tool_result":
                content = getattr(block, 'content', [])
                if isinstance(content, list):
                    for item in content[:3]:
                        url = getattr(item, 'url', '')
                        if url and url not in urls_to_fetch:
                            urls_to_fetch.append(url)
                            print(f"[STEP 1] Found: {url[:60]}...", flush=True)

        self.log("moodboard", f"Found {len(urls_to_fetch)} URLs to analyze")
        print(f"[TIMING] Step 1 (web search): {time.time() - step1_start:.1f}s", flush=True)

        # ============================================
        # STEP 2: Fetch actual content from URLs (PARALLEL)
        # ============================================
        step2_start = time.time()
        print("[STEP 2] Fetching URL content in parallel...", flush=True)
        fetched_content = []
        all_colors_found = []

        # Fetch URLs in parallel for speed
        with ThreadPoolExecutor(max_workers=4) as executor:
            future_to_url = {executor.submit(fetch_page_content, url): url for url in urls_to_fetch[:6]}
            for future in as_completed(future_to_url):
                url = future_to_url[future]
                try:
                    content = future.result()
                    fetched_content.append(content)
                    all_colors_found.extend(content.get("brand_colors", []))
                    all_colors_found.extend(content.get("colors_found", []))
                    print(f"[STEP 2] Fetched: {url[:50]}...", flush=True)
                except Exception as e:
                    print(f"[STEP 2] Error: {url[:40]}: {e}", flush=True)

        unique_colors = list(dict.fromkeys(all_colors_found))[:15]
        print(f"[STEP 2] Found {len(unique_colors)} unique colors", flush=True)
        print(f"[TIMING] Step 2 (fetch URLs): {time.time() - step2_start:.1f}s", flush=True)

        # ============================================
        # STEP 3: Summarize research with Opus
        # ============================================
        step3_start = time.time()
        print("[STEP 3] Summarizing research...", flush=True)

        research_text = "\n\n".join([
            f"URL: {c.get('url', 'unknown')}\nTitle: {c.get('title', 'unknown')}\nColors: {c.get('brand_colors', []) or c.get('colors_found', [])}\nContent: {c.get('text', '')[:500]}"
            for c in fetched_content if not c.get("error")
        ])

        summary_response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=1200,
            messages=[{
                "role": "user",
                "content": f"""Summarize this research for a web design project. Extract:

1. BRAND COLORS (list hex codes from the company's actual website)
2. DESIGN STYLE and visual identity of the brand
3. KEY ELEMENTS to incorporate

4. DESIGN INSPIRATION from similar websites:
   - What design patterns work well in this industry?
   - Hero section styles (full-bleed images, split layouts, video backgrounds?)
   - Typography trends (bold headlines, elegant serifs, modern sans?)
   - Color usage (dark mode, light & airy, warm & cozy?)
   - Notable features from the best sites in this category

Research data:
{research_text}

Colors found: {unique_colors}

Focus on actionable insights that will help create a beautiful, modern website."""
            }]
        )
        self.track_usage(summary_response)

        research_summary = summary_response.content[0].text
        print(f"[STEP 3] Summary: {research_summary[:200]}...", flush=True)
        print(f"[TIMING] Step 3 (summarize): {time.time() - step3_start:.1f}s", flush=True)

        # ============================================
        # STEP 4: Create moodboards using research
        # ============================================
        step4_start = time.time()
        print("[STEP 4] Creating moodboards...", flush=True)

        moodboard_tool = {
            "name": "save_moodboards",
            "description": "Save 3 moodboard alternatives with inspiration sites and recommendation",
            "input_schema": {
                "type": "object",
                "properties": {
                    "moodboards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string", "description": "Short, punchy name (2-3 words)"},
                                "palette": {"type": "array", "items": {"type": "string"}, "minItems": 3, "maxItems": 3, "description": "Exactly 3 hex colors"},
                                "fonts": {"type": "object", "properties": {"heading": {"type": "string"}, "body": {"type": "string"}}},
                                "mood": {"type": "array", "items": {"type": "string"}, "maxItems": 3},
                                "rationale": {"type": "string", "description": "One sentence explanation"}
                            },
                            "required": ["name", "palette", "fonts", "mood", "rationale"]
                        }
                    },
                    "inspiration_sites": {
                        "type": "array",
                        "minItems": 3,
                        "maxItems": 5,
                        "items": {
                            "type": "object",
                            "properties": {
                                "url": {"type": "string", "description": "Full URL to the inspiration website"},
                                "name": {"type": "string", "description": "Website/company name"},
                                "why": {"type": "string", "description": "Why this site is inspiring (1 sentence)"}
                            },
                            "required": ["url", "name", "why"]
                        },
                        "description": "3-5 beautiful websites that inspire this design"
                    },
                    "recommended": {
                        "type": "integer",
                        "minimum": 1,
                        "maximum": 3,
                        "description": "Which moodboard (1, 2, or 3) do you recommend? Pick the one that best matches the brand."
                    },
                    "recommendation_reason": {
                        "type": "string",
                        "description": "One sentence explaining why you recommend this moodboard"
                    }
                },
                "required": ["moodboards", "inspiration_sites", "recommended", "recommendation_reason"]
            }
        }

        moodboard_response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=4000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[{
                "role": "user",
                "content": f"""Create 3 moodboard alternatives for this project AND select the best one.

PROJECT: {self.project.brief}

RESEARCH & DESIGN INSPIRATION: {research_summary}

RAW COLORS FOUND ON PAGE: {unique_colors}

⚠️ CRITICAL - IGNORE THESE COLORS (they are from social media widgets, NOT the brand):
- #1877F2, #4267B2, #3b5998 = Facebook blue
- #1DA1F2 = Twitter blue
- #FF0000, #CC0000 = YouTube red
- #E1306C, #C13584, #833AB4 = Instagram colors
- #0077B5, #0A66C2 = LinkedIn blue
- Any pure gray (#f5f5f5, #e8e8e8, #cccccc, etc.)

✅ USE COLORS FROM:
- The company's LOGO (most important!)
- Navigation/header background
- Buttons and CTAs on THEIR site
- Footer or accent elements

URLS WE FOUND: {[c.get('url', '') for c in fetched_content]}

══════════════════════════════════════════════════════════════
TASK 1: Create 3 moodboards
══════════════════════════════════════════════════════════════
- Each moodboard has EXACTLY 3 colors (primary, secondary, accent)
- Short punchy names (2-3 words max)
- One sentence rationale
- USE THE REAL BRAND COLORS, not social media widget colors!

1. Brand Faithful - uses the ACTUAL brand colors from their logo/website
2. Modern Evolution - refines and modernizes the brand palette
3. Bold Reimagining - fresh, daring new direction

══════════════════════════════════════════════════════════════
TASK 2: List 3-5 INSPIRATION WEBSITES
══════════════════════════════════════════════════════════════
From the research, identify 3-5 beautiful websites that should inspire this design.
These should be REAL websites you found that have great design in this industry.
Include the full URL, site name, and WHY it's inspiring.

Examples of what to look for:
- Stunning hero sections
- Beautiful typography
- Great use of imagery
- Modern, clean layouts
- Sites that match the mood we're going for

══════════════════════════════════════════════════════════════
TASK 3: RECOMMEND one moodboard
══════════════════════════════════════════════════════════════
Pick which moodboard (1, 2, or 3) you think is BEST for this project.
Consider: brand fit, modern appeal, industry standards."""
            }]
        )
        self.track_usage(moodboard_response)

        # Extract moodboards from tool use
        moodboards = []
        inspiration_sites = []
        recommended = 1
        recommendation_reason = ""

        for block in moodboard_response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                inspiration_sites = block.input.get("inspiration_sites", [])
                recommended = block.input.get("recommended", 1)
                recommendation_reason = block.input.get("recommendation_reason", "")
                break

        if moodboards:
            from ..models import ProjectStatus

            # Build research object
            research_data = {
                "queries": search_queries,
                "urls_fetched": [c.get("url", "") for c in fetched_content],
                "colors_found": unique_colors,
                "summary": research_summary,
                "inspiration_sites": inspiration_sites  # NEW: Save inspiration sites
            }

            # Log full research data
            print("[RESEARCH DATA] Full JSON:", flush=True)
            print(json.dumps(research_data, indent=2, ensure_ascii=False), flush=True)

            # Log inspiration sites
            print(f"[INSPIRATION] Found {len(inspiration_sites)} inspiration sites:", flush=True)
            for site in inspiration_sites:
                print(f"  - {site.get('name')}: {site.get('url')}", flush=True)

            # Save everything including recommendation
            self.project.moodboard = {
                "moodboards": moodboards,
                "research": research_data,
                "recommended": recommended,
                "recommendation_reason": recommendation_reason
            }

            # AUTO-SELECT: Use the recommended moodboard
            self.project.selected_moodboard = recommended
            print(f"[AUTO-SELECT] AI recommends moodboard {recommended}: {recommendation_reason}", flush=True)

            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()

            # Log moodboards
            print("[MOODBOARDS] Full JSON:", flush=True)
            print(json.dumps(moodboards, indent=2, ensure_ascii=False), flush=True)

            self.log("moodboard", f"Created {len(moodboards)} moodboards, auto-selected #{recommended}")
            print(f"[TIMING] Step 4 (create moodboards): {time.time() - step4_start:.1f}s", flush=True)
            print(f"[TIMING] TOTAL Phase 2: {time.time() - phase_start:.1f}s", flush=True)
            print(f"[MOODBOARD] Done! {len(moodboards)} moodboards created", flush=True)

            return moodboards

        # Fallback
        return self._fallback_moodboard()

    def _fallback_moodboard(self: "Generator") -> list:
        """Fallback moodboard generation without research"""
        from ..models import ProjectStatus

        print("[FALLBACK] Creating moodboards without research...", flush=True)

        moodboard_tool = {
            "name": "save_moodboards",
            "description": "Save 3 moodboard alternatives",
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
                                "fonts": {"type": "object"},
                                "mood": {"type": "array", "items": {"type": "string"}},
                                "rationale": {"type": "string"}
                            }
                        }
                    }
                }
            }
        }

        response = self.client.messages.create(
            model=MODEL_OPUS,
            max_tokens=4000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[{"role": "user", "content": f"Create 3 moodboards for: {self.project.brief}"}]
        )
        self.track_usage(response)

        moodboards = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                break

        if moodboards:
            self.project.moodboard = {"moodboards": moodboards}
            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()

        return moodboards

    def search_and_clarify(self: "Generator") -> dict:
        """
        PHASE 1: Initial search to identify if clarification is needed.

        Returns:
            dict with either:
            - {"needs_clarification": True, "question": "...", "options": [...]}
            - {"needs_clarification": False} (continue to Phase 2)
        """
        from ..models import ProjectStatus

        phase1_start = time.time()
        print(f"[PHASE 1] Initial search for project {self.project.id}", flush=True)
        print(f"[PHASE 1] Brief: {self.project.brief[:100]}...", flush=True)
        self.log("moodboard", "Phase 1: Initial search to identify brand...")

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

                    self.log("moodboard", f"Needs clarification: {decision.get('question')}")
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

                    self.log("moodboard", f"Brand identified: {decision.get('identified_brand')}")
                    return {"needs_clarification": False}

        # Fallback - proceed without clarification
        return {"needs_clarification": False}

    def _generate_moodboard_fallback(self: "Generator") -> list:
        """Fallback moodboard generation without web search"""
        from ..models import ProjectStatus

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
            model=MODEL_OPUS,
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
