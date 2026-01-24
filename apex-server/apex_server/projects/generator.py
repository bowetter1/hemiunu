"""Project generator - Opus calls for moodboard and layouts with web research"""
import json
import re
import httpx
from pathlib import Path
from datetime import datetime
from typing import Optional
from bs4 import BeautifulSoup

from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from .models import Project, Page, ProjectLog, ProjectStatus

settings = get_settings()


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

        Flow:
        1. Claude searches for relevant URLs (brand colors, competitors, trends)
        2. We FETCH actual content from top URLs
        3. Haiku summarizes findings
        4. Sonnet creates moodboards based on real data
        """
        print(f"[MOODBOARD] Starting for project {self.project.id}", flush=True)
        print(f"[MOODBOARD] Brief: {self.project.brief[:100]}...", flush=True)
        self.log("moodboard", "Starting moodboard generation...")

        # ============================================
        # STEP 1: Search for relevant URLs
        # ============================================
        print("[STEP 1] Searching for URLs...", flush=True)
        self.log("moodboard", "Step 1: Searching web for brand info and inspiration...")

        web_search_tool = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5
        }

        search_response = self.client.beta.messages.create(
            model="claude-haiku-3-5-20241022",  # Fast & cheap for search
            max_tokens=1000,
            betas=["web-search-2025-03-05"],
            tools=[web_search_tool],
            messages=[{
                "role": "user",
                "content": f"""Search for information about this project. Find:
1. Brand colors and visual identity (if a company is mentioned)
2. Competitor websites in the same industry
3. Current design trends

Project: {self.project.brief}

Do 2-3 targeted searches to find the most relevant information."""
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
                    for item in content[:3]:  # Top 3 from each search
                        url = getattr(item, 'url', '')
                        if url and url not in urls_to_fetch:
                            urls_to_fetch.append(url)
                            print(f"[STEP 1] Found: {url[:60]}...", flush=True)

        self.log("moodboard", f"Found {len(urls_to_fetch)} URLs to analyze")

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
            model="claude-haiku-3-5-20241022",
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
            model="claude-sonnet-4-5-20250929",
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
            # Save everything
            self.project.moodboard = {
                "moodboards": moodboards,
                "research": {
                    "queries": search_queries,
                    "urls_fetched": [c["url"] for c in fetched_content],
                    "colors_found": unique_colors,
                    "summary": research_summary
                }
            }
            self.project.status = ProjectStatus.MOODBOARD
            self.db.commit()

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
            model="claude-sonnet-4-5-20250929",
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

        # Extract structured data from tool use
        layouts = []
        for block in response.content:
            if block.type == "tool_use" and block.name == "save_layouts":
                layouts = block.input.get("layouts", [])

        # Save layouts as pages
        for i, layout in enumerate(layouts, 1):
            # Try to save HTML file (optional - may fail on Railway)
            try:
                file_path = self.project_dir / f"layout_{i}.html"
                file_path.parent.mkdir(parents=True, exist_ok=True)
                file_path.write_text(layout["html"])
            except Exception:
                pass  # File storage is optional, DB is the source of truth

            # Create page record
            page = Page(
                project_id=self.project.id,
                name=layout.get("name", f"Layout {i}"),
                html=layout["html"],
                layout_variant=i
            )
            self.db.add(page)

        self.project.status = ProjectStatus.LAYOUTS
        self.db.commit()

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

        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
            max_tokens=8000,
            system="""You are a web developer. Modify the HTML code based on the instruction.
Respond ONLY with the updated HTML code, nothing else.""",
            messages=[
                {"role": "user", "content": f"Current HTML:\n```html\n{page.html}\n```\n\nInstruction: {instruction}"}
            ]
        )

        self.track_usage(response)

        # Extract HTML from response
        new_html = response.content[0].text
        if "```html" in new_html:
            new_html = new_html.split("```html")[1].split("```")[0]
        elif "```" in new_html:
            new_html = new_html.split("```")[1].split("```")[0]

        # Update page
        page.html = new_html.strip()
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

        response = self.client.messages.create(
            model="claude-opus-4-5-20251101",
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

        self.track_usage(response)

        html = response.content[0].text
        if "```html" in html:
            html = html.split("```html")[1].split("```")[0]
        elif "```" in html:
            html = html.split("```")[1].split("```")[0]

        # Create page
        page = Page(
            project_id=self.project.id,
            name=name,
            html=html.strip()
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
