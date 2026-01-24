"""Sprint routes"""
import uuid
from typing import Optional
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, Query
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from apex_server.config import get_settings
from apex_server.shared.database import get_db
from apex_server.shared.dependencies import get_current_user
from apex_server.shared.tools import list_files, read_file
from apex_server.auth.models import User
from .models import SprintStatus, LogEntry, Question, QuestionStatus
from .service import SprintService
from .runner import SprintRunner
from .websocket import sprint_ws_manager
from .schemas import (
    CreateSprintRequest,
    SprintResponse,
    SprintListResponse,
    SprintFilesResponse,
    SprintFileResponse,
    LogEntryResponse,
    SprintLogsResponse,
    QuestionResponse,
    AnswerRequest,
)

router = APIRouter(prefix="/sprints", tags=["sprints"])
settings = get_settings()


def sprint_to_response(sprint) -> SprintResponse:
    """Convert Sprint model to response schema"""
    return SprintResponse(
        id=str(sprint.id),
        task=sprint.task,
        status=sprint.status.value,
        project_dir=sprint.project_dir,
        team=sprint.team or "a-team",
        github_repo=sprint.github_repo,
        created_at=sprint.created_at.isoformat(),
        started_at=sprint.started_at.isoformat() if sprint.started_at else None,
        completed_at=sprint.completed_at.isoformat() if sprint.completed_at else None,
        error_message=sprint.error_message,
        input_tokens=sprint.input_tokens or 0,
        output_tokens=sprint.output_tokens or 0,
        cost_usd=sprint.cost_usd or 0.0
    )


def run_sprint_background(sprint_id: uuid.UUID, db_url: str):
    """Run sprint in background thread"""
    import threading
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from .models import Sprint

    def run():
        engine = create_engine(db_url)
        SessionLocal = sessionmaker(bind=engine)
        db = SessionLocal()

        try:
            sprint = db.query(Sprint).filter_by(id=sprint_id).first()
            if sprint:
                runner = SprintRunner(sprint, db)
                runner.run()
        except Exception as e:
            print(f"Sprint error: {e}")
            # Update sprint status to failed
            sprint = db.query(Sprint).filter_by(id=sprint_id).first()
            if sprint:
                sprint.status = SprintStatus.FAILED
                sprint.error_message = str(e)
                db.commit()
        finally:
            db.close()

    thread = threading.Thread(target=run, daemon=True)
    thread.start()


@router.post("", response_model=SprintResponse)
def create_sprint(
    request: CreateSprintRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create and start a new sprint"""
    service = SprintService(db)

    sprint = service.create(
        task=request.task,
        tenant_id=current_user.tenant_id,
        created_by_id=current_user.id,
        team=request.team
    )

    # Run sprint in background thread
    db_url = str(settings.database_url)
    run_sprint_background(sprint.id, db_url)

    # Return immediately with running status
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


@router.get("/{sprint_id}/logs", response_model=SprintLogsResponse)
def get_sprint_logs(
    sprint_id: uuid.UUID,
    since_id: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get logs for a sprint, optionally since a specific log ID"""
    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    # Get logs since the given ID
    logs = db.query(LogEntry).filter(
        LogEntry.sprint_id == sprint_id,
        LogEntry.id > since_id
    ).order_by(LogEntry.id).all()

    return SprintLogsResponse(
        logs=[
            LogEntryResponse(
                id=log.id,
                timestamp=log.timestamp.isoformat(),
                log_type=log.log_type.value,
                worker=log.worker,
                message=log.message,
                data=log.data
            )
            for log in logs
        ],
        total=len(sprint.logs)
    )


@router.get("/{sprint_id}/question", response_model=Optional[QuestionResponse])
def get_pending_question(
    sprint_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the current pending question for a sprint (if any)"""
    import json as json_module

    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    # Find pending question
    question = db.query(Question).filter(
        Question.sprint_id == sprint_id,
        Question.status == QuestionStatus.PENDING
    ).order_by(Question.id.desc()).first()

    if not question:
        return None

    # Parse options JSON
    options = None
    if question.options:
        try:
            options = json_module.loads(question.options)
        except (json_module.JSONDecodeError, TypeError):
            options = []

    return QuestionResponse(
        id=question.id,
        question=question.question,
        options=options,
        status=question.status.value,
        created_at=question.created_at.isoformat(),
        answer=question.answer,
        answered_at=question.answered_at.isoformat() if question.answered_at else None
    )


@router.post("/{sprint_id}/question/{question_id}/answer")
def answer_question(
    sprint_id: uuid.UUID,
    question_id: int,
    request: AnswerRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Answer a pending question"""
    from datetime import datetime

    service = SprintService(db)
    sprint = service.get_by_id(sprint_id, current_user.tenant_id)

    if not sprint:
        raise HTTPException(status_code=404, detail="Sprint not found")

    # Find the question
    question = db.query(Question).filter(
        Question.id == question_id,
        Question.sprint_id == sprint_id
    ).first()

    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    if question.status != QuestionStatus.PENDING:
        raise HTTPException(status_code=400, detail="Question already answered")

    # Update question with answer
    question.answer = request.answer
    question.answered_at = datetime.utcnow()
    question.status = QuestionStatus.ANSWERED
    db.commit()

    return {"status": "answered", "answer": request.answer}


@router.websocket("/{sprint_id}/ws")
async def sprint_websocket(
    websocket: WebSocket,
    sprint_id: uuid.UUID,
    token: str = Query(...)
):
    """WebSocket endpoint for real-time sprint updates

    Connect with: ws://host/api/v1/sprints/{sprint_id}/ws?token={jwt_token}
    """
    from apex_server.auth.models import User
    from apex_server.shared.database import SessionLocal

    # Verify JWT token
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm]
        )
        user_id = payload.get("sub")
        if not user_id:
            await websocket.close(code=4001, reason="Invalid token")
            return
    except JWTError:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # Verify user has access to this sprint
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            await websocket.close(code=4001, reason="User not found")
            return

        service = SprintService(db)
        sprint = service.get_by_id(sprint_id, user.tenant_id)
        if not sprint:
            await websocket.close(code=4004, reason="Sprint not found")
            return

        sprint_id_str = str(sprint_id)

        # Connect to WebSocket manager
        await sprint_ws_manager.connect(sprint_id_str, websocket)

        try:
            # Keep connection alive and handle incoming messages
            while True:
                # Wait for messages (ping/pong or close)
                data = await websocket.receive_text()
                # Client can send "ping" to keep alive
                if data == "ping":
                    await websocket.send_text('{"type": "pong"}')
        except WebSocketDisconnect:
            pass
        finally:
            await sprint_ws_manager.disconnect(sprint_id_str, websocket)

    finally:
        db.close()
