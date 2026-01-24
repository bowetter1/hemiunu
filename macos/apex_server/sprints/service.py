"""Sprint service - CRUD operations for sprints"""
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional, List

from sqlalchemy.orm import Session

from apex_server.config import get_settings
from .models import Sprint, SprintStatus

settings = get_settings()


class SprintService:
    """Service for sprint CRUD operations"""

    def __init__(self, db: Session):
        self.db = db
        self.storage = Path(settings.storage_path)

    def create(self, task: str, tenant_id: uuid.UUID, created_by_id: uuid.UUID, team: str = "a-team") -> Sprint:
        """Create a new sprint"""
        sprint_id = uuid.uuid4()
        project_dir = str(self.storage / str(sprint_id))

        sprint = Sprint(
            id=sprint_id,
            task=task,
            tenant_id=tenant_id,
            created_by_id=created_by_id,
            project_dir=project_dir,
            team=team
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
