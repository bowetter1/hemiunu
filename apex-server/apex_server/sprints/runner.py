"""Sprint runner - orchestrates multi-agent execution"""
import json
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

from sqlalchemy.orm import Session

from apex_server.config import get_settings
from apex_server.llm import LLMClient
from apex_server.workers import (
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
from .models import Sprint, SprintStatus, LogEntry, LogType, Question, QuestionStatus
from .websocket import sprint_ws_manager


class SprintCancelledException(Exception):
    """Raised when a sprint is cancelled by the user"""
    pass


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
        self._db_lock = threading.Lock()  # Thread-safe logging
        self._total_input_tokens = 0
        self._total_output_tokens = 0
        self._total_cost_usd = 0.0

    def track_tokens(self, ai_type: str, input_tokens: int, output_tokens: int, db: Session = None):
        """Track token usage and cost (thread-safe) and broadcast via WebSocket"""
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

        # Broadcast token update via WebSocket
        sprint_ws_manager.broadcast_sync(
            str(self.sprint.id),
            "tokens",
            {
                "input_tokens": self._total_input_tokens,
                "output_tokens": self._total_output_tokens,
                "cost_usd": self._total_cost_usd
            }
        )

    def log(self, log_type: LogType, message: str, worker: str = None, data: dict = None, db: Session = None):
        """Add structured log entry (thread-safe) and broadcast via WebSocket"""
        from datetime import datetime

        timestamp = datetime.utcnow()
        entry = LogEntry(
            sprint_id=self.sprint.id,
            log_type=log_type,
            worker=worker,
            message=message,
            data=json.dumps(data) if data else None,
            timestamp=timestamp
        )
        # Use provided db session or fall back to self.db with lock
        if db:
            db.add(entry)
            db.commit()
            db.refresh(entry)
        else:
            with self._db_lock:
                self.db.add(entry)
                self.db.commit()
                self.db.refresh(entry)

        print(f"[{self.sprint.id}] [{log_type.value}] {worker or ''}: {message}")

        # Broadcast via WebSocket
        sprint_ws_manager.broadcast_sync(
            str(self.sprint.id),
            "log",
            {
                "id": entry.id,
                "timestamp": timestamp.isoformat(),
                "log_type": log_type.value,
                "worker": worker,
                "message": message,
                "data": data
            }
        )

    def _get_worker_icon(self, worker: str) -> str:
        """Get emoji icon for worker"""
        return ROLE_ICONS.get(worker, "👤")

    def _is_cancelled(self, db: Session = None) -> bool:
        """Check if sprint has been cancelled (thread-safe DB check)"""
        target_db = db or self.db
        with self._db_lock:
            target_db.refresh(self.sprint)
            return self.sprint.status == SprintStatus.CANCELLED

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
        ai_type = get_worker_ai(worker_name, team=self.sprint.team)
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
            # Check if sprint was cancelled
            if self._is_cancelled(db):
                self.log(LogType.INFO, "Sprint avbruten av användaren", log_worker, db=db)
                raise SprintCancelledException("Sprint cancelled by user")

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
            elif provider == "groq":
                response = self.llm.call_groq(model_id, system_prompt, messages, tools)
                # Convert Groq (OpenAI format) response to Anthropic-like structure
                content_blocks = LLMClient.parse_groq_response(response)
                stop_reason = "end_turn" if not any(b.get("type") == "tool_use" for b in content_blocks) else "tool_use"
                # Track Groq tokens
                if "usage" in response:
                    self.track_tokens(
                        ai_type,
                        response["usage"].get("prompt_tokens", 0),
                        response["usage"].get("completion_tokens", 0),
                        db=db
                    )
            else:  # google
                response = self.llm.call_gemini(system_prompt, messages, tools)
                # Convert Gemini response to Anthropic-like structure
                content_blocks = LLMClient.parse_gemini_response(response)
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

                    # Handle special tools
                    if tool_name in DELEGATION_TOOLS:
                        result = self._handle_delegation(tool_name, tool_args)
                    elif tool_name == "ask_user":
                        result = self._handle_ask_user(tool_args, db)
                    else:
                        result = execute_tool(self.project_dir, tool_name, tool_args)

                    # Check if GitHub repo was created - save URL to sprint
                    if tool_name == "github_create_repo" and "URL:" in result:
                        self._save_github_url(result, db)

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

    def _handle_ask_user(self, args: dict, db: Session = None) -> str:
        """Handle ask_user tool - create question and wait for answer"""
        import time

        question_text = args.get("question", "")
        options = args.get("options", [])

        # Create question in database
        target_db = db or self.db
        question = Question(
            sprint_id=self.sprint.id,
            question=question_text,
            options=json.dumps(options) if options else None,
            status=QuestionStatus.PENDING
        )

        with self._db_lock:
            target_db.add(question)
            target_db.commit()
            target_db.refresh(question)

        question_id = question.id

        # Log that we're waiting for user input
        self.log(
            LogType.QUESTION,
            f"Chef fragar: {question_text}",
            "chef",
            {"question_id": question_id, "options": options},
            db=db
        )

        # Poll for answer (max 5 minutes)
        max_wait = 300  # 5 minutes
        poll_interval = 1  # 1 second
        waited = 0

        while waited < max_wait:
            time.sleep(poll_interval)
            waited += poll_interval

            # Refresh question from database
            with self._db_lock:
                target_db.refresh(question)

            if question.status == QuestionStatus.ANSWERED:
                answer = question.answer or ""
                self.log(
                    LogType.ANSWER,
                    f"Anvandaren svarade: {answer}",
                    "chef",
                    {"question_id": question_id, "answer": answer},
                    db=db
                )
                return f"Användaren svarade: {answer}"

            if question.status == QuestionStatus.CANCELLED:
                return "Frågan avbröts av användaren."

        # Timeout
        with self._db_lock:
            question.status = QuestionStatus.CANCELLED
            target_db.commit()

        return "Timeout: Användaren svarade inte inom 5 minuter."

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

        if tool_name in ["talk_to", "reassign_with_feedback", "checkin_worker"]:
            worker = args.get("worker", "backend")
            # Support both "message" (talk_to) and "question" (checkin_worker)
            message = args.get("message", args.get("question", args.get("task", "")))
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

    def _save_github_url(self, result: str, db: Session = None):
        """Extract and save GitHub URL from tool result"""
        import re
        match = re.search(r'URL:\s*(https://github\.com/[^\s\n]+)', result)
        if match:
            github_url = match.group(1)
            target_db = db or self.db
            with self._db_lock:
                self.sprint.github_repo = github_url
                target_db.commit()
            self.log(LogType.INFO, f"GitHub repo: {github_url}", "devops", db=db)

    def _broadcast_status(self, status: str):
        """Broadcast sprint status change via WebSocket"""
        sprint_ws_manager.broadcast_sync(
            str(self.sprint.id),
            "status",
            {
                "status": status,
                "input_tokens": self._total_input_tokens,
                "output_tokens": self._total_output_tokens,
                "cost_usd": self._total_cost_usd
            }
        )

    def run(self) -> dict:
        """Run the full sprint with Chef orchestration"""
        from .service import SprintService

        service = SprintService(self.db)
        service.update_status(self.sprint, SprintStatus.RUNNING)
        self._broadcast_status("running")

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
            self._broadcast_status("completed")
            self.log(LogType.SUCCESS, "SPRINT KLAR!", None)

            return {
                "status": "completed",
                "summary": chef_result.get("final_response", "")
            }

        except SprintCancelledException:
            # Sprint was cancelled by user - status already set to CANCELLED
            self._broadcast_status("cancelled")
            self.log(LogType.INFO, "Sprint avbruten", None)
            return {
                "status": "cancelled",
                "summary": "Sprint avbruten av användaren"
            }

        except Exception as e:
            self.log(LogType.ERROR, f"Sprint misslyckades: {str(e)}", None)
            service.update_status(self.sprint, SprintStatus.FAILED, str(e))
            self._broadcast_status("failed")
            return {
                "status": "failed",
                "error": str(e)
            }
