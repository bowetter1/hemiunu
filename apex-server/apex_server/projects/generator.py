"""Project generator - Opus calls for moodboard and layouts with web research"""
import json
import re
import httpx
import time
from pathlib import Path
from datetime import datetime
from typing import Optional, Callable, TypeVar
from bs4 import BeautifulSoup

from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from .models import Project, Page, ProjectLog, ProjectStatus

settings = get_settings()

# Model constants - easy to switch
MODEL_OPUS = "claude-opus-4-5-20251101"
MODEL_SONNET = "claude-sonnet-4-20250514"
MODEL_DEFAULT = MODEL_SONNET  # Use Sonnet by default (faster, cheaper)
MODEL_QUALITY = MODEL_OPUS    # Use Opus for quality-critical tasks

T = TypeVar('T')


def with_retry(fn: Callable[[], T], max_retries: int = 3, base_delay: float = 2.0) -> T:
    """Execute function with exponential backoff retry on overload errors"""
    last_error = None
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as e:
            error_str = str(e).lower()
            # Retry on overload (529) or rate limit errors
            if 'overloaded' in error_str or '529' in error_str or 'rate' in error_str:
                last_error = e
                delay = base_delay * (2 ** attempt)  # Exponential backoff
                print(f"[RETRY] Attempt {attempt + 1}/{max_retries} failed (overloaded), waiting {delay}s...", flush=True)
                time.sleep(delay)
            else:
                # Non-retryable error, raise immediately
                raise
    # All retries exhausted
    raise last_error


def fetch_page_content(url: str, timeout: float = 10.0) -> dict:
    """Fetch and extract content from a URL"""
    try:
        headers = {"User-Agent": "Mozilla/5.0 (compatible; ApexBot/1.0)"}
        response = httpx.get(url, headers=headers, timeout=timeout, follow_redirects=True)

        if response.status_code != 200:
            return {"url": url, "error": f"HTTP {response.status_code}"}

        soup = BeautifulSoup(response.text, 'html.parser')

        # Remove script and style elements
        for element in soup(['script', 'style', 'nav', 'footer', 'header']):
            element.decompose()

        # Extract title
        title = soup.title.string if soup.title else ""

        # Extract text content (limited)
        text = soup.get_text(separator=' ', strip=True)[:2000]

        # Try to find colors (hex codes)
        colors = re.findall(r'#[0-9A-Fa-f]{6}\b', response.text)
        unique_colors = list(dict.fromkeys(colors))[:10]  # Top 10 unique

        # Look for brand-specific patterns
        brand_colors = []
        if 'brandfetch' in url.lower():
            # Brandfetch has structured color data
            color_matches = re.findall(r'"hex":\s*"([^"]+)"', response.text)
            brand_colors = list(dict.fromkeys(color_matches))[:5]

        return {
            "url": url,
            "title": title,
            "text": text,
            "colors_found": unique_colors,
            "brand_colors": brand_colors
        }
    except Exception as e:
        return {"url": url, "error": str(e)}


