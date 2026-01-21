"""Sprint service"""
import uuid
import json
from datetime import datetime
from pathlib import Path
from typing import Optional, List

from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from apex_server.shared.tools import TOOL_DEFINITIONS, execute_tool
from .models import Sprint, SprintStatus

settings = get_settings()


class SprintService:
    """Service for sprint operations"""

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


class SprintRunner:
    """Runs a sprint with multi-agent coordination"""

    def __init__(self, sprint: Sprint, db: Session):
        self.sprint = sprint
        self.db = db
        self.project_dir = Path(sprint.project_dir)
        self.client = Anthropic(api_key=settings.anthropic_api_key)
        self.logs = []

    def log(self, message: str):
        """Add to sprint log"""
        self.logs.append(message)
        print(f"[Sprint {self.sprint.id}] {message}")

    def run_worker(self, worker_name: str, prompt: str, task: str, max_iterations: int = 10) -> dict:
        """Run a single worker"""
        messages = [{"role": "user", "content": task}]

        for i in range(max_iterations):
            self.log(f"--- {worker_name.upper()} Iteration {i+1} ---")

            response = self.client.messages.create(
                model="claude-opus-4-20250514",
                max_tokens=4096,
                system=prompt,
                tools=TOOL_DEFINITIONS,
                messages=messages
            )

            assistant_content = []
            has_tool_use = False
            final_text = ""

            for block in response.content:
                if block.type == "text":
                    self.log(f"{worker_name.upper()}: {block.text[:200]}...")
                    final_text = block.text
                    assistant_content.append(block)

                elif block.type == "tool_use":
                    has_tool_use = True
                    tool_name = block.name
                    tool_args = block.input
                    tool_id = block.id

                    self.log(f"TOOL: {tool_name}({json.dumps(tool_args)[:100]})")

                    result = execute_tool(self.project_dir, tool_name, tool_args)
                    self.log(f"RESULT: {result[:200]}")

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

        return {"worker": worker_name, "iterations": i + 1, "final_response": final_text}

    def run(self) -> dict:
        """Run the full sprint"""
        from .workers import WORKER_PROMPTS
        from apex_server.shared.tools import read_file

        service = SprintService(self.db)
        service.update_status(self.sprint, SprintStatus.RUNNING)

        try:
            # Clear old messages
            messages_dir = self.project_dir / "messages"
            if messages_dir.exists():
                for f in messages_dir.glob("*.txt"):
                    f.unlink()

            # Phase 1: Chef planning
            self.log("=" * 50)
            self.log("PHASE 1: CHEF PLANNING")
            self.log("=" * 50)

            chef_result = self.run_worker(
                "chef",
                WORKER_PROMPTS["chef"],
                f"""Uppgift från användaren: {self.sprint.task}

Gör följande:
1. Analysera uppgiften
2. Skicka instruktioner till frontend via send_message("frontend", "instruktioner")
3. Skicka instruktioner till backend via send_message("backend", "instruktioner")
4. Berätta vad du delegerat"""
            )

            # Phase 2: Backend
            self.log("=" * 50)
            self.log("PHASE 2: BACKEND WORKER")
            self.log("=" * 50)

            backend_task = read_file(self.project_dir, "messages/to_backend.txt")
            backend_result = self.run_worker(
                "backend",
                WORKER_PROMPTS["backend"],
                f"""Instruktioner från Chef:\n\n{backend_task}\n\nUtför uppgiften och svara Chef via send_message."""
            )

            # Phase 3: Frontend
            self.log("=" * 50)
            self.log("PHASE 3: FRONTEND WORKER")
            self.log("=" * 50)

            frontend_task = read_file(self.project_dir, "messages/to_frontend.txt")
            frontend_result = self.run_worker(
                "frontend",
                WORKER_PROMPTS["frontend"],
                f"""Instruktioner från Chef:\n\n{frontend_task}\n\nUtför uppgiften och svara Chef via send_message."""
            )

            # Phase 4: Chef summary
            self.log("=" * 50)
            self.log("PHASE 4: CHEF SUMMARY")
            self.log("=" * 50)

            chef_messages = read_file(self.project_dir, "messages/to_chef.txt")
            summary_result = self.run_worker(
                "chef",
                WORKER_PROMPTS["chef"],
                f"""Workers har rapporterat:\n\n{chef_messages}\n\nLäs filerna och ge en sammanfattning.""",
                max_iterations=5
            )

            service.update_status(self.sprint, SprintStatus.COMPLETED)

            return {
                "status": "completed",
                "logs": self.logs,
                "summary": summary_result.get("final_response", "")
            }

        except Exception as e:
            service.update_status(self.sprint, SprintStatus.FAILED, str(e))
            return {
                "status": "failed",
                "error": str(e),
                "logs": self.logs
            }
