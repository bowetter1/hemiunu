"""Project routes - API for macOS app"""
import uuid
import asyncio
import threading
from typing import List, Optional
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from pydantic import BaseModel

from apex_server.config import get_settings
from apex_server.shared.database import get_db
from apex_server.shared.dependencies import get_current_user
from apex_server.auth.models import User
from .models import Project, Page, ProjectLog, ProjectStatus
from .generator import Generator
from .websocket import manager, notify_moodboard_ready, notify_layouts_ready, notify_error

router = APIRouter(prefix="/projects", tags=["projects"])
settings = get_settings()

# Event loop for async notifications from sync code
_loop = None

def get_event_loop():
    global _loop
    if _loop is None:
        try:
            _loop = asyncio.get_running_loop()
        except RuntimeError:
            _loop = asyncio.new_event_loop()
    return _loop


# === WebSocket Endpoint ===

@router.websocket("/{project_id}/ws")
async def websocket_endpoint(websocket: WebSocket, project_id: uuid.UUID):
    """WebSocket connection for real-time project updates"""
    await manager.connect(websocket, str(project_id))
    try:
        while True:
            # Keep connection alive, wait for messages (ping/pong)
            data = await websocket.receive_text()
            # Echo back for ping/pong
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket, str(project_id))


# === Request/Response Models ===

class CreateProjectRequest(BaseModel):
    brief: str


class ProjectResponse(BaseModel):
    id: str
    brief: str
    status: str
    moodboard: Optional[dict] = None
    selected_moodboard: Optional[int] = None
    selected_layout: Optional[int] = None
    created_at: str
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    error_message: Optional[str] = None

    class Config:
        from_attributes = True


class PageResponse(BaseModel):
    id: str
    name: str
    html: str
    layout_variant: Optional[int] = None

    class Config:
        from_attributes = True


class LogResponse(BaseModel):
    id: int
    phase: str
    message: str
    data: Optional[dict] = None
    timestamp: str

    class Config:
        from_attributes = True


class EditPageRequest(BaseModel):
    instruction: str


class AddPageRequest(BaseModel):
    name: str
    description: Optional[str] = None


class SelectMoodboardRequest(BaseModel):
    variant: int  # 1, 2, or 3


class SelectLayoutRequest(BaseModel):
    variant: int  # 1, 2, or 3


# === Helper Functions ===

def project_to_response(project: Project) -> ProjectResponse:
    return ProjectResponse(
        id=str(project.id),
        brief=project.brief,
        status=project.status.value,
        moodboard=project.moodboard,
        selected_moodboard=project.selected_moodboard,
        selected_layout=project.selected_layout,
        created_at=project.created_at.isoformat(),
        input_tokens=project.input_tokens,
        output_tokens=project.output_tokens,
        cost_usd=project.cost_usd,
        error_message=project.error_message
    )


def run_in_background(func, *args):
    """Run a function in a background thread"""
    thread = threading.Thread(target=func, args=args, daemon=True)
    thread.start()


# === Routes ===