def inject_google_fonts(html: str, fonts: dict) -> str:
    """Inject Google Fonts link into HTML head based on moodboard fonts"""
    if not fonts:
        return html

    font_families = []

    # Extract font names from moodboard fonts dict
    heading_font = fonts.get("heading") or fonts.get("primary") or fonts.get("title")
    body_font = fonts.get("body") or fonts.get("secondary") or fonts.get("text")

    if heading_font and isinstance(heading_font, str):
        # Clean font name and format for Google Fonts URL
        font_name = heading_font.split(",")[0].strip().strip("'\"")
        font_families.append(font_name.replace(" ", "+"))

    if body_font and isinstance(body_font, str):
        font_name = body_font.split(",")[0].strip().strip("'\"")
        if font_name.replace(" ", "+") not in font_families:
            font_families.append(font_name.replace(" ", "+"))

    if not font_families:
        return html

    # Build Google Fonts link with multiple weights
    families_param = "&family=".join([f"{f}:wght@300;400;500;600;700" for f in font_families])
    link_tag = f'<link href="https://fonts.googleapis.com/css2?family={families_param}&display=swap" rel="stylesheet">'

    # Remove any existing Google Fonts links to avoid duplicates
    html = re.sub(r'<link[^>]*fonts\.googleapis\.com[^>]*>', '', html)

    # Inject after <head> tag
    if "<head>" in html:
        html = html.replace("<head>", f"<head>\n    {link_tag}")
    elif "<HEAD>" in html:
        html = html.replace("<HEAD>", f"<HEAD>\n    {link_tag}")

    return html


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
            model="claude-opus-4-5-20251101",
            max_tokens=1000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool],
            messages=[{
                "role": "user",
                "content": f"""Find brand colors and visual identity for this web design project.

Project: {search_context}

IMPORTANT: Do these searches IN ORDER:
1. FIRST search for the company's official website directly (e.g. "site:forex.se" or just the domain)
2. THEN search for brand colors (e.g. "forex.se colors" or "company brandfetch")
3. THEN search for competitors

The FIRST search result should be the company's own website - we will fetch it to extract their actual colors."""
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
        # STEP 2: Fetch actual content from URLs
        # ============================================
        step2_start = time.time()
        print("[STEP 2] Fetching URL content...", flush=True)
        fetched_content = []
        all_colors_found = []

        for url in urls_to_fetch[:6]:  # Limit to 6 URLs
            print(f"[STEP 2] Fetching: {url[:50]}...", flush=True)
            content = fetch_page_content(url)
            fetched_content.append(content)

            # Collect colors
            all_colors_found.extend(content.get("brand_colors", []))
            all_colors_found.extend(content.get("colors_found", []))

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
            model="claude-opus-4-5-20251101",
            max_tokens=800,
            messages=[{
                "role": "user",
                "content": f"""Summarize this research for a web design project. Extract:
1. Brand colors found (list hex codes)
2. Design style and visual identity
3. Key elements to incorporate

Research data:
{research_text}

Colors found: {unique_colors}

Be concise but thorough."""
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
            "description": "Save 3 moodboard alternatives with exactly 3 colors each",
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
                    }
                },
                "required": ["moodboards"]
            }
        }

        moodboard_response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
            max_tokens=3000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[{
                "role": "user",
                "content": f"""Create 3 moodboard alternatives for this project.

PROJECT: {self.project.brief}

RESEARCH: {research_summary}

BRAND COLORS: {unique_colors}

RULES:
- Each moodboard has EXACTLY 3 colors (primary, secondary, accent)
- Short punchy names (2-3 words max)
- One sentence rationale
- Use actual brand colors from research for moodboard 1

Create:
1. Brand Faithful - matches existing brand
2. Modern Evolution - refined and contemporary
3. Bold Reimagining - fresh and daring"""
            }]
        )
        self.track_usage(moodboard_response)

        # Extract moodboards from tool use
        moodboards = []
        for block in moodboard_response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                break

        if moodboards:
            # Build research object
            research_data = {
                "queries": search_queries,
                "urls_fetched": [c["url"] for c in fetched_content],
                "colors_found": unique_colors,
                "summary": research_summary
            }

            # Log full research data
            print("[RESEARCH DATA] Full JSON:", flush=True)
            print(json.dumps(research_data, indent=2, ensure_ascii=False), flush=True)

            # Save everything
            self.project.moodboard = {
                "moodboards": moodboards,
                "research": research_data
            }
            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()

            # Log moodboards
            print("[MOODBOARDS] Full JSON:", flush=True)
            print(json.dumps(moodboards, indent=2, ensure_ascii=False), flush=True)

            self.log("moodboard", f"Success! Created {len(moodboards)} moodboards")
            print(f"[TIMING] Step 4 (create moodboards): {time.time() - step4_start:.1f}s", flush=True)
            print(f"[TIMING] TOTAL Phase 2: {time.time() - phase_start:.1f}s", flush=True)
            print(f"[MOODBOARD] Done! {len(moodboards)} moodboards created", flush=True)

            return moodboards

        # Fallback
        return self._fallback_moodboard()

    def _fallback_moodboard(self) -> list:
        """Fallback moodboard generation without research"""
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
            model="claude-opus-4-5-20251101",
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

    def search_and_clarify(self) -> dict:
        """
        PHASE 1: Initial search to identify if clarification is needed.

        Returns:
            dict with either:
            - {"needs_clarification": True, "question": "...", "options": [...]}
            - {"needs_clarification": False} (continue to Phase 2)
        """
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
            model="claude-opus-4-5-20251101",
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
            model="claude-opus-4-5-20251101",
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

        # ============================================
        # STEP 2: Fetch actual content from URLs
        # ============================================
        print(f"[STEP 2] Fetching content from {len(urls_to_fetch)} URLs...", flush=True)
        self.log("moodboard", "Step 2: Fetching page content...")

        fetched_content = []
        all_colors_found = []

        for url in urls_to_fetch[:6]:  # Limit to 6 URLs
            print(f"[STEP 2] Fetching: {url[:50]}...", flush=True)
            content = fetch_page_content(url)

            if "error" not in content:
                fetched_content.append(content)
                all_colors_found.extend(content.get("brand_colors", []))
                all_colors_found.extend(content.get("colors_found", [])[:3])
                print(f"[STEP 2] Got: {content.get('title', 'No title')[:40]}", flush=True)

                if content.get("brand_colors"):
                    print(f"[STEP 2] Brand colors: {content['brand_colors']}", flush=True)
                    self.log("moodboard", f"Found brand colors: {content['brand_colors']}")

        # Deduplicate colors
        unique_colors = list(dict.fromkeys(all_colors_found))[:15]
        print(f"[STEP 2] Total unique colors found: {unique_colors}", flush=True)

        # ============================================
        # STEP 3: Summarize findings with Haiku
        # ============================================
        print("[STEP 3] Summarizing findings...", flush=True)
        self.log("moodboard", "Step 3: Analyzing and summarizing research...")

        # Build content summary
        content_for_summary = []
        for c in fetched_content:
            content_for_summary.append(f"URL: {c['url']}\nTitle: {c.get('title', 'N/A')}\nContent: {c.get('text', '')[:500]}")

        summary_response = self.client.messages.create(
            model="claude-opus-4-5-20251101",  # Opus for better quality
            max_tokens=800,
            messages=[{
                "role": "user",
                "content": f"""Summarize the key findings for a web design project.

PROJECT: {self.project.brief}

COLORS FOUND ON PAGES: {unique_colors}

PAGE CONTENTS:
{chr(10).join(content_for_summary[:4])}

Provide a brief summary (max 200 words) with:
1. Brand colors identified (exact hex codes if found)
2. Design style/mood from competitors
3. Key visual elements to consider"""
            }]
        )
        self.track_usage(summary_response)

        research_summary = summary_response.content[0].text
        print(f"[STEP 3] Summary: {research_summary[:200]}...", flush=True)
        self.log("moodboard", f"Research summary: {research_summary[:300]}...")

        # ============================================
        # STEP 4: Create moodboards with Sonnet
        # ============================================
        print("[STEP 4] Creating moodboards with research...", flush=True)
        self.log("moodboard", "Step 4: Creating moodboards based on research...")

        moodboard_tool = {
            "name": "save_moodboards",
            "description": "Save the moodboard alternatives",
            "input_schema": {
                "type": "object",
                "properties": {
                    "moodboards": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "name": {"type": "string"},
                                "palette": {"type": "array", "items": {"type": "string"}, "description": "3-5 hex colors"},
                                "fonts": {
                                    "type": "object",
                                    "properties": {"heading": {"type": "string"}, "body": {"type": "string"}},
                                    "required": ["heading", "body"]
                                },
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

        moodboard_response = self.client.messages.create(
            model="claude-opus-4-5-20251101",  # Opus for best quality
            max_tokens=3000,
            tools=[moodboard_tool],
            tool_choice={"type": "tool", "name": "save_moodboards"},
            messages=[{
                "role": "user",
                "content": f"""Create THREE moodboard alternatives for this website.

PROJECT BRIEF: {self.project.brief}

RESEARCH FINDINGS:
{research_summary}

COLORS FOUND IN RESEARCH: {unique_colors}

IMPORTANT:
- Use the ACTUAL brand colors from research (not generic colors!)
- If brand colors were found, the first moodboard MUST use them
- Each moodboard should offer a different creative direction
- Use Google Fonts for typography

Create 3 moodboards now."""
            }]
        )
        self.track_usage(moodboard_response)

        # Extract moodboards
        moodboards = []
        for block in moodboard_response.content:
            if block.type == "tool_use" and block.name == "save_moodboards":
                moodboards = block.input.get("moodboards", [])
                print(f"[STEP 4] Created {len(moodboards)} moodboards", flush=True)

        if moodboards:
            # Build research object
            research_data = {
                "queries": search_queries,
                "urls_fetched": [c["url"] for c in fetched_content],
                "colors_found": unique_colors,
                "summary": research_summary
            }

            # Log full research data
            print("[RESEARCH DATA] Full JSON:", flush=True)
            print(json.dumps(research_data, indent=2, ensure_ascii=False), flush=True)

            # Save everything
            self.project.moodboard = {
                "moodboards": moodboards,
                "research": research_data
            }
            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()

            # Log moodboards
            print("[MOODBOARDS] Full JSON:", flush=True)
            print(json.dumps(moodboards, indent=2, ensure_ascii=False), flush=True)

            self.log("moodboard", f"Success! Created {len(moodboards)} moodboards")
            print(f"[MOODBOARD] Done! {len(moodboards)} moodboards created", flush=True)
            return moodboards

        # Fallback
        print("[MOODBOARD] No moodboards created, using fallback", flush=True)
        self.log("moodboard", "Warning: Using fallback")
        return self._generate_moodboard_fallback()

    def _generate_moodboard_fallback(self) -> list:
        """Fallback moodboard generation without web search"""
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
            model="claude-opus-4-5-20251101",  # Opus
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

    def generate_layouts(self) -> list[dict]:
        """Generate 3 layout alternatives using the selected moodboard"""
        layouts_start = time.time()
        print("[GENERATE_LAYOUTS] Starting...", flush=True)
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

        opus_start = time.time()
        print(f"[GENERATE_LAYOUTS] Calling Opus with moodboard: {moodboard.get('name', 'unknown')}", flush=True)
        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
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
        print(f"[TIMING] Opus layout generation: {time.time() - opus_start:.1f}s", flush=True)
        print(f"[GENERATE_LAYOUTS] Opus response received, stop_reason: {response.stop_reason}", flush=True)

        # Extract structured data from tool use
        layouts = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_layouts":
                layouts = block.input.get("layouts", [])

        print(f"[GENERATE_LAYOUTS] Extracted {len(layouts)} layouts", flush=True)

        # Save layouts as pages
        for i, layout in enumerate(layouts, 1):
            # Inject Google Fonts based on moodboard
            html = layout["html"]
            html = inject_google_fonts(html, moodboard.get("fonts", {}))

            # Try to save HTML file (optional - may fail on Railway)
            try:
                file_path = self.project_dir / f"layout_{i}.html"
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(html)
            except Exception:
                pass  # File storage is optional, DB is the source of truth

            # Create page record
            page = Page(
                project_id=self.project.id,
                name=layout.get("name", f"Layout {i}"),
                html=html,
                layout_variant=i
            )
            self.db.add(page)

        self.project.status = ProjectStatus.LAYOUTS
        self.db.commit()

        print(f"[TIMING] TOTAL layout generation: {time.time() - layouts_start:.1f}s", flush=True)
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
        """Select a layout and move to editing phase (keeps all 3 alternatives)"""
        page = self.db.query(Page).filter(
            Page.project_id == self.project.id,
            Page.layout_variant == variant
        ).first()

        if not page:
            raise ValueError(f"Layout {variant} not found")

        # Try to save as index.html (optional - may fail on Railway)
        try:
            self.project_dir.mkdir(parents=True, exist_ok=True)
            file_path = self.project_dir / "index.html"
            file_path.write_text(page.html)
        except Exception as e:
            print(f"Could not save file (non-critical): {e}", flush=True)

        # Keep all 3 layouts - just mark which one is selected
        # (Previously we deleted alternatives - now we keep them for browsing)
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

        # Inject Google Fonts based on moodboard
        moodboard = self.project.moodboard or {}
        if isinstance(moodboard, dict):
            # Get fonts from selected moodboard
            moodboards = moodboard.get("moodboards", [])
            if moodboards:
                # Use first moodboard's fonts (or selected one)
                fonts = moodboards[0].get("fonts", {})
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

        def make_request():
            return self.client.messages.create(
                model=MODEL_SONNET,  # Sonnet for new pages
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

        response = with_retry(make_request)
        self.track_usage(response)

        html = response.content[0].text
        if "```html" in html:
            html = html.split("```html")[1].split("```")[0]
        elif "```" in html:
            html = html.split("```")[1].split("```")[0]

        html = html.strip()

        # Inject Google Fonts based on moodboard
        moodboard = self.project.moodboard or {}
        if isinstance(moodboard, dict):
            moodboards = moodboard.get("moodboards", [])
            if moodboards:
                fonts = moodboards[0].get("fonts", {})
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
