"""
Prompt loader - loads prompts from markdown files
"""
from pathlib import Path

PROMPTS_DIR = Path(__file__).parent


def load_prompt(role: str, **kwargs) -> str:
    """
    Load and format a prompt for a role.

    Args:
        role: Role name (ad, architect, backend, frontend, reviewer, tester, devops, security)
        **kwargs: Variables to replace in prompt (task, context, file, files, focus)

    Returns:
        Formatted prompt string
    """
    # Load base prompt
    base_file = PROMPTS_DIR / "_base.md"
    base_content = base_file.read_text(encoding="utf-8") if base_file.exists() else ""

    # Load role-specific prompt
    role_file = PROMPTS_DIR / f"{role}.md"
    if not role_file.exists():
        raise ValueError(f"No prompt exists for role: {role}")

    role_content = role_file.read_text(encoding="utf-8")

    # Combine and format
    full_prompt = base_content + "\n\n---\n\n" + role_content

    # Replace placeholders
    # Handle optional context/file with empty string as default
    formatted = full_prompt
    for key, value in kwargs.items():
        placeholder = "{" + key + "}"
        if value:
            if key == "context":
                formatted = formatted.replace(placeholder, f"**Context:** {value}")
            elif key == "file":
                formatted = formatted.replace(placeholder, f"**File:** {value}")
            elif key == "files":
                formatted = formatted.replace(placeholder, value)
            elif key == "focus":
                formatted = formatted.replace(placeholder, value)
            else:
                formatted = formatted.replace(placeholder, str(value))
        else:
            formatted = formatted.replace(placeholder, "")

    # Add feedback instruction
    return formatted.strip() + "\n\nIMPORTANT: Speak up if the task is unclear or if you have a better idea."


def get_available_roles() -> list[str]:
    """List all available roles with prompts."""
    return [
        f.stem for f in PROMPTS_DIR.glob("*.md")
        if not f.name.startswith("_")
    ]
