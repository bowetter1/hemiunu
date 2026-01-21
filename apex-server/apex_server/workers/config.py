"""
Apex Workers Configuration - Worker AI Mappings and Prompts
"""
import os
from pathlib import Path
from typing import Optional

# Sökväg till prompts-mappen
PROMPTS_DIR = Path(__file__).parent / "prompts"

# === TILLGÄNGLIGA AI:er ===
# Mappar till API providers
AVAILABLE_PROVIDERS = {
    "claude": "anthropic",  # Claude Opus via Anthropic API
    "sonnet": "anthropic",  # Claude Sonnet via Anthropic API
    "gemini": "google",     # Gemini via Google AI API
}

# Model IDs per provider
MODEL_IDS = {
    "claude": "claude-opus-4-20250514",
    "sonnet": "claude-sonnet-4-20250514",
    "gemini": "gemini-2.0-flash-exp",
}

# === WORKER AI MAPPNING ===
# Vilken AI varje worker använder
# TODO: Aktivera Gemini när GOOGLE_API_KEY är konfigurerad
WORKER_AI = {
    "chef": "claude",      # Opus - orchestration
    "ad": "claude",        # Opus - visual review
    "architect": "claude", # Opus - planning
    "backend": "claude",   # Gemini - backend coding (using Claude for now)
    "frontend": "claude",  # Opus - frontend coding
    "tester": "claude",    # Gemini - test writing (using Claude for now)
    "reviewer": "claude",  # Gemini - code review (using Claude for now)
    "devops": "claude",    # Opus - deploy
}

# === ROLLER ===
ALL_ROLES = ["chef", "ad", "architect", "backend", "frontend", "tester", "reviewer", "devops"]

ROLE_NAMES = {
    "chef": "Chef",
    "ad": "AD",
    "architect": "Architect",
    "backend": "Backend",
    "frontend": "Frontend",
    "tester": "Tester",
    "reviewer": "Reviewer",
    "devops": "DevOps",
}

# Role icons for logging
ROLE_ICONS = {
    "chef": "👨‍🍳",
    "ad": "🎨",
    "architect": "🏗️",
    "backend": "⚙️",
    "frontend": "🖼️",
    "tester": "🧪",
    "reviewer": "🔍",
    "devops": "🚀",
}


def get_worker_ai(worker: str, override: Optional[str] = None) -> str:
    """Get AI type for a worker."""
    if override and override in AVAILABLE_PROVIDERS:
        return override
    return WORKER_AI.get(worker, "sonnet")


def get_model_id(ai_type: str) -> str:
    """Get the model ID for an AI type."""
    return MODEL_IDS.get(ai_type, MODEL_IDS["sonnet"])


def get_provider(ai_type: str) -> str:
    """Get the API provider for an AI type."""
    return AVAILABLE_PROVIDERS.get(ai_type, "anthropic")


def _load_prompt(filename: str) -> str:
    """Load a prompt from the prompts folder."""
    path = PROMPTS_DIR / filename
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def get_base_prompt() -> str:
    """Get the shared base prompt."""
    return _load_prompt("_base.md")


def get_chef_prompt(task: str, project_dir: str = "") -> str:
    """Get Chef prompt with task substitution."""
    template = _load_prompt("chef.md")
    # Use replace instead of format() to avoid issues with curly braces in examples
    prompt = template.replace("{task}", task)
    if project_dir:
        prompt += f"\n\nPROJEKTMAPP: {project_dir}"
    return prompt


def get_worker_prompt(role: str, **kwargs) -> str:
    """Get prompt for a specific worker role.

    Args:
        role: Worker role (ad, architect, backend, frontend, tester, reviewer, devops)
        **kwargs: Variables to substitute in the prompt template

    Returns:
        The formatted prompt string
    """
    # Load base + role-specific prompt
    base = get_base_prompt()
    role_template = _load_prompt(f"{role}.md")

    # Substitute variables using replace() to avoid issues with curly braces in examples
    # Default empty strings for optional variables
    defaults = {
        "task": "",
        "context": "",
        "file": "",
        "files": "",
        "focus": "",
        "project_dir": "",
    }
    defaults.update(kwargs)

    # Use replace instead of format() to avoid KeyError on curly braces in examples
    role_prompt = role_template
    for key, value in defaults.items():
        role_prompt = role_prompt.replace(f"{{{key}}}", str(value))

    return f"{base}\n\n---\n\n{role_prompt}"
