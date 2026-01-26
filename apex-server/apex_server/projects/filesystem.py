"""
Filesystem service for project files.

Projects are stored at: /data/projects/{project_id}/
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
import os
import shutil
import subprocess
from pathlib import Path
from typing import Optional, List
from datetime import datetime

from apex_server.config import get_settings

settings = get_settings()


class FileSystemService:
    """Service for managing project files on disk."""

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
