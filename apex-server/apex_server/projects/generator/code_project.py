"""Code project generation mixin - uses filesystem for file storage"""
import json
from typing import TYPE_CHECKING

from .utils import MODEL_SONNET, MODEL_OPUS, with_retry

if TYPE_CHECKING:
    from .base import Generator


class CodeProjectMixin:
    """Mixin for generating full code projects (Python, Node, etc.)"""

    def get_code_file_tools(self: "Generator"):
        """Define file tools for code project generation"""
        return [
            {
                "name": "list_files",
                "description": "List all files in the project with their paths and types",
                "input_schema": {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
            },
            {
                "name": "read_file",
                "description": "Read the content of a file",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "File path (e.g., 'src/main.py', 'package.json')"
                        }
                    },
                    "required": ["path"]
                }
            },
            {
                "name": "write_file",
                "description": "Create or update a file with content",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "File path (e.g., 'src/app.py', 'templates/index.html')"
                        },
                        "content": {
                            "type": "string",
                            "description": "Complete file content"
                        }
                    },
                    "required": ["path", "content"]
                }
            },
            {
                "name": "delete_file",
                "description": "Delete a file from the project",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "File path to delete"
                        }
                    },
                    "required": ["path"]
                }
            },
            {
                "name": "search_files",
                "description": "Search for files containing a string",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search query"
                        }
                    },
                    "required": ["query"]
                }
            }
        ]

        # Sandbox-only tools (available when running in Daytona)
        if hasattr(self.fs, "exec_command"):
            tools.append({
                "name": "exec_command",
                "description": "Execute a shell command in the sandbox environment (e.g. pip install, npm install, docker-compose up, python main.py, cat file). Use for installing dependencies, building, running tests, starting servers.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "Shell command to execute"
                        },
                        "cwd": {
                            "type": "string",
                            "description": "Working directory (default: /workspace)",
                            "default": "/workspace"
                        }
                    },
                    "required": ["command"]
                }
            })
            tools.append({
                "name": "get_preview_url",
                "description": "Get a public URL to preview the running application. Call after starting a server on a port.",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "port": {
                            "type": "integer",
                            "description": "Port the server is running on (e.g. 3000, 5000, 8000)"
                        }
                    },
                    "required": ["port"]
                }
            })

        return tools

    def execute_code_file_tool(self: "Generator", tool_name: str, tool_input: dict) -> str:
        """Execute a file tool using filesystem storage"""
        print(f"[CODE_TOOL] Executing {tool_name} with input: {tool_input}", flush=True)

        if tool_name == "list_files":
            # List all files in src directory
            files = self.fs.list_files("src")
            return json.dumps({
                "files": files,
                "total": len(files)
            })

        elif tool_name == "read_file":
            path = tool_input.get("path", "")
            content = self.fs.read_file(path)
            if content is not None:
                return json.dumps({
                    "path": path,
                    "content": content
                })
            else:
                return json.dumps({"error": f"File '{path}' not found"})

        elif tool_name == "write_file":
            path = tool_input.get("path", "")
            content = tool_input.get("content", "")
            result = self.fs.write_file(path, content)
            self.log("code", f"Wrote {path}")
            return json.dumps({"status": "created", "path": path, "size": result["size"]})

        elif tool_name == "delete_file":
            path = tool_input.get("path", "")
            success = self.fs.delete_file(path)
            if success:
                self.log("code", f"Deleted {path}")
                return json.dumps({"status": "deleted", "path": path})
            else:
                return json.dumps({"error": f"File '{path}' not found"})

        elif tool_name == "search_files":
            # Search not implemented in filesystem service yet
            return json.dumps({
                "query": tool_input.get("query", ""),
                "matches": [],
                "count": 0,
                "note": "Search not yet implemented"
            })

        elif tool_name == "exec_command":
            command = tool_input.get("command", "")
            cwd = tool_input.get("cwd", "/workspace")
            if hasattr(self.fs, "exec_command"):
                result = self.fs.exec_command(command, cwd=cwd)
                self.log("code", f"Exec: {command} (exit={result['exit_code']})")
                return json.dumps({
                    "exit_code": result["exit_code"],
                    "stdout": result["stdout"][:5000],  # truncate long output
                })
            return json.dumps({"error": "Command execution not available (no sandbox)"})

        elif tool_name == "get_preview_url":
            port = tool_input.get("port", 8000)
            if hasattr(self.fs, "get_preview_url"):
                url = self.fs.get_preview_url(port=port)
                self.project.sandbox_preview_url = url
                self.db.commit()
                self.log("code", f"Preview URL: {url}")
                return json.dumps({"preview_url": url, "port": port})
            return json.dumps({"error": "Preview not available (no sandbox)"})

        return json.dumps({"error": f"Unknown tool: {tool_name}"})

    def generate_code_project(self: "Generator", project_type: str = "python") -> dict:
        """
        Generate a complete code project based on the brief.

        Args:
            project_type: Type of project (python, node, react, flask, fastapi, etc.)

        Returns:
            dict with created files and summary
        """
        self.log("code", f"Starting {project_type} project generation...")

        # Get moodboard info for context (if exists)
        context = f"Project Brief: {self.project.brief}\n"
        context += f"Project Type: {project_type}\n"

        if self.project.moodboard:
            moodboard = self.project.moodboard
            if isinstance(moodboard, dict) and moodboard.get("moodboards"):
                mb = moodboard["moodboards"][0]
                context += f"\nDesign (if applicable):\n"
                context += f"- Colors: {', '.join(mb.get('palette', []))}\n"
                context += f"- Style: {mb.get('rationale', '')}\n"

        system_prompt = f"""You are an expert software developer. Create a complete, production-ready {project_type} project.

{context}

You have tools to:
- list_files: See all files in the project
- read_file: Read a file's content
- write_file: Create or update files
- delete_file: Remove files
- search_files: Search in file contents

REQUIREMENTS:
1. Create a well-structured project with proper organization
2. Include all necessary files (main code, config, dependencies, README)
3. Follow best practices for {project_type} projects
4. Make the code production-ready with proper error handling
5. Include comments explaining key parts

PROJECT STRUCTURE EXAMPLES:

Python/Flask:
- app.py (main application)
- requirements.txt
- templates/ (HTML templates)
- static/ (CSS, JS)
- README.md

Python/FastAPI:
- main.py
- requirements.txt
- routers/ (API routes)
- models/ (Pydantic models)
- README.md

Node/Express:
- package.json
- src/index.js
- src/routes/
- README.md

React:
- package.json
- src/App.jsx
- src/components/
- src/styles/
- README.md

Create the complete project now. Start by writing the core files."""

        messages = [
            {"role": "user", "content": f"Create a complete {project_type} project based on the brief. Include all necessary files."}
        ]

        # Agentic loop
        max_iterations = 20
        created_files = []
        final_response = ""

        for i in range(max_iterations):
            print(f"[CODE_PROJECT] Iteration {i+1}", flush=True)

            def make_request():
                return self.client.messages.create(
                    model=MODEL_OPUS,  # Use Opus for code generation quality
                    max_tokens=16000,
                    system=system_prompt,
                    tools=self.get_code_file_tools(),
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
                print(f"[CODE_PROJECT] Done - no more tool calls", flush=True)
                break

            # Execute tool calls
            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for tool_call in tool_calls:
                result = self.execute_code_file_tool(tool_call.name, tool_call.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_call.id,
                    "content": result
                })

                # Track created files
                if tool_call.name == "write_file":
                    path = tool_call.input.get("path", "")
                    if path and path not in created_files:
                        created_files.append(path)
                        print(f"[CODE_PROJECT] Created: {path}", flush=True)

            messages.append({"role": "user", "content": tool_results})

            if response.stop_reason == "end_turn":
                final_response = text_content
                break

        self.log("code", f"Project generation complete: {len(created_files)} files")

        return {
            "files_created": created_files,
            "summary": final_response,
            "total_files": len(created_files),
            "project_type": project_type
        }

    def edit_code_project(self: "Generator", instruction: str) -> str:
        """
        Edit an existing code project based on instruction.
        Uses agentic loop with file tools.
        """
        files = self.get_files_service()
        self.log("code", f"Editing project: {instruction[:50]}...")

        # Get current project state
        file_list = files.list_files()
        file_paths = [f["path"] for f in file_list]

        system_prompt = f"""You are an expert software developer editing an existing project.

Project Files: {', '.join(file_paths) if file_paths else 'Empty project'}

You have tools to:
- list_files: See all files in the project
- read_file: Read a file's content
- write_file: Create or update files
- delete_file: Remove files
- search_files: Search in file contents

Complete the user's request. Read relevant files first to understand the codebase, then make necessary changes."""

        messages = [
            {"role": "user", "content": instruction}
        ]

        max_iterations = 15
        final_response = ""

        for i in range(max_iterations):
            print(f"[CODE_EDIT] Iteration {i+1}", flush=True)

            def make_request():
                return self.client.messages.create(
                    model=MODEL_SONNET,  # Sonnet for faster edits
                    max_tokens=8000,
                    system=system_prompt,
                    tools=self.get_code_file_tools(),
                    messages=messages
                )

            response = with_retry(make_request)
            self.track_usage(response)

            tool_calls = []
            text_content = ""

            for block in response.content:
                if block.type == "text":
                    text_content += block.text
                elif block.type == "tool_use":
                    tool_calls.append(block)

            if not tool_calls:
                final_response = text_content
                break

            messages.append({"role": "assistant", "content": response.content})

            tool_results = []
            for tool_call in tool_calls:
                result = self.execute_code_file_tool(tool_call.name, tool_call.input)
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": tool_call.id,
                    "content": result
                })

            messages.append({"role": "user", "content": tool_results})

            if response.stop_reason == "end_turn":
                final_response = text_content
                break

        self.log("code", "Edit complete")
        return final_response
