"""Sprint service with multi-agent orchestration"""
import uuid
import json
import asyncio
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Any
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy.orm import Session
from anthropic import Anthropic
# TODO: Aktivera när GOOGLE_API_KEY är konfigurerad
# import google.generativeai as genai

from apex_server.config import get_settings
from apex_server.workers import (
    TOOL_DEFINITIONS,
    DELEGATION_TOOLS,
    ROLE_ICONS,
    ROLE_NAMES,
    get_worker_ai,
    get_model_id,
    get_provider,
    get_chef_prompt,
    get_worker_prompt,
    get_tools_for_worker,
    execute_tool,
)
from .models import Sprint, SprintStatus, LogEntry, LogType

settings = get_settings()


class SprintService:
    """Service for sprint CRUD operations"""

    def __init__(self, db: Session):
        self.db = db
        self.storage = Path(settings.storage_path)

    def create(self, task: str, tenant_id: uuid.UUID, created_by_id: uuid.UUID) -> Sprint:
        """Create a new sprint"""
        sprint_id = uuid.uuid4()
        project_dir = str(self.storage / str(sprint_id))

        sprint = Sprint(
            id=sprint_id,
            task=task,
            tenant_id=tenant_id,
            created_by_id=created_by_id,
            project_dir=project_dir
        )
        self.db.add(sprint)
        self.db.commit()
        self.db.refresh(sprint)

        # Create project directory
        Path(project_dir).mkdir(parents=True, exist_ok=True)

        return sprint

    def get_by_id(self, sprint_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[Sprint]:
        """Get sprint by ID (scoped to tenant)"""
        return self.db.query(Sprint).filter(
            Sprint.id == sprint_id,
            Sprint.tenant_id == tenant_id
        ).first()

    def list_by_tenant(self, tenant_id: uuid.UUID, limit: int = 50) -> List[Sprint]:
        """List sprints for a tenant"""
        return self.db.query(Sprint).filter(
            Sprint.tenant_id == tenant_id
        ).order_by(Sprint.created_at.desc()).limit(limit).all()

    def update_status(self, sprint: Sprint, status: SprintStatus, error: str = None):
        """Update sprint status"""
        sprint.status = status
        if status == SprintStatus.RUNNING:
            sprint.started_at = datetime.utcnow()
        elif status in [SprintStatus.COMPLETED, SprintStatus.FAILED]:
            sprint.completed_at = datetime.utcnow()
        if error:
            sprint.error_message = error
        self.db.commit()

    def cancel(self, sprint: Sprint) -> bool:
        """Cancel a sprint"""
        if sprint.status in [SprintStatus.PENDING, SprintStatus.RUNNING]:
            self.update_status(sprint, SprintStatus.CANCELLED)
            return True
        return False


class LLMClient:
    """Unified LLM client supporting Anthropic (and Google when enabled)"""

    def __init__(self):
        self.anthropic = Anthropic(api_key=settings.anthropic_api_key) if settings.anthropic_api_key else None
        self.gemini_model = None  # TODO: Aktivera Gemini senare

        # TODO: Aktivera när GOOGLE_API_KEY är konfigurerad
        # if settings.google_api_key:
        #     genai.configure(api_key=settings.google_api_key)
        #     self.gemini_model = genai.GenerativeModel('gemini-2.0-flash-exp')

    def call_anthropic(self, model: str, system: str, messages: list, tools: list) -> dict:
        """Call Anthropic API"""
        if not self.anthropic:
            raise ValueError("Anthropic API key not configured")

        response = self.anthropic.messages.create(
            model=model,
            max_tokens=4096,
            system=system,
            tools=tools,
            messages=messages
        )
        return response

    def call_gemini(self, system: str, messages: list, tools: list) -> dict:
        """Call Google Gemini API"""
        if not self.gemini_model:
            raise ValueError("Google API key not configured")

        # Convert Anthropic-style messages to Gemini format
        gemini_messages = []
        for msg in messages:
            role = "user" if msg["role"] == "user" else "model"
            content = msg["content"]

            if isinstance(content, str):
                gemini_messages.append({"role": role, "parts": [content]})
            elif isinstance(content, list):
                # Handle tool results and complex content
                parts = []
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            parts.append(block["text"])
                        elif block.get("type") == "tool_result":
                            parts.append(f"Tool result ({block.get('tool_use_id', '')}): {block.get('content', '')}")
                        elif block.get("type") == "tool_use":
                            parts.append(f"Using tool: {block.get('name', '')} with args: {json.dumps(block.get('input', {}))}")
                    else:
                        parts.append(str(block))
                if parts:
                    gemini_messages.append({"role": role, "parts": parts})

        # Convert tools to Gemini function declarations
        gemini_tools = []
        for tool in tools:
            func_decl = {
                "name": tool["name"],
                "description": tool.get("description", ""),
                "parameters": tool.get("input_schema", {})
            }
            gemini_tools.append(func_decl)

        # Create chat with system instruction
        chat = self.gemini_model.start_chat(history=gemini_messages[:-1] if len(gemini_messages) > 1 else [])

        # Include tools in generation config
        generation_config = genai.GenerationConfig(
            max_output_tokens=4096,
            temperature=0.7,
        )

        # Make the request
        if gemini_tools:
            response = chat.send_message(
                gemini_messages[-1]["parts"] if gemini_messages else [system],
                generation_config=generation_config,
                tools=[genai.protos.Tool(function_declarations=gemini_tools)]
            )
        else:
            response = chat.send_message(
                gemini_messages[-1]["parts"] if gemini_messages else [system],
                generation_config=generation_config
            )

        return response


class SprintRunner:
    """Runs a sprint with multi-agent orchestration

    Chef orchestrates by using delegation tools:
    - assign_ad, assign_architect, assign_backend, assign_frontend, etc.
    - Each delegation recursively calls run_worker for that role
    """

    def __init__(self, sprint: Sprint, db: Session):
        self.sprint = sprint
        self.db = db
        self.db_url = str(get_settings().database_url)
        self.project_dir = Path(sprint.project_dir)
        self.llm = LLMClient()
        self.worker_sessions: dict[str, list] = {}  # Worker memory
        self._db_lock = __import__('threading').Lock()  # Thread-safe logging
        self._total_input_tokens = 0
        self._total_output_tokens = 0
        self._total_cost_usd = 0.0

    def track_tokens(self, ai_type: str, input_tokens: int, output_tokens: int, db: Session = None):
        """Track token usage and cost (thread-safe)"""
        from apex_server.workers.config import calculate_cost

        cost = calculate_cost(ai_type, input_tokens, output_tokens)

        with self._db_lock:
            self._total_input_tokens += input_tokens
            self._total_output_tokens += output_tokens
            self._total_cost_usd += cost
            # Update sprint in database
            target_db = db or self.db
            self.sprint.input_tokens = self._total_input_tokens
            self.sprint.output_tokens = self._total_output_tokens
            self.sprint.cost_usd = self._total_cost_usd
            target_db.commit()

    def log(self, log_type: LogType, message: str, worker: str = None, data: dict = None, db: Session = None):
        """Add structured log entry (thread-safe)"""
        entry = LogEntry(
            sprint_id=self.sprint.id,
            log_type=log_type,
            worker=worker,
            message=message,
            data=json.dumps(data) if data else None
        )
        # Use provided db session or fall back to self.db with lock
        if db:
            db.add(entry)
            db.commit()
        else:
            with self._db_lock:
                self.db.add(entry)
                self.db.commit()
        print(f"[{self.sprint.id}] [{log_type.value}] {worker or ''}: {message}")

    def _get_worker_icon(self, worker: str) -> str:
        """Get emoji icon for worker"""
        return ROLE_ICONS.get(worker, "👤")

    def _convert_tools_for_api(self, tools: list, provider: str) -> list:
        """Convert tool definitions for the specific API provider"""
        if provider == "anthropic":
            # Anthropic uses input_schema
            return tools
        elif provider == "google":
            # Google uses parameters directly
            return [
                {
                    "name": t["name"],
                    "description": t.get("description", ""),
                    "parameters": t.get("input_schema", {})
                }
                for t in tools
            ]
        return tools

    def run_worker(self, worker_name: str, task: str, max_iterations: int = 20,
                   instance_id: str = None, db: Session = None) -> dict:
        """Run a single worker with tool calling loop

        Args:
            worker_name: Worker role (chef, backend, frontend, etc.)
            task: Task description
            max_iterations: Max API round-trips
            instance_id: Optional instance ID for parallel workers (e.g., "frontend-1")
            db: Optional dedicated database session for this worker

        Returns:
            Dict with worker result
        """
        icon = self._get_worker_icon(worker_name)
        role_name = ROLE_NAMES.get(worker_name, worker_name)
        ai_type = get_worker_ai(worker_name)
        provider = get_provider(ai_type)
        model_id = get_model_id(ai_type)

        # Use instance_id for logging if provided (for parallel workers)
        log_worker = instance_id if instance_id else worker_name

        self.log(LogType.WORKER_START, f"STARTAR {role_name.upper()} ({ai_type})...", log_worker, db=db)

        # Get appropriate prompt
        if worker_name == "chef":
            system_prompt = get_chef_prompt(task, str(self.project_dir))
        else:
            system_prompt = get_worker_prompt(
                worker_name,
                task=task,
                project_dir=str(self.project_dir)
            )

        # Get tools for this worker
        tools = get_tools_for_worker(worker_name)

        # Initialize or restore session
        if worker_name not in self.worker_sessions:
            self.worker_sessions[worker_name] = []

        messages = self.worker_sessions[worker_name].copy()
        messages.append({"role": "user", "content": task})

        final_text = ""

        for i in range(max_iterations):
            # Call appropriate LLM
            if provider == "anthropic":
                response = self.llm.call_anthropic(model_id, system_prompt, messages, tools)
                content_blocks = response.content
                stop_reason = response.stop_reason
                # Track token usage and cost
                if hasattr(response, 'usage'):
                    self.track_tokens(
                        ai_type,
                        response.usage.input_tokens,
                        response.usage.output_tokens,
                        db=db
                    )
            else:  # google
                response = self.llm.call_gemini(system_prompt, messages, tools)
                # Convert Gemini response to Anthropic-like structure
                content_blocks = self._parse_gemini_response(response)
                stop_reason = "end_turn" if not any(b.get("type") == "tool_use" for b in content_blocks) else "tool_use"
                # TODO: Track Gemini tokens when enabled

            assistant_content = []
            has_tool_use = False

            for block in content_blocks:
                if isinstance(block, dict):
                    block_type = block.get("type", "text")
                else:
                    # Anthropic SDK returns objects
                    block_type = getattr(block, "type", "text")

                if block_type == "text":
                    text = block.get("text", "") if isinstance(block, dict) else block.text
                    final_text = text
                    if len(text) < 300:
                        self.log(LogType.THINKING, text, log_worker, db=db)
                    assistant_content.append(block)

                elif block_type == "tool_use":
                    has_tool_use = True

                    if isinstance(block, dict):
                        tool_name = block.get("name", "")
                        tool_args = block.get("input", {})
                        tool_id = block.get("id", f"tool_{i}")
                    else:
                        tool_name = block.name
                        tool_args = block.input
                        tool_id = block.id

                    # Log tool call
                    self.log(
                        LogType.TOOL_CALL,
                        f"{tool_name} anropat",
                        log_worker,
                        {"tool": tool_name, "args": tool_args},
                        db=db
                    )

                    # Handle delegation tools specially
                    if tool_name in DELEGATION_TOOLS:
                        result = self._handle_delegation(tool_name, tool_args)
                    else:
                        result = execute_tool(self.project_dir, tool_name, tool_args)

                    # Log result (abbreviated)
                    result_preview = result[:200] + "..." if len(result) > 200 else result
                    self.log(LogType.TOOL_RESULT, result_preview, log_worker, db=db)

                    assistant_content.append(block)
                    messages.append({"role": "assistant", "content": assistant_content})
                    messages.append({
                        "role": "user",
                        "content": [{"type": "tool_result", "tool_use_id": tool_id, "content": result}]
                    })
                    assistant_content = []

            if not has_tool_use:
                if assistant_content:
                    messages.append({"role": "assistant", "content": assistant_content})
                break

        # Save session for memory
        self.worker_sessions[worker_name] = messages

        self.log(LogType.WORKER_DONE, f"{role_name.upper()} klar ({len(final_text)} tecken)", log_worker, db=db)
        return {"worker": worker_name, "instance_id": instance_id, "iterations": i + 1, "final_response": final_text}

    def _parse_gemini_response(self, response) -> list:
        """Parse Gemini response into Anthropic-like content blocks"""
        blocks = []

        for candidate in response.candidates:
            for part in candidate.content.parts:
                if hasattr(part, 'text') and part.text:
                    blocks.append({"type": "text", "text": part.text})
                elif hasattr(part, 'function_call'):
                    fc = part.function_call
                    blocks.append({
                        "type": "tool_use",
                        "id": f"gemini_{fc.name}",
                        "name": fc.name,
                        "input": dict(fc.args) if fc.args else {}
                    })

        return blocks

    def _handle_delegation(self, tool_name: str, args: dict) -> str:
        """Handle delegation tools by running worker"""
        icon_map = {
            "assign_ad": ("ad", "🎨"),
            "assign_architect": ("architect", "🏗️"),
            "assign_backend": ("backend", "⚙️"),
            "assign_frontend": ("frontend", "🖼️"),
            "assign_tester": ("tester", "🧪"),
            "assign_reviewer": ("reviewer", "🔍"),
            "assign_security": ("security", "🔐"),
            "assign_devops": ("devops", "🚀"),
        }

        if tool_name == "assign_parallel":
            return self._handle_parallel(args)

        if tool_name in ["talk_to", "reassign_with_feedback"]:
            worker = args.get("worker", "backend")
            message = args.get("message", args.get("task", ""))
            feedback = args.get("feedback", "")
            if feedback:
                message = f"Task: {message}\n\nFeedback: {feedback}\n\nMake adjustments!"

            result = self.run_worker(worker, message)
            return f"💬 {ROLE_NAMES.get(worker, worker)}: {result.get('final_response', '')[:500]}"

        if tool_name in icon_map:
            worker, icon = icon_map[tool_name]
            task = args.get("task", "")
            context = args.get("context", "")
            file = args.get("file", "")

            # Build task with context
            full_task = task
            if context:
                full_task += f"\n\nContext: {context}"
            if file:
                full_task += f"\n\nFile: {file}"

            # Special handling for reviewer
            if tool_name == "assign_reviewer":
                files = args.get("files_to_review", [])
                focus = args.get("focus", "")
                full_task = f"Review files: {', '.join(files)}"
                if focus:
                    full_task += f"\n\nFocus: {focus}"

            result = self.run_worker(worker, full_task)
            return f"{icon} {ROLE_NAMES.get(worker, worker)}: {result.get('final_response', '')[:1000]}"

        return f"Unknown delegation tool: {tool_name}"

    def _handle_parallel(self, args: dict) -> str:
        """Handle parallel worker execution with separate DB sessions per thread"""
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker

        assignments = args.get("assignments", [])
        if not assignments:
            return "No assignments given"

        self.log(LogType.PARALLEL_START, f"STARTAR {len(assignments)} PARALLELLA UPPGIFTER...", None)

        results = []

        # Count instances per worker type for unique IDs
        worker_counts: dict[str, int] = {}
        assignment_info = []

        for a in assignments:
            worker = a.get("worker", "backend")
            task = a.get("task", "")
            context = a.get("context", "")
            file = a.get("file", "")

            full_task = task
            if context:
                full_task += f"\n\nContext: {context}"
            if file:
                full_task += f"\n\nFile: {file}"

            # Generate instance ID for multiple workers of same type
            worker_counts[worker] = worker_counts.get(worker, 0) + 1
            count = worker_counts[worker]
            instance_id = worker if count == 1 else f"{worker}-{count}"

            assignment_info.append({
                "worker": worker,
                "instance_id": instance_id,
                "task": full_task
            })

        def run_worker_with_own_session(worker: str, instance_id: str, task: str) -> dict:
            """Run worker with its own database session"""
            engine = create_engine(self.db_url)
            SessionLocal = sessionmaker(bind=engine)
            thread_db = SessionLocal()
            try:
                return self.run_worker(worker, task, instance_id=instance_id, db=thread_db)
            finally:
                thread_db.close()

        # Run workers in parallel using thread pool
        with ThreadPoolExecutor(max_workers=len(assignments)) as executor:
            futures = {}
            for info in assignment_info:
                future = executor.submit(
                    run_worker_with_own_session,
                    info["worker"],
                    info["instance_id"],
                    info["task"]
                )
                futures[future] = info

            for future in futures:
                info = futures[future]
                worker = info["worker"]
                instance_id = info["instance_id"]
                icon = self._get_worker_icon(worker)
                try:
                    result = future.result()
                    response = result.get('final_response', '')[:500]
                    results.append(f"**{instance_id.upper()}**:\n{response}...")
                    # Note: WORKER_DONE is already logged by run_worker
                except Exception as e:
                    results.append(f"**{instance_id.upper()}**: ERROR - {e}")
                    self.log(LogType.ERROR, f"{icon} {instance_id.upper()} ERROR: {e}", instance_id)

        self.log(LogType.PARALLEL_DONE, f"PARALLELLT ARBETE KLART ({len(assignments)} workers)", None)
        return f"⚡ PARALLEL WORK COMPLETE\n\n" + "\n\n---\n\n".join(results)

    def run(self) -> dict:
        """Run the full sprint with Chef orchestration"""
        service = SprintService(self.db)
        service.update_status(self.sprint, SprintStatus.RUNNING)

        self.log(LogType.INFO, f"Sprint startad: {self.sprint.task[:50]}...")

        try:
            # Run Chef - it will orchestrate everything using delegation tools
            self.log(LogType.PHASE, "CHEF ORKESTRERAR SPRINT", "chef")

            chef_result = self.run_worker(
                "chef",
                self.sprint.task,
                max_iterations=50  # Chef needs more iterations for full orchestration
            )

            service.update_status(self.sprint, SprintStatus.COMPLETED)
            self.log(LogType.SUCCESS, "SPRINT KLAR!", None)

            return {
                "status": "completed",
                "summary": chef_result.get("final_response", "")
            }

        except Exception as e:
            self.log(LogType.ERROR, f"Sprint misslyckades: {str(e)}", None)
            service.update_status(self.sprint, SprintStatus.FAILED, str(e))
            return {
                "status": "failed",
                "error": str(e)
            }
