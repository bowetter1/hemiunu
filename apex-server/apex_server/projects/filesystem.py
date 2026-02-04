"""
Filesystem service for project files.

Two implementations:
1. FileSystemService      — local disk (Railway volume, legacy)
2. DaytonaFileSystemService — Daytona sandbox (new)

Factory function get_filesystem() selects based on project sandbox_id.

Projects are stored at: /data/projects/{project_id}/  (local)
                    or: /workspace/                    (Daytona sandbox)
├── .git/                    # Git repo
├── .gitignore
├── public/                  # Deployable files
│   ├── index.html
│   └── styles.css
├── .apex/                   # Internal (gitignored)
│   └── versions/
│       └── {page_id}/
│           ├── v1.html
│           └── v2.html
└── src/                     # Source code (optional)
"""
import logging
import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional, List
from datetime import datetime

from apex_server.config import get_settings

logger = logging.getLogger("apex.filesystem")
settings = get_settings()


# ==============================================================================
# Local Filesystem (legacy — Railway volume)
# ==============================================================================

class FileSystemService:
    """Service for managing project files on local disk."""

    def __init__(self, project_id: str):
        self.project_id = project_id
        self.base_dir = Path(settings.data_dir) / "projects" / project_id
        self.public_dir = self.base_dir / "public"
        self.versions_dir = self.base_dir / ".apex" / "versions"
        self.src_dir = self.base_dir / "src"

    # ==========================================
    # Project Initialization
    # ==========================================

    def init_project(self) -> dict:
        """Initialize a new project directory with git."""
        print(f"[FS] Initializing project at {self.base_dir}", flush=True)

        # Create directories
        self.public_dir.mkdir(parents=True, exist_ok=True)
        self.versions_dir.mkdir(parents=True, exist_ok=True)
        print(f"[FS] Created directories: public/, .apex/versions/", flush=True)

        # Create .gitignore
        gitignore_path = self.base_dir / ".gitignore"
        if not gitignore_path.exists():
            gitignore_path.write_text(""".apex/
.env
__pycache__/
*.pyc
node_modules/
.DS_Store
""")
            print(f"[FS] Created .gitignore", flush=True)

        # Initialize git repo if not exists
        git_dir = self.base_dir / ".git"
        if not git_dir.exists():
            self._run_git("init")
            self._run_git("add", ".")
            self._run_git("commit", "-m", "Initial commit")
            print(f"[FS] Initialized git repo", flush=True)

        print(f"[FS] Project initialized successfully", flush=True)
        return {
            "project_id": self.project_id,
            "path": str(self.base_dir),
            "initialized": True
        }

    def delete_project(self) -> bool:
        """Delete entire project directory."""
        if self.base_dir.exists():
            shutil.rmtree(self.base_dir)
            return True
        return False

    # ==========================================
    # File Operations
    # ==========================================

    def read_file(self, path: str) -> Optional[str]:
        """Read file content. Path is relative to project root."""
        file_path = self.base_dir / path
        if file_path.exists() and file_path.is_file():
            content = file_path.read_text(encoding="utf-8")
            print(f"[FS] Read {path} ({len(content)} bytes)", flush=True)
            return content
        print(f"[FS] File not found: {path}", flush=True)
        return None

    def read_binary(self, path: str) -> Optional[bytes]:
        """Read binary file content."""
        file_path = self.base_dir / path
        if file_path.exists() and file_path.is_file():
            return file_path.read_bytes()
        return None

    def write_file(self, path: str, content: str) -> dict:
        """Write file content. Creates directories if needed."""
        file_path = self.base_dir / path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content, encoding="utf-8")
        print(f"[FS] Wrote {path} ({len(content)} bytes)", flush=True)
        return {
            "path": path,
            "size": len(content),
            "written": True
        }

    def write_binary(self, path: str, data: bytes) -> dict:
        """Write binary file (images, etc). Creates directories if needed."""
        file_path = self.base_dir / path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(data)
        print(f"[FS] Wrote binary {path} ({len(data)} bytes)", flush=True)
        return {
            "path": path,
            "size": len(data),
            "written": True
        }

    def delete_file(self, path: str) -> bool:
        """Delete a file."""
        file_path = self.base_dir / path
        if file_path.exists() and file_path.is_file():
            file_path.unlink()
            return True
        return False

    def list_files(self, directory: str = "") -> List[dict]:
        """List files in a directory."""
        dir_path = self.base_dir / directory if directory else self.base_dir
        if not dir_path.exists():
            return []

        files = []
        for item in dir_path.iterdir():
            # Skip hidden directories except .git info
            if item.name.startswith(".") and item.name not in [".gitignore"]:
                continue

            files.append({
                "name": item.name,
                "path": str(item.relative_to(self.base_dir)),
                "is_dir": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else 0
            })

        return sorted(files, key=lambda x: (not x["is_dir"], x["name"]))

    def file_exists(self, path: str) -> bool:
        """Check if file exists."""
        return (self.base_dir / path).exists()

    # ==========================================
    # Pipeline File Operations (.apex/)
    # ==========================================

    def write_pipeline_file(self, filename: str, content: str) -> dict:
        """Write a pipeline file to .apex/{filename} (e.g. 01-search.md)."""
        path = f".apex/{filename}"
        return self.write_file(path, content)

    def read_pipeline_file(self, filename: str) -> Optional[str]:
        """Read a pipeline file from .apex/{filename}."""
        return self.read_file(f".apex/{filename}")

    # ==========================================
    # Page HTML Operations
    # ==========================================

    def write_page_html(self, page_id: str, html: str, file_name: str = "index.html") -> dict:
        """Write current page HTML to public directory."""
        path = f"public/{file_name}"
        return self.write_file(path, html)

    def read_page_html(self, file_name: str = "index.html") -> Optional[str]:
        """Read page HTML from public directory."""
        return self.read_file(f"public/{file_name}")

    # ==========================================
    # Version Operations
    # ==========================================

    def save_version(self, page_id: str, version: int, html: str) -> dict:
        """Save a version of page HTML."""
        version_dir = self.versions_dir / page_id
        version_dir.mkdir(parents=True, exist_ok=True)

        version_path = version_dir / f"v{version}.html"
        version_path.write_text(html, encoding="utf-8")
        print(f"[FS] Saved version v{version} for page {page_id[:8]}... ({len(html)} bytes)", flush=True)

        return {
            "page_id": page_id,
            "version": version,
            "path": str(version_path.relative_to(self.base_dir)),
            "size": len(html)
        }

    def get_version(self, page_id: str, version: int) -> Optional[str]:
        """Get a specific version of page HTML."""
        version_path = self.versions_dir / page_id / f"v{version}.html"
        if version_path.exists():
            content = version_path.read_text(encoding="utf-8")
            print(f"[FS] Read version v{version} for page {page_id[:8]}... ({len(content)} bytes)", flush=True)
            return content
        print(f"[FS] Version v{version} not found for page {page_id[:8]}...", flush=True)
        return None

    def list_versions(self, page_id: str) -> List[int]:
        """List all version numbers for a page."""
        version_dir = self.versions_dir / page_id
        if not version_dir.exists():
            return []

        versions = []
        for f in version_dir.glob("v*.html"):
            try:
                v = int(f.stem[1:])  # Remove 'v' prefix
                versions.append(v)
            except ValueError:
                pass

        return sorted(versions)

    def delete_versions(self, page_id: str) -> int:
        """Delete all versions for a page."""
        version_dir = self.versions_dir / page_id
        if version_dir.exists():
            count = len(list(version_dir.glob("v*.html")))
            shutil.rmtree(version_dir)
            return count
        return 0

    # ==========================================
    # Git Operations
    # ==========================================

    def _run_git(self, *args) -> tuple[int, str, str]:
        """Run a git command in project directory."""
        try:
            result = subprocess.run(
                ["git"] + list(args),
                cwd=self.base_dir,
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "Git command timed out"
        except Exception as e:
            return -1, "", str(e)

    def git_commit(self, message: str) -> dict:
        """Stage all changes and commit."""
        self._run_git("add", ".")
        code, stdout, stderr = self._run_git("commit", "-m", message)
        if code == 0:
            print(f"[FS] Git commit: {message}", flush=True)
        else:
            print(f"[FS] Git commit failed: {stderr}", flush=True)
        return {
            "success": code == 0,
            "message": message,
            "output": stdout or stderr
        }

    def git_log(self, limit: int = 10) -> List[dict]:
        """Get git commit history."""
        code, stdout, stderr = self._run_git(
            "log",
            f"-{limit}",
            "--pretty=format:%H|%s|%ai"
        )

        if code != 0:
            return []

        commits = []
        for line in stdout.strip().split("\n"):
            if line:
                parts = line.split("|")
                if len(parts) >= 3:
                    commits.append({
                        "hash": parts[0],
                        "message": parts[1],
                        "date": parts[2]
                    })
        return commits

    def clone_repo(self, github_url: str) -> dict:
        """Clone a GitHub repository."""
        print(f"[FS] Cloning {github_url} to {self.base_dir}", flush=True)

        # Remove existing directory if it exists
        if self.base_dir.exists():
            shutil.rmtree(self.base_dir)
            print(f"[FS] Removed existing directory", flush=True)

        # Clone
        self.base_dir.parent.mkdir(parents=True, exist_ok=True)
        print(f"[FS] Running git clone...", flush=True)
        result = subprocess.run(
            ["git", "clone", github_url, str(self.base_dir)],
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            print(f"[FS] Clone failed: {result.stderr}", flush=True)
            return {
                "success": False,
                "error": result.stderr
            }

        # Create .apex directory for versions
        self.versions_dir.mkdir(parents=True, exist_ok=True)

        # Update .gitignore to include .apex
        gitignore_path = self.base_dir / ".gitignore"
        gitignore_content = ""
        if gitignore_path.exists():
            gitignore_content = gitignore_path.read_text()

        if ".apex/" not in gitignore_content:
            with gitignore_path.open("a") as f:
                f.write("\n# Apex internal\n.apex/\n")

        file_count = len(list(self.base_dir.rglob("*")))
        print(f"[FS] Clone successful! {file_count} files", flush=True)

        return {
            "success": True,
            "path": str(self.base_dir),
            "files": file_count
        }

    def git_push(self, remote: str = "origin", branch: str = "main") -> dict:
        """Push changes to remote."""
        code, stdout, stderr = self._run_git("push", remote, branch)
        return {
            "success": code == 0,
            "output": stdout or stderr
        }

    # ==========================================
    # Deploy Helpers
    # ==========================================

    def get_deployable_path(self) -> Path:
        """Get path to deployable directory."""
        return self.public_dir

    def get_all_public_files(self) -> List[dict]:
        """Get all files in public directory for deployment."""
        if not self.public_dir.exists():
            return []

        files = []
        for path in self.public_dir.rglob("*"):
            if path.is_file():
                files.append({
                    "path": str(path.relative_to(self.public_dir)),
                    "full_path": str(path),
                    "size": path.stat().st_size
                })
        return files


# ==============================================================================
# Daytona Sandbox Filesystem
# ==============================================================================

class DaytonaFileSystemService:
    """Filesystem service backed by a Daytona sandbox.

    Same public interface as FileSystemService, but all operations go
    through the Daytona sandbox.fs / sandbox.git / sandbox.process APIs.
    """

    def __init__(self, project_id: str, sandbox_id: str):
        self.project_id = project_id
        self.sandbox_id = sandbox_id
        self._sandbox = None
        # Path constants inside the sandbox
        self.workspace = "/workspace"

    @property
    def sandbox(self):
        """Lazy-load sandbox connection."""
        if self._sandbox is None:
            from apex_server.integrations.daytona_service import daytona_service
            self._sandbox = daytona_service.get_sandbox(self.project_id, self.sandbox_id)
        return self._sandbox

    # ==========================================
    # Project Initialization
    # ==========================================

    def init_project(self) -> dict:
        """Initialize project directory structure in sandbox."""
        logger.info("[DAYTONA-FS] Initializing project %s", self.project_id)

        for path in [
            f"{self.workspace}/public/images",
            f"{self.workspace}/.apex/versions",
            f"{self.workspace}/src",
        ]:
            try:
                self.sandbox.fs.create_folder(path, mode="755")
            except Exception:
                pass

        gitignore = ".apex/\n.env\n__pycache__/\n*.pyc\nnode_modules/\n.DS_Store\n"
        self.sandbox.fs.upload_file(gitignore.encode("utf-8"), f"{self.workspace}/.gitignore")

        return {
            "project_id": self.project_id,
            "path": self.workspace,
            "initialized": True,
            "backend": "daytona",
        }

    def delete_project(self) -> bool:
        """Delete project by deleting sandbox."""
        from apex_server.integrations.daytona_service import daytona_service
        try:
            daytona_service.delete_sandbox(self.project_id, self.sandbox_id)
            return True
        except Exception:
            return False

    # ==========================================
    # File Operations
    # ==========================================

    def read_file(self, path: str) -> Optional[str]:
        """Read file content. Path relative to workspace root."""
        full_path = f"{self.workspace}/{path}"
        try:
            data = self.sandbox.fs.download_file(full_path)
            if data is None:
                logger.info("[DAYTONA-FS] File not found: %s", path)
                return None
            content = data.decode("utf-8")
            logger.info("[DAYTONA-FS] Read %s (%d bytes)", path, len(content))
            return content
        except UnicodeDecodeError:
            logger.warning("[DAYTONA-FS] File %s is not valid UTF-8 text", path)
            return None
        except Exception:
            logger.warning("[DAYTONA-FS] Failed to read %s", path, exc_info=True)
            return None

    def read_binary(self, path: str) -> Optional[bytes]:
        """Read binary file content."""
        full_path = f"{self.workspace}/{path}"
        try:
            return self.sandbox.fs.download_file(full_path)
        except Exception:
            return None

    def write_file(self, path: str, content: str) -> dict:
        """Write file content. Creates parent directories if needed."""
        full_path = f"{self.workspace}/{path}"
        parent = "/".join(full_path.split("/")[:-1])
        try:
            self.sandbox.fs.create_folder(parent, mode="755")
        except Exception:
            pass
        # upload_file treats str as local file path — must encode to bytes
        self.sandbox.fs.upload_file(content.encode("utf-8"), full_path)
        logger.info("[DAYTONA-FS] Wrote %s (%d bytes)", path, len(content))
        return {"path": path, "size": len(content), "written": True}

    def write_binary(self, path: str, data: bytes) -> dict:
        """Write binary file (images, etc)."""
        full_path = f"{self.workspace}/{path}"
        parent = "/".join(full_path.split("/")[:-1])
        try:
            self.sandbox.fs.create_folder(parent, mode="755")
        except Exception:
            pass
        self.sandbox.fs.upload_file(data, full_path)
        logger.info("[DAYTONA-FS] Wrote binary %s (%d bytes)", path, len(data))
        return {"path": path, "size": len(data), "written": True}

    def delete_file(self, path: str) -> bool:
        full_path = f"{self.workspace}/{path}"
        try:
            self.sandbox.fs.delete_file(full_path)
            return True
        except Exception:
            return False

    def list_files(self, directory: str = "") -> List[dict]:
        dir_path = f"{self.workspace}/{directory}" if directory else self.workspace
        try:
            entries = self.sandbox.fs.list_files(dir_path)
            files = []
            for entry in entries:
                name = entry.name
                if name.startswith(".") and name != ".gitignore":
                    continue
                files.append({
                    "name": name,
                    "path": f"{directory}/{name}" if directory else name,
                    "is_dir": entry.is_dir,
                    "size": entry.size,
                })
            return sorted(files, key=lambda x: (not x["is_dir"], x["name"]))
        except Exception:
            logger.warning("[DAYTONA-FS] Failed to list %s", dir_path, exc_info=True)
            return []

    def file_exists(self, path: str) -> bool:
        """Check if file exists (works for both text and binary files)."""
        full_path = f"{self.workspace}/{path}"
        try:
            self.sandbox.fs.get_file_info(full_path)
            return True
        except Exception:
            return False

    # ==========================================
    # Pipeline File Operations (.apex/)
    # ==========================================

    def write_pipeline_file(self, filename: str, content: str) -> dict:
        return self.write_file(f".apex/{filename}", content)

    def read_pipeline_file(self, filename: str) -> Optional[str]:
        return self.read_file(f".apex/{filename}")

    # ==========================================
    # Page HTML Operations
    # ==========================================

    def write_page_html(self, page_id: str, html: str, file_name: str = "index.html") -> dict:
        return self.write_file(f"public/{file_name}", html)

    def read_page_html(self, file_name: str = "index.html") -> Optional[str]:
        return self.read_file(f"public/{file_name}")

    # ==========================================
    # Version Operations
    # ==========================================

    def save_version(self, page_id: str, version: int, html: str) -> dict:
        version_path = f".apex/versions/{page_id}/v{version}.html"
        self.write_file(version_path, html)
        logger.info("[DAYTONA-FS] Saved version v%d for page %s...", version, page_id[:8])
        return {
            "page_id": page_id,
            "version": version,
            "path": version_path,
            "size": len(html),
        }

    def get_version(self, page_id: str, version: int) -> Optional[str]:
        version_path = f".apex/versions/{page_id}/v{version}.html"
        content = self.read_file(version_path)
        if content:
            logger.info("[DAYTONA-FS] Read version v%d for page %s...", version, page_id[:8])
        else:
            logger.info("[DAYTONA-FS] Version v%d not found for page %s...", version, page_id[:8])
        return content

    def list_versions(self, page_id: str) -> List[int]:
        dir_path = f"{self.workspace}/.apex/versions/{page_id}"
        try:
            entries = self.sandbox.fs.list_files(dir_path)
            versions = []
            for entry in entries:
                name = entry.name
                if name.startswith("v") and name.endswith(".html"):
                    try:
                        v = int(name[1:].replace(".html", ""))
                        versions.append(v)
                    except ValueError:
                        pass
            return sorted(versions)
        except Exception:
            logger.debug("[DAYTONA-FS] No versions found for page %s", page_id[:8])
            return []

    def delete_versions(self, page_id: str) -> int:
        versions = self.list_versions(page_id)
        dir_path = f"{self.workspace}/.apex/versions/{page_id}"
        try:
            self.sandbox.fs.delete_file(dir_path, recursive=True)
        except Exception:
            pass
        return len(versions)

    # ==========================================
    # Git Operations
    # ==========================================

    def git_commit(self, message: str) -> dict:
        try:
            self.sandbox.process.exec("git add .", cwd=self.workspace)
            response = self.sandbox.process.exec(
                f'git commit -m "{message}"', cwd=self.workspace
            )
            success = response.exit_code == 0
            logger.info("[DAYTONA-FS] Git commit: %s (success=%s)", message, success)
            return {
                "success": success,
                "message": message,
                "output": response.result,
            }
        except Exception as e:
            logger.error("[DAYTONA-FS] Git commit failed: %s", e)
            return {"success": False, "message": message, "output": str(e)}

    def git_log(self, limit: int = 10) -> List[dict]:
        try:
            response = self.sandbox.process.exec(
                f'git log -{limit} --pretty=format:"%H|%s|%ai"',
                cwd=self.workspace,
            )
            if response.exit_code != 0:
                return []
            commits = []
            for line in response.result.strip().split("\n"):
                if line:
                    parts = line.strip('"').split("|")
                    if len(parts) >= 3:
                        commits.append({
                            "hash": parts[0],
                            "message": parts[1],
                            "date": parts[2],
                        })
            return commits
        except Exception:
            return []

    def clone_repo(self, github_url: str) -> dict:
        from apex_server.integrations.daytona_service import daytona_service
        return daytona_service.clone_repo(self.project_id, self.sandbox_id, github_url)

    def git_push(self, remote: str = "origin", branch: str = "main") -> dict:
        try:
            response = self.sandbox.process.exec(
                f"git push {remote} {branch}", cwd=self.workspace
            )
            return {"success": response.exit_code == 0, "output": response.result}
        except Exception as e:
            return {"success": False, "output": str(e)}

    # ==========================================
    # Deploy Helpers
    # ==========================================

    def get_deployable_path(self) -> str:
        """Returns the sandbox public directory path."""
        return f"{self.workspace}/public"

    def get_all_public_files(self) -> List[dict]:
        try:
            entries = self.sandbox.fs.list_files(f"{self.workspace}/public")
            files = []
            for entry in entries:
                if not entry.is_dir:
                    files.append({
                        "path": entry.name,
                        "full_path": f"{self.workspace}/public/{entry.name}",
                        "size": entry.size,
                    })
            return files
        except Exception:
            logger.warning("[DAYTONA-FS] Failed to list public files", exc_info=True)
            return []

    # ==========================================
    # Sandbox-Specific Operations (NEW)
    # ==========================================

    def exec_command(self, command: str, cwd: str = "/workspace") -> dict:
        """Execute a shell command inside the sandbox."""
        response = self.sandbox.process.exec(command, cwd=cwd)
        return {"exit_code": response.exit_code, "stdout": response.result}

    def get_preview_url(self, port: int = 8000) -> dict:
        """Get a public preview URL for a port in the sandbox."""
        preview = self.sandbox.get_preview_link(port)
        return {"url": preview.url, "token": preview.token}

    def start_http_server(self, port: int = 8000) -> dict:
        """Start a simple HTTP server in public/ for preview."""
        cmd = f"python -m http.server {port} --directory /workspace/public &"
        response = self.sandbox.process.exec(cmd, cwd=self.workspace)
        return {"exit_code": response.exit_code, "port": port}


# ==============================================================================
# Factory
# ==============================================================================

def get_filesystem(project_id: str, sandbox_id: str = None):
    """Return the appropriate filesystem backend.

    If sandbox_id is provided and Daytona is enabled, returns
    DaytonaFileSystemService. Otherwise, returns legacy FileSystemService.
    """
    if sandbox_id:
        from apex_server.integrations.daytona_service import daytona_service
        if daytona_service.is_available:
            return DaytonaFileSystemService(project_id, sandbox_id)

    return FileSystemService(project_id)
