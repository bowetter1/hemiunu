"""Site generation mixin with agentic file tools"""
import json
from typing import TYPE_CHECKING

from .utils import MODEL_SONNET, with_retry, inject_google_fonts

if TYPE_CHECKING:
    from .base import Generator


class SiteGenerationMixin:
    """Mixin for site generation and agentic editing"""

    # MARK: - Agentic File Tools

    def get_file_tools(self: "Generator"):
        """Define file tools for agentic editing"""
        return [
            {
                "name": "list_files",
                "description": "List all files/pages in the current project",
                "input_schema": {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
            },
            {
                "name": "read_file",
                "description": "Read the content of a file/page",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "File name (e.g., 'index.html', 'about.html')"
                        }
                    },
                    "required": ["name"]
                }
            },
            {
                "name": "write_file",
                "description": "Create or update a file/page with HTML content",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "File name (e.g., 'contact.html')"
                        },
                        "content": {
                            "type": "string",
                            "description": "Complete HTML content for the file"
                        }
                    },
                    "required": ["name", "content"]
                }
            },
            {
                "name": "delete_file",
                "description": "Delete a file/page from the project",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "File name to delete"
                        }
                    },
                    "required": ["name"]
                }
            },
            {
                "name": "generate_image",
                "description": "Generate an AI image using DALL-E and save it to the project. Use for hero backgrounds, illustrations, logos, etc.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "prompt": {
                            "type": "string",
                            "description": "Detailed description of the image. Include style, colors, mood, composition details."
                        },
                        "filename": {
                            "type": "string",
                            "description": "Filename to save as (e.g., 'hero-bg.png', 'team-photo.png')"
                        },
                        "size": {
                            "type": "string",
                            "enum": ["1024x1024", "1792x1024", "1024x1792"],
                            "description": "Image size. Use 1792x1024 for landscape/hero banners, 1024x1792 for portrait, 1024x1024 for square."
                        },
                        "style": {
                            "type": "string",
                            "enum": ["vivid", "natural"],
                            "description": "Style: 'vivid' for dramatic/artistic, 'natural' for realistic/photographic"
                        }
                    },
                    "required": ["prompt", "filename"]
                }
            }
        ]

    def execute_file_tool(self: "Generator", tool_name: str, tool_input: dict) -> str:
        """Execute a file tool and return result"""
        from ..models import Page, PageVersion

        print(f"[TOOL] Executing {tool_name} with input: {tool_input}", flush=True)

        if tool_name == "list_files":
            # List from filesystem
            files = self.fs.list_files("public")
            if not files:
                # Fallback to PostgreSQL during migration
                pages = self.db.query(Page).filter(
                    Page.project_id == self.project.id
                ).all()
                files = []
                for p in pages:
                    name = p.name.lower().replace(" ", "-") + ".html"
                    files.append({"name": name, "path": f"public/{name}", "is_dir": False, "size": len(p.html)})
            return json.dumps({"files": files})

        elif tool_name == "read_file":
            file_name = tool_input.get("name", "")
            # Try filesystem first
            content = self.fs.read_file(f"public/{file_name}")
            if content:
                page = self._find_page_by_filename(file_name)
                return json.dumps({
                    "name": file_name,
                    "content": content,
                    "page_id": str(page.id) if page else None
                })
            # Fallback to PostgreSQL
            page = self._find_page_by_filename(file_name)
            if page:
                return json.dumps({
                    "name": file_name,
                    "content": page.html,
                    "page_id": str(page.id)
                })
            return json.dumps({"error": f"File '{file_name}' not found"})

        elif tool_name == "write_file":
            file_name = tool_input.get("name", "")
            content = tool_input.get("content", "")

            # Inject Google Fonts from moodboard.fonts
            moodboard = self.project.moodboard or {}
            if isinstance(moodboard, dict):
                fonts = moodboard.get("fonts")
                if fonts:
                    content = inject_google_fonts(content, fonts)

            # Write to filesystem
            self.fs.write_file(f"public/{file_name}", content)

            # Check if page exists in PostgreSQL
            page = self._find_page_by_filename(file_name)
            if page:
                # Update existing
                page.html = content
                # Save new version
                new_version = page.current_version + 1
                page.current_version = new_version
                self.fs.save_version(str(page.id), new_version, content)
                # Create PageVersion record in PostgreSQL
                page_version = PageVersion(
                    page_id=page.id,
                    version=new_version,
                    html=content,
                    instruction="Agentic edit"
                )
                self.db.add(page_version)
                self.db.commit()
                self.log("edit", f"Updated {file_name} (v{new_version})")
                return json.dumps({"status": "updated", "name": file_name, "page_id": str(page.id), "version": new_version})
            else:
                # Create new page with parent_page_id if set
                page_name = file_name.replace(".html", "").replace("-", " ").title()
                parent_id = getattr(self, '_current_parent_page_id', None)
                new_page = Page(
                    project_id=self.project.id,
                    name=page_name,
                    html=content,
                    parent_page_id=parent_id
                )
                self.db.add(new_page)
                self.db.flush()
                # Save v1 to versions (filesystem + PostgreSQL)
                self.fs.save_version(str(new_page.id), 1, content)
                page_version = PageVersion(
                    page_id=new_page.id,
                    version=1,
                    html=content,
                    instruction="Initial version"
                )
                self.db.add(page_version)
                self.db.commit()
                self.log("edit", f"Created {file_name} (parent: {parent_id})")
                return json.dumps({"status": "created", "name": file_name, "page_id": str(new_page.id), "parent_page_id": parent_id})

        elif tool_name == "delete_file":
            file_name = tool_input.get("name", "")
            # Delete from filesystem
            self.fs.delete_file(f"public/{file_name}")
            # Delete from PostgreSQL
            page = self._find_page_by_filename(file_name)
            if page:
                # Delete versions
                self.fs.delete_versions(str(page.id))
                self.db.delete(page)
                self.db.commit()
                self.log("edit", f"Deleted {file_name}")
                return json.dumps({"status": "deleted", "name": file_name})
            else:
                return json.dumps({"error": f"File '{file_name}' not found"})

        elif tool_name == "generate_image":
            # Delegate to image generation mixin
            return self.execute_image_tool(tool_name, tool_input)

        return json.dumps({"error": f"Unknown tool: {tool_name}"})

    def _find_page_by_filename(self: "Generator", filename: str):
        """Find a page by its filename (e.g., 'about.html' -> page named 'About')"""
        from ..models import Page

        # Remove .html extension and convert to page name format
        name_part = filename.replace(".html", "").replace("-", " ")

        pages = self.db.query(Page).filter(
            Page.project_id == self.project.id
        ).all()

        for page in pages:
            page_filename = page.name.lower().replace(" ", "-") + ".html"
            if page_filename == filename.lower():
                return page
            # Also check direct name match
            if page.name.lower() == name_part.lower():
                return page

        return None

    def agentic_edit(self: "Generator", instruction: str, page_id: str = None) -> str:
        """
        Agentic editing with file tools.
        Opus can read/write/list files as needed to complete the instruction.
        """
        from ..models import Page

        self.log("edit", f"Agentic edit: {instruction}")

        # Build context about current project
        pages = self.db.query(Page).filter(Page.project_id == self.project.id).all()
        files_list = [p.name.lower().replace(" ", "-") + ".html" for p in pages]

        # If editing a specific page, include its content
        current_file_context = ""
        if page_id:
            page = self.db.query(Page).filter(Page.id == page_id).first()
            if page:
                filename = page.name.lower().replace(" ", "-") + ".html"
                current_file_context = f"\n\nCurrently selected file: {filename}\n```html\n{page.html}\n```"

        # Get design context from 04-design-brief.md
        moodboard_context = ""
        design_brief_md = self.fs.read_pipeline_file("04-design-brief.md")
        if design_brief_md:
            moodboard_context = f"\nDesign Brief:\n{design_brief_md}\n"

        system_prompt = f"""You are a web developer working on a website project.

Project files: {', '.join(files_list) if files_list else 'No files yet'}
{moodboard_context}

You have tools to:
- list_files: See all files in the project
- read_file: Read a file's content
- write_file: Create or update a file
- delete_file: Remove a file
- generate_image: Generate an AI image with DALL-E

IMPORTANT - When adding images:
1. First generate the image with generate_image tool (use descriptive prompts matching the brand/mood)
2. THEN update the HTML with write_file to include the image: <img src="images/filename.png">
3. Always do BOTH steps - generating alone is not enough!

Image prompt tips:
- Use colors that match the project's palette
- Match the mood/style of the brand
- Be specific about composition, lighting, style
- For multiple images, make each unique but cohesive

Example workflow for adding images:
1. generate_image with detailed prompt -> saves to images/name.png
2. write_file to update HTML with <img src="images/name.png">

When creating/editing HTML:
- Use the project's color palette and fonts
- Keep consistent styling across pages
- Include complete HTML with inline CSS
- Make it responsive

Complete the user's request using the available tools."""

        messages = [
            {"role": "user", "content": instruction + current_file_context}
        ]

        # Agentic loop - keep going until Opus stops using tools
        max_iterations = 10
        final_response = ""

        for i in range(max_iterations):
            print(f"[AGENTIC] Iteration {i+1}", flush=True)

            def make_request():
                return self.client.messages.create(
                    model=MODEL_SONNET,
                    max_tokens=8000,
                    system=system_prompt,
                    tools=self.get_file_tools(),
                    messages=messages
                )

            response = with_retry(make_request)
            self.track_usage(response)

            # Process response
            tool_calls = []
            text_content = ""

            for block in response.content:
                if block.type == "text":
                    text_content += block.text
                elif block.type == "tool_use":
                    tool_calls.append(block)

            # If no tool calls, we're done
            if not tool_calls:
                final_response = text_content
                print(f"[AGENTIC] Done - no more tool calls", flush=True)
                break

            # Execute tool calls and add results to messages
            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for tool_call in tool_calls:
                result = self.execute_file_tool(tool_call.name, tool_call.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_call.id,
                    "content": result
                })

            messages.append({"role": "user", "content": tool_results})

            # Check stop reason
            if response.stop_reason == "end_turn":
                final_response = text_content
                break

        self.log("edit", "Agentic edit complete")
        return final_response

    def generate_site(self: "Generator", parent_page_id: str, pages: list[str] = None) -> dict:
        """
        Generate additional pages for the site based on navigation links.
        Parses the parent layout/hero page to find linked pages and creates them.

        Args:
            parent_page_id: The ID of the layout/hero page to use as template
            pages: Optional list of page names to create. If None, parsed from nav.

        Returns:
            dict with created pages and summary
        """
        from ..models import Page

        self.log("site", f"Starting site generation from parent {parent_page_id}...")

        # Store parent_page_id for use in execute_file_tool
        self._current_parent_page_id = parent_page_id

        # Get the parent/template page
        template_page = self.db.query(Page).filter(Page.id == parent_page_id).first()
        if not template_page:
            raise ValueError("Parent page not found")

        template_html = template_page.html
        template_filename = template_page.name.lower().replace(" ", "-") + ".html"

        # Get existing child pages for this parent
        existing_children = self.db.query(Page).filter(Page.parent_page_id == parent_page_id).all()
        existing_filenames = [template_filename] + [p.name.lower().replace(" ", "-") + ".html" for p in existing_children]

        # Get design context from 04-design-brief.md
        moodboard_context = ""
        design_brief_md = self.fs.read_pipeline_file("04-design-brief.md")
        if design_brief_md:
            moodboard_context = f"\nDesign Brief:\n{design_brief_md}\n"

        system_prompt = f"""You are a professional web developer expanding a website.

{moodboard_context}

Project Brief: {self.project.brief}

EXISTING INDEX PAGE ({template_filename}) - THIS IS YOUR STYLE TEMPLATE:
```html
{template_html}
```

EXISTING FILES (DO NOT recreate these):
{', '.join(existing_filenames)}

You have tools to:
- list_files: See all files in the project
- read_file: Read a file's content
- write_file: Create or update a file
- delete_file: Remove a file

YOUR TASK:
1. Look at the navigation links in the index page (e.g., about.html, contact.html, services.html)
2. Create ONLY the pages that are linked but don't exist yet
3. DO NOT recreate {template_filename} - it already exists!

CRITICAL STYLE REQUIREMENTS:
1. Copy the EXACT same CSS/styles from the index page
2. Use the same colors, fonts, spacing, layout structure
3. Keep the same header/navigation on all pages
4. Keep the same footer on all pages
5. Only change the main content section for each page
6. Include the same Google Fonts import

Each new page should feel like it belongs to the same website - consistent header, footer, colors, fonts, and overall design language.

Create appropriate content for each page based on the page name and the project brief."""

        messages = [
            {"role": "user", "content": "Analyze the navigation in the index page and create each missing linked page. Match the exact style."}
        ]

        # Agentic loop
        max_iterations = 15  # More iterations for multi-page generation
        created_pages = []
        final_response = ""

        for i in range(max_iterations):
            print(f"[GENERATE_SITE] Iteration {i+1}", flush=True)

            def make_request():
                return self.client.messages.create(
                    model=MODEL_SONNET,  # Sonnet for speed
                    max_tokens=12000,  # More tokens for full pages
                    system=system_prompt,
                    tools=self.get_file_tools(),
                    messages=messages
                )

            response = with_retry(make_request)
            self.track_usage(response)

            # Process response
            tool_calls = []
            text_content = ""

            for block in response.content:
                if block.type == "text":
                    text_content += block.text
                elif block.type == "tool_use":
                    tool_calls.append(block)

            # If no tool calls, we're done
            if not tool_calls:
                final_response = text_content
                print(f"[GENERATE_SITE] Done - no more tool calls", flush=True)
                break

            # Execute tool calls
            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for tool_call in tool_calls:
                result = self.execute_file_tool(tool_call.name, tool_call.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_call.id,
                    "content": result
                })

                # Track created pages
                if tool_call.name == "write_file":
                    page_name = tool_call.input.get("name", "")
                    if page_name and page_name not in created_pages:
                        created_pages.append(page_name)
                        print(f"[GENERATE_SITE] Created: {page_name}", flush=True)

            messages.append({"role": "user", "content": tool_results})

            if response.stop_reason == "end_turn":
                final_response = text_content
                break

        # Step 2: Update parent page navigation to link to all child pages
        if created_pages:
            self._update_parent_navigation(parent_page_id, created_pages)

        self.log("site", f"Site generation complete: {len(created_pages)} pages")

        return {
            "pages_created": created_pages,
            "summary": final_response,
            "total_pages": len(created_pages)
        }

    def _update_parent_navigation(self: "Generator", parent_page_id: str, child_pages: list[str]):
        """Update the parent page's navigation to include working links to all child pages."""
        from ..models import Page

        print(f"[GENERATE_SITE] Updating parent navigation with {len(child_pages)} child pages", flush=True)
        self.log("site", "Updating parent page navigation...")

        # Get parent page
        parent_page = self.db.query(Page).filter(Page.id == parent_page_id).first()
        if not parent_page:
            print("[GENERATE_SITE] Parent page not found, skipping nav update", flush=True)
            return

        # Get all child pages for complete navigation
        all_children = self.db.query(Page).filter(Page.parent_page_id == parent_page_id).all()
        child_filenames = [p.name.lower().replace(" ", "-") + ".html" for p in all_children]

        # Build navigation context
        nav_links = "\n".join([f"- {name}: {name.lower().replace(' ', '-')}.html" for name in [p.name for p in all_children]])

        update_prompt = f"""Update this HTML page's navigation to include working links to all child pages.

CURRENT HTML:
```html
{parent_page.html}
```

CHILD PAGES THAT NEED TO BE LINKED:
{nav_links}

REQUIREMENTS:
1. Update all navigation links (in header/nav) to point to the correct .html files
2. Replace any href="#" or placeholder links with actual page links
3. Keep the index/home link pointing to index.html or #
4. DO NOT change anything else - same styles, content, structure
5. Return the COMPLETE updated HTML

Return ONLY the updated HTML, no explanations."""

        def make_request():
            return self.client.messages.create(
                model=MODEL_SONNET,
                max_tokens=8000,
                messages=[{"role": "user", "content": update_prompt}]
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

        # Update parent page
        if new_html and len(new_html) > 100:  # Sanity check
            parent_page.html = new_html
            self.db.commit()
            print(f"[GENERATE_SITE] Parent page navigation updated", flush=True)
            self.log("site", "Parent page navigation updated with working links")
        else:
            print(f"[GENERATE_SITE] Invalid HTML response, skipping nav update", flush=True)
