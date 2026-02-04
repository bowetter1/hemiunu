"""Daytona sandbox integration for Apex projects.

Each project gets a Daytona sandbox for file storage, preview URLs,
and command execution. The sandbox replaces Railway volume storage.
"""
import logging
from typing import Optional, Dict

from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams

from apex_server.config import get_settings

logger = logging.getLogger("apex.daytona")
settings = get_settings()

# Docker images per project type
SANDBOX_IMAGES = {
    "html": "python:3.12-slim-bookworm",
    "python": "python:3.12-slim-bookworm",
    "fastapi": "python:3.12-slim-bookworm",
    "flask": "python:3.12-slim-bookworm",
    "node": "node:20-slim",
    "react": "node:20-slim",
    "nextjs": "node:20-slim",
    "default": "python:3.12-slim-bookworm",
}


class DaytonaService:
    """Manages Daytona sandbox lifecycle for Apex projects."""

    def __init__(self):
        self._client: Optional[Daytona] = None
        self._sandboxes: Dict[str, object] = {}  # cache: project_id -> sandbox

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    async def start(self):
        """Initialize Daytona client. Called from app lifespan."""
        if not settings.daytona_api_key:
            logger.warning("No Daytona API key configured, skipping")
            return
        self._client = Daytona(DaytonaConfig(api_key=settings.daytona_api_key))
        logger.info("Daytona client initialized")

    async def stop(self):
        """Cleanup on shutdown."""
        self._sandboxes.clear()
        logger.info("Daytona service stopped")

    @property
    def is_available(self) -> bool:
        return self._client is not None

    # ------------------------------------------------------------------
    # Sandbox CRUD
    # ------------------------------------------------------------------

    def create_sandbox(
        self,
        project_id: str,
        project_type: str = "html",
        env_vars: dict = None,
    ) -> dict:
        """Create a new Daytona sandbox for a project.

        Initialises directory structure: public/, .apex/versions/, src/.
        Returns dict with sandbox_id and metadata.
        """
        if not self._client:
            raise RuntimeError("Daytona not initialized")

        image = SANDBOX_IMAGES.get(project_type, SANDBOX_IMAGES["default"])
        name = f"apex-{project_id[:12]}"

        sandbox = self._client.create(CreateSandboxFromImageParams(
            image=image,
            name=name,
            env_vars=env_vars or {},
        ))

        self._sandboxes[project_id] = sandbox

        # Create project directory structure
        for path in [
            "/workspace/public/images",
            "/workspace/.apex/versions",
            "/workspace/src",
        ]:
            try:
                sandbox.fs.create_folder(path, mode="755")
            except Exception as e:
                logger.debug("create_folder %s: %s", path, e)

        # Create .gitignore (upload_file treats str as file path, must use bytes)
        sandbox.fs.upload_file(
            ".apex/\n.env\n__pycache__/\n*.pyc\nnode_modules/\n.DS_Store\n".encode("utf-8"),
            "/workspace/.gitignore",
        )

        # Install git if not present (python:3.12-slim doesn't include it)
        git_check = sandbox.process.exec("which git", cwd="/workspace")
        if git_check.exit_code != 0:
            logger.info("Installing git in sandbox %s", name)
            sandbox.process.exec(
                "apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1",
                cwd="/workspace",
                timeout=120,
            )

        # Init git repo
        sandbox.process.exec("git config user.email 'apex@apex.dev'", cwd="/workspace")
        sandbox.process.exec("git config user.name 'Apex'", cwd="/workspace")
        init_result = sandbox.process.exec("git init", cwd="/workspace")
        if init_result.exit_code != 0:
            logger.warning("git init failed in sandbox %s: %s", name, init_result.result)
        else:
            sandbox.process.exec("git add .", cwd="/workspace")
            commit_result = sandbox.process.exec('git commit -m "Initial commit"', cwd="/workspace")
            if commit_result.exit_code != 0:
                logger.warning("git commit failed: %s", commit_result.result)

        logger.info("Created sandbox %s for project %s (image=%s)", sandbox.id, project_id, image)

        return {
            "sandbox_id": sandbox.id,
            "name": name,
            "image": image,
            "status": "running",
        }

    def get_sandbox(self, project_id: str, sandbox_id: str = None):
        """Get or reconnect to a sandbox. Caches by project_id."""
        cached = self._sandboxes.get(project_id)
        if cached is not None:
            # Validate cached sandbox matches requested sandbox_id
            if sandbox_id and cached.id != sandbox_id:
                logger.warning(
                    "Cached sandbox %s doesn't match requested %s for project %s, re-fetching",
                    cached.id, sandbox_id, project_id,
                )
                del self._sandboxes[project_id]
            else:
                return cached

        if not sandbox_id:
            raise ValueError(f"No cached sandbox and no sandbox_id for project {project_id}")

        if not self._client:
            raise RuntimeError("Daytona not initialized")

        sandbox = self._client.get(sandbox_id)
        self._sandboxes[project_id] = sandbox
        return sandbox

    def stop_sandbox(self, project_id: str, sandbox_id: str):
        """Stop a running sandbox."""
        sandbox = self.get_sandbox(project_id, sandbox_id)
        sandbox.stop()
        self._sandboxes.pop(project_id, None)
        logger.info("Stopped sandbox %s", sandbox_id)

    def start_sandbox(self, project_id: str, sandbox_id: str):
        """Start a stopped sandbox."""
        sandbox = self.get_sandbox(project_id, sandbox_id)
        sandbox.start()
        logger.info("Started sandbox %s", sandbox_id)

    def delete_sandbox(self, project_id: str, sandbox_id: str):
        """Delete a sandbox permanently."""
        sandbox = self.get_sandbox(project_id, sandbox_id)
        sandbox.delete()
        self._sandboxes.pop(project_id, None)
        logger.info("Deleted sandbox %s", sandbox_id)

    # ------------------------------------------------------------------
    # Operations
    # ------------------------------------------------------------------

    def clone_repo(
        self,
        project_id: str,
        sandbox_id: str,
        github_url: str,
        branch: str = "main",
    ) -> dict:
        """Clone a GitHub repo into the sandbox workspace."""
        sandbox = self.get_sandbox(project_id, sandbox_id)

        # Clear workspace completely (including dotfiles like .git)
        sandbox.process.exec("rm -rf /workspace/{*,.[!.]*,..?*} 2>/dev/null || true", cwd="/")

        try:
            sandbox.git.clone(github_url, "/workspace", branch=branch)
        except Exception as e:
            logger.error("git clone failed for %s: %s", github_url, e)
            return {"success": False, "error": str(e), "github_url": github_url}

        # Create .apex directory
        try:
            sandbox.fs.create_folder("/workspace/.apex/versions", mode="755")
        except Exception as e:
            logger.debug("create_folder .apex/versions: %s", e)

        # Append .apex/ to .gitignore if needed
        try:
            gitignore_bytes = sandbox.fs.download_file("/workspace/.gitignore")
            gitignore = gitignore_bytes.decode("utf-8") if gitignore_bytes else ""
        except Exception:
            gitignore = ""
        if ".apex/" not in gitignore:
            sandbox.fs.upload_file(
                (gitignore + "\n# Apex internal\n.apex/\n").encode("utf-8"),
                "/workspace/.gitignore",
            )

        logger.info("Cloned %s into sandbox %s", github_url, sandbox_id)
        return {"success": True, "github_url": github_url}

    def exec_command(
        self,
        project_id: str,
        sandbox_id: str,
        command: str,
        cwd: str = "/workspace",
    ) -> dict:
        """Execute a command inside the sandbox."""
        sandbox = self.get_sandbox(project_id, sandbox_id)
        response = sandbox.process.exec(command, cwd=cwd)
        return {
            "exit_code": response.exit_code,
            "stdout": response.result,
        }

    def get_preview_url(self, project_id: str, sandbox_id: str, port: int = 8000) -> dict:
        """Get a public preview URL for a port in the sandbox."""
        sandbox = self.get_sandbox(project_id, sandbox_id)
        preview = sandbox.get_preview_link(port)
        return {"url": preview.url, "token": preview.token}


# Global singleton
daytona_service = DaytonaService()