@router.post("", response_model=ProjectResponse)
def create_project(
    request: CreateProjectRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new project and start moodboard generation"""
    project_id = uuid.uuid4()
    project_dir = str(Path(settings.storage_path) / str(project_id))

    project = Project(
        id=project_id,
        brief=request.brief,
        project_dir=project_dir,
        user_id=current_user.id
    )
    db.add(project)
    db.commit()
    db.refresh(project)

    # Create directory
    Path(project_dir).mkdir(parents=True, exist_ok=True)

    # Start moodboard generation in background
    def generate_moodboard_bg(project_id: uuid.UUID):
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker
        db_url = str(settings.database_url)
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)
        engine = create_engine(db_url)
        SessionLocal = sessionmaker(bind=engine)
        db = SessionLocal()
        try:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                gen = Generator(project, db)
                moodboards = gen.generate_moodboard()
                # Send WebSocket notification
                asyncio.run(notify_moodboard_ready(str(project_id), moodboards))
        except Exception as e:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                asyncio.run(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    run_in_background(generate_moodboard_bg, project.id)

    return project_to_response(project)


@router.get("", response_model=List[ProjectResponse])
def list_projects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """List user's projects"""
    projects = db.query(Project).filter(
        Project.user_id == current_user.id
    ).order_by(Project.created_at.desc()).limit(20).all()

    return [project_to_response(p) for p in projects]


@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    return project_to_response(project)


@router.delete("/{project_id}")
def delete_project(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a project and all its data"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # Delete related data
    db.query(Page).filter(Page.project_id == project_id).delete()
    db.query(ProjectLog).filter(ProjectLog.project_id == project_id).delete()
    db.delete(project)
    db.commit()

    return {"status": "deleted", "id": str(project_id)}


@router.post("/{project_id}/select-moodboard", response_model=ProjectResponse)
def select_moodboard(
    project_id: uuid.UUID,
    request: SelectMoodboardRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Select a moodboard variant (1, 2, or 3) and start layout generation"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if project.status != ProjectStatus.MOODBOARD:
        raise HTTPException(status_code=400, detail="Project must be in moodboard phase")

    # Validate variant
    moodboards = project.moodboard.get("moodboards", []) if project.moodboard else []
    if request.variant < 1 or request.variant > len(moodboards):
        raise HTTPException(status_code=400, detail=f"Invalid moodboard variant. Must be 1-{len(moodboards)}")

    # Save selected moodboard
    project.selected_moodboard = request.variant
    db.commit()

    # Generate layouts in background
    def generate_layouts_bg(project_id: uuid.UUID):
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker
        db_url = str(settings.database_url)
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)
        engine = create_engine(db_url)
        SessionLocal = sessionmaker(bind=engine)
        db = SessionLocal()
        try:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                gen = Generator(project, db)
                layouts = gen.generate_layouts()
                # Send WebSocket notification
                asyncio.run(notify_layouts_ready(str(project_id), layouts))
        except Exception as e:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                asyncio.run(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    run_in_background(generate_layouts_bg, project.id)

    return project_to_response(project)


@router.post("/{project_id}/generate-layouts", response_model=ProjectResponse)
def generate_layouts(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Generate 3 layout alternatives (after moodboard is selected)"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if project.status != ProjectStatus.MOODBOARD:
        raise HTTPException(status_code=400, detail="Project must be in moodboard phase")

    if not project.selected_moodboard:
        raise HTTPException(status_code=400, detail="Must select a moodboard first")

    # Generate in background
    def generate_layouts_bg(project_id: uuid.UUID):
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker
        db_url = str(settings.database_url)
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)
        engine = create_engine(db_url)
        SessionLocal = sessionmaker(bind=engine)
        db = SessionLocal()
        try:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                gen = Generator(project, db)
                layouts = gen.generate_layouts()
                asyncio.run(notify_layouts_ready(str(project_id), layouts))
        except Exception as e:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                asyncio.run(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    run_in_background(generate_layouts_bg, project.id)

    return project_to_response(project)


@router.post("/{project_id}/select-layout", response_model=ProjectResponse)
def select_layout(
    project_id: uuid.UUID,
    request: SelectLayoutRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Select a layout variant (1, 2, or 3)"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if project.status != ProjectStatus.LAYOUTS:
        raise HTTPException(status_code=400, detail="Project must be in layouts phase")

    gen = Generator(project, db)
    gen.select_layout(request.variant)

    return project_to_response(project)


@router.get("/{project_id}/pages", response_model=List[PageResponse])
def get_pages(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all pages for a project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    pages = db.query(Page).filter(Page.project_id == project_id).all()

    return [PageResponse(
        id=str(p.id),
        name=p.name,
        html=p.html,
        layout_variant=p.layout_variant
    ) for p in pages]


@router.get("/{project_id}/pages/{page_id}", response_model=PageResponse)
def get_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific page"""
    page = db.query(Page).filter(
        Page.id == page_id,
        Page.project_id == project_id
    ).first()

    if not page:
        raise HTTPException(status_code=404, detail="Page not found")

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=page.html,
        layout_variant=page.layout_variant
    )


@router.post("/{project_id}/pages/{page_id}/edit", response_model=PageResponse)
def edit_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: EditPageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Edit a page with an instruction"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    gen = Generator(project, db)
    html = gen.edit_page(str(page_id), request.instruction)

    page = db.query(Page).filter(Page.id == page_id).first()
    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=html,
        layout_variant=page.layout_variant
    )


@router.post("/{project_id}/pages", response_model=PageResponse)
def add_page(
    project_id: uuid.UUID,
    request: AddPageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a new page to the project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    gen = Generator(project, db)
    page = gen.add_page(request.name, request.description)

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=page.html,
        layout_variant=page.layout_variant
    )


@router.get("/{project_id}/logs", response_model=List[LogResponse])
def get_logs(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get project logs"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    logs = db.query(ProjectLog).filter(
        ProjectLog.project_id == project_id
    ).order_by(ProjectLog.timestamp.desc()).limit(50).all()

    return [LogResponse(
        id=l.id,
        phase=l.phase,
        message=l.message,
        data=l.data,
        timestamp=l.timestamp.isoformat()
    ) for l in logs]
