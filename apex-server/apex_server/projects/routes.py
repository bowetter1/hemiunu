"""Project routes - API for macOS app"""
import uuid
import asyncio
import threading
from typing import List, Optional
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
import mimetypes
import re

from apex_server.config import get_settings
from apex_server.shared.database import get_db
from apex_server.shared.dependencies import get_current_user
from apex_server.auth.models import User
from .models import Project, Variant, Page, PageVersion, ProjectLog, ProjectStatus
from .generator import Generator
from .websocket import manager, notify_moodboard_ready, notify_layouts_ready, notify_error, notify_clarification_needed
from .structured_edit import generate_structured_edit, StructuredEditResponse
from .filesystem import FileSystemService

router = APIRouter(prefix="/projects", tags=["projects"])
settings = get_settings()

# Event loop for async notifications from sync code
_main_loop = None

def set_main_loop():
    """Store reference to main event loop (call from async context)"""
    global _main_loop
    try:
        _main_loop = asyncio.get_running_loop()
        print("[MAIN LOOP] Stored main event loop reference", flush=True)
    except RuntimeError:
        pass

def notify_from_thread(coro):
    """Run an async notification from a background thread"""
    global _main_loop
    if _main_loop is not None and _main_loop.is_running():
        # Schedule on main loop - this is the correct way!
        future = asyncio.run_coroutine_threadsafe(coro, _main_loop)
        try:
            future.result(timeout=5)  # Wait up to 5 seconds
            print("[WS] Notification sent via main loop", flush=True)
        except Exception as e:
            print(f"[WS] Notification failed: {e}", flush=True)
    else:
        # Fallback: create new loop (won't have connections, but won't crash)
        print("[WS] Warning: No main loop, using asyncio.run()", flush=True)
        asyncio.run(coro)


# === Helper Functions ===

def rewrite_asset_urls(html: str, project_id: str, base_url: str) -> str:
    """
    Normalize image URLs for WebView compatibility.

    The macOS WebView sets baseURL to the assets endpoint, so relative URLs
    like 'images/hero.png' resolve correctly. We just ensure URLs are clean.
    """
    if not html:
        return html

    # Normalize ./images/ to images/ (WebView baseURL handles the rest)
    html = re.sub(r'src=(["\'])\.\/images\/', r'src=\1images/', html)

    return html


# === WebSocket Endpoint ===

@router.websocket("/{project_id}/ws")
async def websocket_endpoint(websocket: WebSocket, project_id: uuid.UUID):
    """WebSocket connection for real-time project updates (authenticated)"""
    from apex_server.auth.firebase import verify_firebase_token
    from apex_server.auth.service import AuthService
    from apex_server.auth.models import User as UserModel
    from apex_server.shared.database import SessionLocal

    # Extract token from query param or Authorization header
    token = websocket.query_params.get("token")
    if not token:
        auth_header = websocket.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]

    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return

    # Verify token
    db = SessionLocal()
    try:
        user = None

        # Try Firebase first
        firebase_claims = verify_firebase_token(token)
        if firebase_claims:
            uid = firebase_claims["uid"]
            user = db.query(UserModel).filter(UserModel.firebase_uid == uid).first()
        else:
            # Fallback: HS256 dev token
            auth_service = AuthService(db)
            payload = auth_service.decode_token(token)
            if payload:
                user = auth_service.get_by_id(uuid.UUID(payload["sub"]))

        if not user or user.status != "approved":
            await websocket.close(code=4001, reason="Unauthorized")
            return
    finally:
        db.close()

    # Store main loop reference for background thread notifications
    set_main_loop()

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
    image_source: str = "ai"


class ProjectResponse(BaseModel):
    id: str
    brief: str
    status: str
    moodboard: Optional[dict] = None
    clarification: Optional[dict] = None  # Question and options when status is CLARIFICATION
    research_md: Optional[str] = None  # Markdown research report
    selected_moodboard: Optional[int] = None
    selected_layout: Optional[int] = None
    created_at: str
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    error_message: Optional[str] = None

    class Config:
        from_attributes = True


