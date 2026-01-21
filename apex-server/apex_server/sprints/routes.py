"""Sprint routes"""
import uuid
from typing import List, Optional
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel

from apex_server.config import get_settings
from apex_server.shared.database import get_db
from apex_server.shared.dependencies import get_current_user
from apex_server.shared.tools import list_files, read_file
from apex_server.auth.models import User
from .models import SprintStatus
from .service import SprintService, SprintRunner

router = APIRouter(prefix="/sprints", tags=["sprints"])
settings = get_settings()


# Request/Response models
class CreateSprintRequest(BaseModel):
    task: str


class SprintResponse(BaseModel):
    id: str
    task: str
    status: str
    project_dir: str
    github_repo: Optional[str]
    created_at: str
    started_at: Optional[str]
    completed_at: Optional[str]
    error_message: Optional[str]

    class Config:
        from_attributes = True


class SprintListResponse(BaseModel):
    sprints: List[SprintResponse]


class SprintFilesResponse(BaseModel):
    files: str


class SprintFileResponse(BaseModel):
    path: str
    content: str


# Helper to convert Sprint to response
def sprint_to_response(sprint) -> SprintResponse:
    return SprintResponse(
        id=str(sprint.id),
        task=sprint.task,
        status=sprint.status.value,
        project_dir=sprint.project_dir,
        github_repo=sprint.github_repo,
        created_at=sprint.created_at.isoformat(),
        started_at=sprint.started_at.isoformat() if sprint.started_at else None,
        completed_at=sprint.completed_at.isoformat() if sprint.completed_at else None,
        error_message=sprint.error_message
    )


# Background task runner
def run_sprint_background(sprint_id: uuid.UUID, db_url: str):
    """Run sprint in background"""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    engine = create_engine(db_url)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    try:
        service = SprintService(db)
        # Need to get tenant_id somehow - for now just query without tenant filter
        sprint = db.query(SprintService).filter_by(id=sprint_id).first()
        if sprint:
            runner = SprintRunner(sprint, db)
            runner.run()
    finally:
        db.close()


@router.post("", response_model=SprintResponse)
def create_sprint(
    request: CreateSprintRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create and start a new sprint"""
    service = SprintService(db)

    sprint = service.create(
        task=request.task,
        tenant_id=current_user.tenant_id,
        created_by_id=current_user.id
    )

    # Run sprint in background
    # For now, run synchronously for simplicity
    runner = SprintRunner(sprint, db)
    result = runner.run()

    # Refresh to get updated status
    db.refresh(sprint)

    return sprint_to_response(sprint)


@router.get("", response_model=SprintListResponse)
def list_sprints(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List all sprints for current tenant"""
    service = SprintService(db)
    sprints = service.list_by_tenant(current_user.tenant_id)
    return SprintListResponse(sprints=[sprint_to_response(s) for s in sprints])


@router.get("/{sprint_id}", response_model=SprintResponse)
def get_sprint(
    sprint_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific sprint"""
    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    return sprint_to_response(sprint)


@router.post("/{sprint_id}/cancel")
def cancel_sprint(
    sprint_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Cancel a sprint"""
    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    if not service.cancel(sprint):
        raise HTTPException(status_code=400, detail="Cannot cancel sprint in current state")

    return {"status": "cancelled"}


@router.get("/{sprint_id}/files", response_model=SprintFilesResponse)
def get_sprint_files(
    sprint_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List files in sprint directory"""
    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    files = list_files(Path(sprint.project_dir))
    return SprintFilesResponse(files=files)


@router.get("/{sprint_id}/files/{path:path}", response_model=SprintFileResponse)
def get_sprint_file(
    sprint_id: uuid.UUID,
    path: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Read a file from sprint directory"""
    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    content = read_file(Path(sprint.project_dir), path)

    if content.startswith("Error:"):
        raise HTTPException(status_code=404, detail=content)

    return SprintFileResponse(path=path, content=content)
