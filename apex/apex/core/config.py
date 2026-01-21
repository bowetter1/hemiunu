#!/usr/bin/env python3
"""
Apex Configuration - Single Source of Truth
"""
import os

# Sökväg till prompts-mappen
PROMPTS_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "prompts")

# === TILLGÄNGLIGA AI:er ===
AVAILABLE_AIS = ["claude", "sonnet", "gemini"]

# === WORKER CLI MAPPNING ===
WORKER_CLI = {
    "chef": "claude",      # Opus - orchestration
    "ad": "gemini",        # Gemini - design (faster)
    "architect": "claude", # Opus - planning
    "backend": "gemini",   # Gemini - backend coding
    "frontend": "gemini",  # Gemini - frontend coding (faster)
    "tester": "claude",    # Opus - test writing (more reliable)
    "reviewer": "gemini",  # Gemini - code review
    "security": "gemini",  # Gemini - security audit
    "devops": "claude",    # Opus - deploy
}

# === ROLLER ===
ALL_ROLES = ["chef", "ad", "architect", "backend", "frontend", "tester", "reviewer", "security", "devops"]

ROLE_NAMES = {
    "chef": "Chef",
    "ad": "AD",
    "architect": "Architect",
    "backend": "Backend",
    "frontend": "Frontend",
    "tester": "Tester",
    "reviewer": "Reviewer",
    "security": "Security",
    "devops": "DevOps",
}

# === CLI FLAGGOR ===
CLI_FLAGS = {
    "claude": ["-p", "--dangerously-skip-permissions"],
    "sonnet": ["-p", "--dangerously-skip-permissions", "--model", "sonnet"],
    "gemini": ["-y"],
}


def get_worker_cli(worker: str, ai: str = None) -> str:
    """Hämta CLI för en worker."""
    if ai and ai in AVAILABLE_AIS:
        return ai
    return WORKER_CLI.get(worker, "sonnet")


def _load_prompt(filename: str) -> str:
    """Ladda en prompt från prompts-mappen."""
    path = os.path.join(PROMPTS_DIR, filename)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_chef_prompt(task: str) -> str:
    """Chef-prompt - laddas från prompts/chef.md."""
    template = _load_prompt("chef.md")
    return template.format(task=task)


def get_web_chef_prompt(task: str, cwd: str) -> str:
    """Chef-prompt för web med projektmapp."""
    base = get_chef_prompt(task)
    return base + f"""

PROJEKTMAPP: {cwd}

BROWSER (Playwright):
- mcp__playwright__browser_navigate(url)
- mcp__playwright__browser_snapshot()
- mcp__playwright__browser_take_screenshot()"""
