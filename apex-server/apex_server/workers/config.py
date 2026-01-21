"""
Apex Workers Configuration - Worker AI Mappings and Prompts
"""
import os
from pathlib import Path
from typing import Optional

# Sökväg till prompts-mappen
PROMPTS_DIR = Path(__file__).parent / "prompts"

# =============================================================================
# MODELLER - Alla tillgängliga AI-modeller
# =============================================================================
MODELS = {
    "opus": {
        "id": "claude-opus-4-5-20251101",
        "provider": "anthropic",
        "input_price": 5.0,    # $ per M tokens
        "output_price": 25.0,  # $ per M tokens
    },
    "sonnet": {
        "id": "claude-sonnet-4-20250514",
        "provider": "anthropic",
        "input_price": 3.0,
        "output_price": 15.0,
    },
    "haiku": {
        "id": "claude-haiku-4-5-20251101",
        "provider": "anthropic",
        "input_price": 1.0,
        "output_price": 5.0,
    },
    "gemini": {
        "id": "gemini-2.0-flash-exp",
        "provider": "google",
        "input_price": 0.0,
        "output_price": 0.0,
    },
}

# =============================================================================
# ROLLER - Alla workers med namn, ikon och default-modell
# =============================================================================
ROLES = {
    "chef":      {"name": "Chef",      "icon": "👨‍🍳", "model": "opus"},
    "ad":        {"name": "AD",        "icon": "🎨",  "model": "haiku"},
    "architect": {"name": "Architect", "icon": "🏗️",  "model": "haiku"},
    "backend":   {"name": "Backend",   "icon": "⚙️",  "model": "haiku"},
    "frontend":  {"name": "Frontend",  "icon": "🖼️",  "model": "haiku"},
    "tester":    {"name": "Tester",    "icon": "🧪",  "model": "haiku"},
    "reviewer":  {"name": "Reviewer",  "icon": "🔍",  "model": "haiku"},
    "devops":    {"name": "DevOps",    "icon": "🚀",  "model": "haiku"},
}

# =============================================================================
# HELPER DICTS (för bakåtkompatibilitet)
# =============================================================================
ALL_ROLES = list(ROLES.keys())
ROLE_NAMES = {k: v["name"] for k, v in ROLES.items()}
ROLE_ICONS = {k: v["icon"] for k, v in ROLES.items()}
WORKER_AI = {k: v["model"] for k, v in ROLES.items()}

# Legacy dicts
AVAILABLE_PROVIDERS = {k: v["provider"] for k, v in MODELS.items()}
MODEL_IDS = {k: v["id"] for k, v in MODELS.items()}
MODEL_PRICING = {k: {"input": v["input_price"], "output": v["output_price"]} for k, v in MODELS.items()}


def get_worker_ai(worker: str, override: Optional[str] = None) -> str:
    """Get AI type for a worker. Checks env var APEX_MODEL_{WORKER} first."""
    if override and override in MODELS:
        return override
    # Check environment variable, e.g. APEX_MODEL_CHEF=sonnet
    env_key = f"APEX_MODEL_{worker.upper()}"
    env_model = os.environ.get(env_key)
    if env_model and env_model in MODELS:
        return env_model
    return ROLES.get(worker, {}).get("model", "haiku")


def calculate_cost(ai_type: str, input_tokens: int, output_tokens: int) -> float:
    """Calculate cost in USD for token usage."""
    model = MODELS.get(ai_type, MODELS["haiku"])
    input_cost = input_tokens * model["input_price"] / 1_000_000
    output_cost = output_tokens * model["output_price"] / 1_000_000
    return input_cost + output_cost


def get_model_id(ai_type: str) -> str:
    """Get the model ID for an AI type."""
    return MODELS.get(ai_type, MODELS["sonnet"])["id"]


def get_provider(ai_type: str) -> str:
    """Get the API provider for an AI type."""
    return MODELS.get(ai_type, MODELS["haiku"])["provider"]


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
