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
    "opus": "anthropic",   # Claude Opus 4.5 via Anthropic API
    "haiku": "anthropic",  # Claude Haiku 4.5 via Anthropic API
    "sonnet": "anthropic", # Claude Sonnet via Anthropic API
    "gemini": "google",    # Gemini via Google AI API
}

# Model IDs per provider
MODEL_IDS = {
    "opus": "claude-opus-4-5-20251101",    # Opus 4.5 - $5/$25 per M
    "haiku": "claude-haiku-4-5-20251101",  # Haiku 4.5 - $1/$5 per M
    "sonnet": "claude-sonnet-4-20250514",
    "gemini": "gemini-2.0-flash-exp",
}

# === WORKER AI MAPPNING ===
# Chef uses Opus (smart orchestration), workers use Haiku (cheap & fast)
WORKER_AI = {
    "chef": "opus",        # Opus 4.5 - orchestration needs smarts
    "ad": "haiku",         # Haiku 4.5 - design guidelines
    "architect": "haiku",  # Haiku 4.5 - planning
    "backend": "haiku",    # Haiku 4.5 - backend coding
    "frontend": "haiku",   # Haiku 4.5 - frontend coding
    "tester": "haiku",     # Haiku 4.5 - test writing
    "reviewer": "haiku",   # Haiku 4.5 - code review
    "devops": "haiku",     # Haiku 4.5 - deploy
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
    return WORKER_AI.get(worker, "haiku")


# Pricing per million tokens (USD)
MODEL_PRICING = {
    "opus": {"input": 5.0, "output": 25.0},      # Opus 4.5
    "haiku": {"input": 1.0, "output": 5.0},      # Haiku 4.5
    "sonnet": {"input": 3.0, "output": 15.0},    # Sonnet 4
    "gemini": {"input": 0.0, "output": 0.0},     # Free tier
}


def calculate_cost(ai_type: str, input_tokens: int, output_tokens: int) -> float:
    """Calculate cost in USD for token usage."""
    pricing = MODEL_PRICING.get(ai_type, MODEL_PRICING["haiku"])
    input_cost = input_tokens * pricing["input"] / 1_000_000
    output_cost = output_tokens * pricing["output"] / 1_000_000
    return input_cost + output_cost


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