class VariantResponse(BaseModel):
    id: str
    name: str
    moodboard_index: int

    class Config:
        from_attributes = True


class PageResponse(BaseModel):
    id: str
    name: str
    html: str
    variant_id: Optional[str] = None
    layout_variant: Optional[int] = None  # Legacy, kept for compatibility
    current_version: int = 1

    class Config:
        from_attributes = True


class PageVersionResponse(BaseModel):
    id: str
    version: int
    instruction: Optional[str] = None
    created_at: str

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


class ClarifyRequest(BaseModel):
    answer: str  # User's clarification answer


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
        clarification=project.clarification,
        research_md=project.research_md,
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
    """Create a new project and start PHASE 1 (search and maybe clarify)"""
    print(f"[CREATE] Creating project with brief: {request.brief[:50]}...", flush=True)
    project_id = uuid.uuid4()
    project_dir = str(Path(settings.storage_path) / str(project_id))

    image_source = (request.image_source or "ai").strip().lower()
    legacy_map = {
        "existing_site": "img2img",
        "existing": "existing_images",
        "from_site": "existing_images",
        "no_images": "none",
        "none": "none",
    }
    image_source = legacy_map.get(image_source, image_source)
    if image_source not in {"none", "existing_images", "img2img", "ai", "stock"}:
        image_source = "ai"

    project = Project(
        id=project_id,
        brief=request.brief,
        project_dir=project_dir,
        image_source=image_source,
        user_id=current_user.id
    )
    db.add(project)
    db.commit()
    db.refresh(project)

    # Create directory (may fail on Railway - that's OK)
    try:
        Path(project_dir).mkdir(parents=True, exist_ok=True)
    except Exception:
        pass

    # Start PHASE 1 in background: search and check if clarification needed
    def phase1_search_bg(project_id: uuid.UUID):
        print(f"[PHASE1] Starting background search for {project_id}", flush=True)
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
                print(f"[PHASE1] Found project, calling search_and_clarify", flush=True)
                gen = Generator(project, db)
                result = gen.search_and_clarify()
                print(f"[PHASE1] search_and_clarify result: {result}", flush=True)

                # Always asks 3 questions (brand/scope/style)
                notify_from_thread(notify_clarification_needed(
                    str(project_id),
                    result.get("questions", [])
                ))
        except Exception as e:
            print(f"[ERROR] Phase 1 failed: {e}", flush=True)
            import traceback
            traceback.print_exc()
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                notify_from_thread(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    run_in_background(phase1_search_bg, project.id)

    return project_to_response(project)


@router.post("/{project_id}/clarify", response_model=ProjectResponse)
def clarify_project(
    project_id: uuid.UUID,
    request: ClarifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Provide clarification answer and continue to PHASE 2 (moodboard generation).
    Called when project status is CLARIFICATION.
    """
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    if project.status != ProjectStatus.CLARIFICATION:
        raise HTTPException(status_code=400, detail="Project is not waiting for clarification")

    # Save the answer
    clarification = project.clarification or {}
    clarification["answer"] = request.answer
    project.clarification = clarification
    db.commit()

    print(f"[CLARIFY] Received answer for {project_id}: {request.answer}", flush=True)

    # Continue to Phase 2 in background
    def phase2_research_bg(project_id: uuid.UUID):
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
                research_data = gen.research_brand()
                notify_from_thread(notify_moodboard_ready(str(project_id), research_data))

                print(f"[PHASE3] Auto-continuing to layout generation...", flush=True)
                layouts = gen.generate_layouts()
                notify_from_thread(notify_layouts_ready(str(project_id), layouts))
        except Exception as e:
            print(f"[ERROR] Phase 2/3 failed: {e}", flush=True)
            import traceback
            traceback.print_exc()
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                notify_from_thread(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    run_in_background(phase2_research_bg, project.id)

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
    # Refresh to get latest status from database
    db.expire_all()

    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    print(f"[SELECT-MOODBOARD] Project {project_id} status: {project.status}", flush=True)
    print(f"[SELECT-MOODBOARD] Moodboard data: {project.moodboard is not None}", flush=True)
    print(f"[SELECT-MOODBOARD] Requested variant: {request.variant}", flush=True)

    if project.status != ProjectStatus.MOODBOARD:
        raise HTTPException(status_code=400, detail=f"Project must be in moodboard phase (current: {project.status})")

    # Validate variant
    moodboards = project.moodboard.get("moodboards", []) if project.moodboard else []
    print(f"[SELECT-MOODBOARD] Number of moodboards: {len(moodboards)}", flush=True)

    if request.variant < 1 or request.variant > len(moodboards):
        raise HTTPException(status_code=400, detail=f"Invalid moodboard variant. Must be 1-{len(moodboards)}")

    # Save selected moodboard
    project.selected_moodboard = request.variant
    db.commit()

    # Generate layouts in background
    def generate_layouts_bg(project_id: uuid.UUID):
        print(f"[LAYOUTS] Starting layout generation for {project_id}", flush=True)
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
                print(f"[LAYOUTS] Calling generator for {project_id}", flush=True)
                gen = Generator(project, db)
                layouts = gen.generate_layouts()
                print(f"[LAYOUTS] Done! Generated {len(layouts)} layouts", flush=True)
                # Send WebSocket notification via main loop
                print(f"[LAYOUTS] Sending WebSocket notification...", flush=True)
                notify_from_thread(notify_layouts_ready(str(project_id), layouts))
                print(f"[LAYOUTS] WebSocket notification sent!", flush=True)
        except Exception as e:
            print(f"[LAYOUTS] Error: {e}", flush=True)
            import traceback
            traceback.print_exc()
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                notify_from_thread(notify_error(str(project_id), str(e)))
        finally:
            db.close()

    print(f"[SELECT-MOODBOARD] Starting layout generation in background", flush=True)
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
                notify_from_thread(notify_layouts_ready(str(project_id), layouts))
        except Exception as e:
            project = db.query(Project).filter_by(id=project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = str(e)
                db.commit()
                notify_from_thread(notify_error(str(project_id), str(e)))
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


# === Variants Endpoints ===

@router.get("/{project_id}/variants", response_model=List[VariantResponse])
def get_variants(
    project_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all variants for a project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    variants = db.query(Variant).filter(Variant.project_id == project_id).all()

    return [VariantResponse(
        id=str(v.id),
        name=v.name,
        moodboard_index=v.moodboard_index
    ) for v in variants]


class CreateVariantRequest(BaseModel):
    name: str
    moodboard_index: int


@router.post("/{project_id}/variants", response_model=VariantResponse)
def create_variant(
    project_id: uuid.UUID,
    request: CreateVariantRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new variant for a project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    variant = Variant(
        project_id=project.id,
        name=request.name,
        moodboard_index=request.moodboard_index
    )
    db.add(variant)
    db.commit()

    return VariantResponse(
        id=str(variant.id),
        name=variant.name,
        moodboard_index=variant.moodboard_index
    )


@router.get("/{project_id}/variants/{variant_id}/pages", response_model=List[PageResponse])
def get_variant_pages(
    project_id: uuid.UUID,
    variant_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all pages for a specific variant"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    pages = db.query(Page).filter(
        Page.project_id == project_id,
        Page.variant_id == variant_id
    ).all()

    return [PageResponse(
        id=str(p.id),
        name=p.name,
        html=p.html,
        variant_id=str(p.variant_id) if p.variant_id else None,
        layout_variant=p.layout_variant,
        current_version=p.current_version
    ) for p in pages]


# === Pages Endpoints ===

@router.get("/{project_id}/pages", response_model=List[PageResponse])
def get_pages(
    project_id: uuid.UUID,
    request: Request,
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

    # Rewrite image URLs to use assets endpoint
    base_url = str(request.base_url).rstrip('/')

    return [PageResponse(
        id=str(p.id),
        name=p.name,
        html=rewrite_asset_urls(p.html, str(project_id), base_url),
        variant_id=str(p.variant_id) if p.variant_id else None,
        layout_variant=p.layout_variant,
        current_version=p.current_version
    ) for p in pages]


@router.get("/{project_id}/pages/{page_id}", response_model=PageResponse)
def get_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: Request,
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

    # Rewrite image URLs to use assets endpoint
    base_url = str(request.base_url).rstrip('/')
    html = rewrite_asset_urls(page.html, str(project_id), base_url)

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=html,
        layout_variant=page.layout_variant,
        current_version=page.current_version
    )


@router.post("/{project_id}/pages/{page_id}/edit", response_model=PageResponse)
def edit_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: EditPageRequest,
    http_request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Edit a page with an instruction - uses agentic file tools"""
    print(f"[EDIT] Agentic editing page {page_id}: {request.instruction[:50]}...", flush=True)
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        print(f"[EDIT] Project not found: {project_id}", flush=True)
        raise HTTPException(status_code=404, detail="Project not found")

    page = db.query(Page).filter(Page.id == page_id).first()
    if not page:
        raise HTTPException(status_code=404, detail="Page not found")

    print(f"[EDIT] Page found, current version: {page.current_version}", flush=True)
    version_before = page.current_version

    # Save current state as version before edit (if not already saved)
    existing_versions = db.query(PageVersion).filter(PageVersion.page_id == page_id).count()
    print(f"[EDIT] Existing versions count: {existing_versions}", flush=True)
    if existing_versions == 0:
        # Create initial version (v1) from current state
        print(f"[EDIT] Creating initial version v1", flush=True)
        initial_version = PageVersion(
            page_id=page.id,
            version=1,
            html=page.html,
            instruction="Initial version"
        )
        db.add(initial_version)
        db.commit()

    # Use agentic editing - Opus can read/write files as needed
    gen = Generator(project, db)
    response_text = gen.agentic_edit(request.instruction, str(page_id))
    print(f"[EDIT] Agentic response: {response_text[:100] if response_text else 'None'}...", flush=True)

    # Refresh page from db after agentic edit (it may have been updated via tools)
    db.refresh(page)
    print(f"[EDIT] After agentic edit, page.current_version: {page.current_version}", flush=True)

    # Only create new version if agentic edit didn't already create one
    if page.current_version == version_before:
        # Agentic edit didn't change anything, but we still log the instruction
        new_version_num = page.current_version + 1
        print(f"[EDIT] No file changes, creating version v{new_version_num} for instruction log", flush=True)
        new_version = PageVersion(
            page_id=page.id,
            version=new_version_num,
            html=page.html,
            instruction=request.instruction
        )
        db.add(new_version)
        page.current_version = new_version_num
        db.commit()
    else:
        print(f"[EDIT] Agentic edit already created version, skipping duplicate", flush=True)

    print(f"[EDIT] Returning page with version: {page.current_version}", flush=True)

    # Rewrite image URLs to use assets endpoint
    base_url = str(http_request.base_url).rstrip('/')
    html = rewrite_asset_urls(page.html, str(project_id), base_url)

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=html,
        layout_variant=page.layout_variant,
        current_version=page.current_version
    )


@router.get("/{project_id}/pages/{page_id}/versions", response_model=List[PageVersionResponse])
def get_page_versions(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all versions of a page"""
    print(f"[VERSIONS] Getting versions for page {page_id} in project {project_id}", flush=True)

    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        print(f"[VERSIONS] Project not found or not owned by user", flush=True)
        raise HTTPException(status_code=404, detail="Project not found")

    versions = db.query(PageVersion).filter(
        PageVersion.page_id == page_id
    ).order_by(PageVersion.version).all()

    print(f"[VERSIONS] Found {len(versions)} versions", flush=True)

    return [
        PageVersionResponse(
            id=str(v.id),
            version=v.version,
            instruction=v.instruction,
            created_at=v.created_at.isoformat()
        )
        for v in versions
    ]


class RestoreVersionRequest(BaseModel):
    version: int


@router.post("/{project_id}/pages/{page_id}/restore", response_model=PageResponse)
def restore_page_version(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: RestoreVersionRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Restore a page to a specific version"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    page = db.query(Page).filter(Page.id == page_id).first()
    if not page:
        raise HTTPException(status_code=404, detail="Page not found")

    # Try to get version from filesystem first
    fs = FileSystemService(str(project_id))
    html = fs.get_version(str(page_id), request.version)

    if not html:
        # Fallback to PostgreSQL
        version = db.query(PageVersion).filter(
            PageVersion.page_id == page_id,
            PageVersion.version == request.version
        ).first()
        if not version:
            raise HTTPException(status_code=404, detail="Version not found")
        html = version.html

    # Update page in PostgreSQL
    page.html = html
    page.current_version = request.version
    db.commit()

    # Update file in filesystem
    file_name = page.name.lower().replace(" ", "-") + ".html"
    fs.write_file(f"public/{file_name}", html)

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=html,
        layout_variant=page.layout_variant,
        current_version=page.current_version
    )


class StructuredEditRequest(BaseModel):
    instruction: str
    html: str  # Current HTML from client


class StructuredEditApiResponse(BaseModel):
    edits: list
    explanation: str


@router.post("/{project_id}/pages/{page_id}/structured-edit")
def structured_edit_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: StructuredEditRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Generate structured edit instructions (not full HTML).
    Client applies edits locally, then syncs back.
    Much more token-efficient!
    """
    print(f"[STRUCTURED-EDIT] Editing page {page_id}: {request.instruction[:50]}...", flush=True)
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        print(f"[STRUCTURED-EDIT] Project not found: {project_id}", flush=True)
        raise HTTPException(status_code=404, detail="Project not found")

    # Get moodboard for context
    moodboard = None
    if project.moodboard and project.selected_moodboard:
        moodboards = project.moodboard.get("moodboards", [])
        idx = project.selected_moodboard - 1
        if 0 <= idx < len(moodboards):
            moodboard = moodboards[idx]

    # Generate structured edits
    print(f"[STRUCTURED-EDIT] Calling AI to generate edits...", flush=True)
    result = generate_structured_edit(
        html=request.html,
        instruction=request.instruction,
        moodboard=moodboard
    )
    print(f"[STRUCTURED-EDIT] Got {len(result.edits)} edits", flush=True)

    # Log the edit
    log = ProjectLog(
        project_id=project.id,
        phase="edit",
        message=f"Structured edit: {request.instruction}",
        data={"edits_count": len(result.edits)}
    )
    db.add(log)
    db.commit()

    return {
        "edits": [edit.model_dump() for edit in result.edits],
        "explanation": result.explanation
    }


class SyncPageRequest(BaseModel):
    html: str  # Updated HTML from client after local edits


@router.post("/{project_id}/pages/{page_id}/sync", response_model=PageResponse)
def sync_page(
    project_id: uuid.UUID,
    page_id: uuid.UUID,
    request: SyncPageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sync updated HTML from client back to server.
    Called after client applies structured edits locally.
    """
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    page = db.query(Page).filter(
        Page.id == page_id,
        Page.project_id == project_id
    ).first()

    if not page:
        raise HTTPException(status_code=404, detail="Page not found")

    # Update page HTML
    page.html = request.html
    db.commit()

    return PageResponse(
        id=str(page.id),
        name=page.name,
        html=page.html,
        layout_variant=page.layout_variant,
        current_version=page.current_version
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
        layout_variant=page.layout_variant,
        current_version=page.current_version
    )


class GenerateSiteRequest(BaseModel):
    pages: Optional[List[str]] = None  # Optional list of pages to create


class GenerateSiteResponse(BaseModel):
    pages_created: List[str]
    summary: str
    total_pages: int


@router.post("/{project_id}/generate-site", response_model=GenerateSiteResponse)
def generate_site(
    project_id: uuid.UUID,
    request: GenerateSiteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Generate a complete mini-site from the current layout"""
    print(f"[GENERATE-SITE] Starting for project {project_id}", flush=True)

    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    # Check that project has at least one page to use as template
    existing_pages = db.query(Page).filter(Page.project_id == project_id).count()
    if existing_pages == 0:
        raise HTTPException(status_code=400, detail="Project needs at least one page as template")

    gen = Generator(project, db)
    result = gen.generate_site(request.pages)

    print(f"[GENERATE-SITE] Complete: {result['total_pages']} pages created", flush=True)

    return GenerateSiteResponse(
        pages_created=result["pages_created"],
        summary=result["summary"],
        total_pages=result["total_pages"]
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


# === GitHub Clone Endpoint ===

class CloneRepoRequest(BaseModel):
    github_url: str


class CloneRepoResponse(BaseModel):
    project_id: str
    path: str
    files_count: int
    success: bool
    error: Optional[str] = None


@router.post("/clone", response_model=CloneRepoResponse)
def clone_github_repo(
    request: CloneRepoRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Clone a GitHub repository as a new project"""
    import re

    print(f"[CLONE] Cloning {request.github_url}", flush=True)

    # Extract repo name from URL
    match = re.search(r'github\.com[/:]([^/]+)/([^/\.]+)', request.github_url)
    if not match:
        raise HTTPException(status_code=400, detail="Invalid GitHub URL")

    repo_name = match.group(2)

    # Create project in database
    project = Project(
        brief=f"Cloned from {request.github_url}",
        status=ProjectStatus.EDITING,
        user_id=current_user.id,
        project_dir=""  # Will be set by filesystem
    )
    db.add(project)
    db.flush()

    # Clone repository
    fs = FileSystemService(str(project.id))
    result = fs.clone_repo(request.github_url)

    if not result["success"]:
        db.rollback()
        raise HTTPException(status_code=400, detail=result.get("error", "Clone failed"))

    # Update project with path
    project.project_dir = str(fs.base_dir)
    db.commit()

    # Scan for HTML files and create pages
    html_files = list(fs.base_dir.rglob("*.html"))
    for html_file in html_files[:10]:  # Limit to 10 files
        try:
            content = html_file.read_text(encoding="utf-8")
            name = html_file.stem.replace("-", " ").replace("_", " ").title()
            page = Page(
                project_id=project.id,
                name=name,
                html=content
            )
            db.add(page)
        except Exception as e:
            print(f"[CLONE] Could not read {html_file}: {e}", flush=True)

    db.commit()
    print(f"[CLONE] Done! {result['files']} files cloned", flush=True)

    return CloneRepoResponse(
        project_id=str(project.id),
        path=str(fs.base_dir),
        files_count=result.get("files", 0),
        success=True
    )


# ==========================================
# Debug Endpoints
# ==========================================

@router.get("/{project_id}/files")
def list_project_files(
    project_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Debug: List all files on disk for a project"""
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == current_user.id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    fs = FileSystemService(project_id)

    # Check if base directory exists
    if not fs.base_dir.exists():
        return {
            "project_id": project_id,
            "base_dir": str(fs.base_dir),
            "exists": False,
            "files": []
        }

    # Recursively list all files
    all_files = []
    for path in fs.base_dir.rglob("*"):
        if path.is_file():
            all_files.append({
                "path": str(path.relative_to(fs.base_dir)),
                "size": path.stat().st_size
            })

    return {
        "project_id": project_id,
        "base_dir": str(fs.base_dir),
        "exists": True,
        "files": sorted(all_files, key=lambda x: x["path"]),
        "total_files": len(all_files)
    }


@router.get("/{project_id}/assets/{file_path:path}")
def serve_project_asset(
    project_id: str,
    file_path: str
):
    """Serve static files (images, etc) from project's public directory.

    Note: No auth required - project_id is a UUID (hard to guess) and
    files are only served from the public directory. Can add signed URLs later.
    """

    fs = FileSystemService(project_id)

    # Only serve files from public directory for security
    full_path = fs.public_dir / file_path

    # Security: ensure path doesn't escape public directory
    try:
        full_path = full_path.resolve()
        if not str(full_path).startswith(str(fs.public_dir.resolve())):
            raise HTTPException(status_code=403, detail="Access denied")
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid path")

    if not full_path.exists() or not full_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    # Determine content type
    content_type, _ = mimetypes.guess_type(str(full_path))
    if not content_type:
        content_type = "application/octet-stream"

    print(f"[ASSETS] Serving {file_path} ({content_type})", flush=True)

    return FileResponse(
        path=full_path,
        media_type=content_type,
        filename=full_path.name
    )
