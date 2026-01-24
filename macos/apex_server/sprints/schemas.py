"""Pydantic schemas for sprint API"""
from typing import List, Optional
from pydantic import BaseModel


class CreateSprintRequest(BaseModel):
    task: str
    team: str = "a-team"  # a-team, groq-team


class SprintResponse(BaseModel):
    id: str
    task: str
    status: str
    project_dir: str
    team: str
    github_repo: Optional[str]
    created_at: str
    started_at: Optional[str]
    completed_at: Optional[str]
    error_message: Optional[str]
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0

    class Config:
        from_attributes = True


class SprintListResponse(BaseModel):
    sprints: List[SprintResponse]


class SprintFilesResponse(BaseModel):
    files: str


class SprintFileResponse(BaseModel):
    path: str
    content: str


class LogEntryResponse(BaseModel):
    id: int
    timestamp: str
    log_type: str
    worker: Optional[str]
    message: str
    data: Optional[str]

    class Config:
        from_attributes = True


class SprintLogsResponse(BaseModel):
    logs: List[LogEntryResponse]
    total: int


class QuestionResponse(BaseModel):
    id: int
    question: str
    options: Optional[List[str]]
    status: str
    created_at: str
    answer: Optional[str]
    answered_at: Optional[str]

    class Config:
        from_attributes = True


class AnswerRequest(BaseModel):
    answer: str
