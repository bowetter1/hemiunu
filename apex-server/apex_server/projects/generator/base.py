"""Base Generator class with core functionality"""
from pathlib import Path
from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from ..models import Project, ProjectLog
from ..filesystem import FileSystemService

from .research import ResearchMixin
from .layouts import LayoutsMixin
from .editing import EditingMixin
from .site import SiteGenerationMixin
from .code_project import CodeProjectMixin
from .images import ImageGenerationMixin

settings = get_settings()


class Generator(ResearchMixin, LayoutsMixin, EditingMixin, SiteGenerationMixin, CodeProjectMixin, ImageGenerationMixin):
    """Generates brand research, layouts, and page edits using Claude"""

    def __init__(self, project: Project, db: Session):
        self.project = project
        self.db = db
        self.project_dir = Path(project.project_dir)  # Legacy, kept for compatibility
        self.fs = FileSystemService(str(project.id))  # New filesystem service
        self.client = Anthropic(api_key=settings.anthropic_api_key)

    def log(self, phase: str, message: str, data: dict = None):
        """Add a log entry"""
        entry = ProjectLog(
            project_id=self.project.id,
            phase=phase,
            message=message,
            data=data
        )
        self.db.add(entry)
        self.db.commit()

    def track_usage(self, response):
        """Track token usage"""
        self.project.input_tokens += response.usage.input_tokens
        self.project.output_tokens += response.usage.output_tokens
        # Approximate cost for claude-sonnet-4
        cost = (response.usage.input_tokens * 0.003 + response.usage.output_tokens * 0.015) / 1000
        self.project.cost_usd += cost
        self.db.commit()
