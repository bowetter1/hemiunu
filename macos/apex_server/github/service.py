"""GitHub service for repo management"""
import subprocess
from pathlib import Path
from typing import Optional
import httpx

from apex_server.config import get_settings

settings = get_settings()


class GitHubService:
    """Service for GitHub operations"""

    def __init__(self, project_dir: Path):
        self.project_dir = project_dir
        self.token = settings.github_token
        self.org = settings.github_org
        self.api_base = "https://api.github.com"

    def _run_git(self, *args, check: bool = True) -> subprocess.CompletedProcess:
        """Run a git command in the project directory"""
        return subprocess.run(
            ["git"] + list(args),
            cwd=self.project_dir,
            capture_output=True,
            text=True,
            check=check
        )

    def _api_request(self, method: str, endpoint: str, json: dict = None) -> httpx.Response:
        """Make an authenticated API request to GitHub"""
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28"
        }
        url = f"{self.api_base}{endpoint}"
        return httpx.request(method, url, headers=headers, json=json, timeout=30.0)

    def is_configured(self) -> bool:
        """Check if GitHub is configured"""
        return bool(self.token)

    def init_repo(self) -> str:
        """Initialize a git repository in the project directory"""
        if not self.project_dir.exists():
            return "Error: Project directory does not exist"

        git_dir = self.project_dir / ".git"
        if git_dir.exists():
            return "Git repository already initialized"

        try:
            self._run_git("init")
            self._run_git("config", "user.email", "apex@apex-server.local")
            self._run_git("config", "user.name", "Apex AI Team")
            return "Git repository initialized"
        except subprocess.CalledProcessError as e:
            return f"Error initializing git: {e.stderr}"

    def create_gitignore(self) -> str:
        """Create a basic .gitignore file"""
        gitignore_content = """# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
.venv/
ENV/
env/

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local
*.local

# Build
dist/
build/
*.egg-info/

# Logs
*.log
logs/

# Node
node_modules/
"""
        gitignore_path = self.project_dir / ".gitignore"
        gitignore_path.write_text(gitignore_content)
        return "Created .gitignore"

    def add_and_commit(self, message: str) -> str:
        """Add all files and create a commit"""
        try:
            # Create .gitignore if it doesn't exist
            if not (self.project_dir / ".gitignore").exists():
                self.create_gitignore()

            # Add all files
            self._run_git("add", "-A")

            # Check if there are changes to commit
            status = self._run_git("status", "--porcelain", check=False)
            if not status.stdout.strip():
                return "No changes to commit"

            # Commit
            self._run_git("commit", "-m", message)
            return f"Committed: {message}"
        except subprocess.CalledProcessError as e:
            return f"Error committing: {e.stderr}"

    def create_github_repo(self, name: str, description: str = "", private: bool = True) -> dict:
        """Create a new GitHub repository"""
        if not self.is_configured():
            return {"success": False, "error": "GitHub token not configured"}

        # Determine if creating in org or user account
        if self.org:
            endpoint = f"/orgs/{self.org}/repos"
        else:
            endpoint = "/user/repos"

        payload = {
            "name": name,
            "description": description,
            "private": private,
            "auto_init": False  # We'll push our own code
        }

        try:
            response = self._api_request("POST", endpoint, json=payload)

            if response.status_code == 201:
                data = response.json()
                return {
                    "success": True,
                    "url": data["html_url"],
                    "clone_url": data["clone_url"],
                    "ssh_url": data["ssh_url"]
                }
            elif response.status_code == 422:
                # Repo might already exist
                return {"success": False, "error": "Repository already exists or invalid name"}
            else:
                return {"success": False, "error": f"GitHub API error: {response.status_code} - {response.text}"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    def add_remote(self, repo_url: str, remote_name: str = "origin") -> str:
        """Add a remote to the git repository"""
        try:
            # Check if remote already exists
            result = self._run_git("remote", "get-url", remote_name, check=False)
            if result.returncode == 0:
                # Remote exists, update it
                self._run_git("remote", "set-url", remote_name, repo_url)
                return f"Updated remote '{remote_name}' to {repo_url}"
            else:
                # Add new remote
                self._run_git("remote", "add", remote_name, repo_url)
                return f"Added remote '{remote_name}': {repo_url}"
        except subprocess.CalledProcessError as e:
            return f"Error adding remote: {e.stderr}"

    def _run_git_with_auth(self, *args, check: bool = True) -> subprocess.CompletedProcess:
        """Run a git command with token authentication via environment variable.

        This avoids exposing the token in command-line arguments (visible in ps, logs, etc.)
        by using GIT_ASKPASS with a script that returns the token.
        """
        import os
        import tempfile

        # Create a temporary script that outputs the token
        # This is more secure than embedding token in URL
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
            f.write(f'#!/bin/sh\necho "{self.token}"\n')
            askpass_script = f.name

        try:
            os.chmod(askpass_script, 0o700)

            env = os.environ.copy()
            env['GIT_ASKPASS'] = askpass_script
            env['GIT_TERMINAL_PROMPT'] = '0'  # Disable interactive prompts

            return subprocess.run(
                ["git"] + list(args),
                cwd=self.project_dir,
                capture_output=True,
                text=True,
                check=check,
                env=env
            )
        finally:
            # Always clean up the temporary script
            try:
                os.unlink(askpass_script)
            except OSError:
                pass

    def push(self, remote: str = "origin", branch: str = "main") -> str:
        """Push to remote repository using secure token handling."""
        if not self.is_configured():
            return "Error: GitHub token not configured"

        try:
            # Ensure we're on the right branch
            self._run_git("branch", "-M", branch, check=False)

            # Check remote exists
            result = self._run_git("remote", "get-url", remote, check=False)
            if result.returncode != 0:
                return "Error: Remote not configured"

            remote_url = result.stdout.strip()

            # For HTTPS URLs, use authenticated push via GIT_ASKPASS
            if remote_url.startswith("https://"):
                # Ensure URL uses username format for token auth
                if "@" not in remote_url:
                    # Convert https://github.com/... to https://oauth2@github.com/...
                    auth_url = remote_url.replace("https://", "https://oauth2@")
                    self._run_git("remote", "set-url", remote, auth_url)

                self._run_git_with_auth("push", "-u", remote, branch)
            else:
                # SSH URL - just push normally
                self._run_git("push", "-u", remote, branch)

            return f"Pushed to {remote}/{branch}"
        except subprocess.CalledProcessError as e:
            return f"Error pushing: {e.stderr}"

    def setup_and_push(self, repo_name: str, description: str = "") -> dict:
        """Complete flow: init, create repo, commit, and push"""
        results = []

        # Initialize git
        init_result = self.init_repo()
        results.append(init_result)

        # Create initial commit
        commit_result = self.add_and_commit("Initial commit from Apex AI Team")
        results.append(commit_result)

        # Create GitHub repo
        if not self.is_configured():
            return {
                "success": False,
                "error": "GitHub token not configured",
                "steps": results
            }

        repo_result = self.create_github_repo(repo_name, description, private=True)
        if not repo_result["success"]:
            return {
                "success": False,
                "error": repo_result["error"],
                "steps": results
            }

        results.append(f"Created repo: {repo_result['url']}")

        # Add remote
        remote_result = self.add_remote(repo_result["clone_url"])
        results.append(remote_result)

        # Push
        push_result = self.push()
        results.append(push_result)

        return {
            "success": True,
            "url": repo_result["url"],
            "clone_url": repo_result["clone_url"],
            "steps": results
        }

    def get_status(self) -> str:
        """Get git status"""
        try:
            result = self._run_git("status", "--short", check=False)
            if result.returncode != 0:
                return "Not a git repository"
            return result.stdout or "Clean working tree"
        except Exception as e:
            return f"Error: {e}"
