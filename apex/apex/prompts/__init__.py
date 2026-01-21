"""
Prompt loader - laddar prompts från markdown-filer
"""
from pathlib import Path

PROMPTS_DIR = Path(__file__).parent


def load_prompt(role: str, **kwargs) -> str:
    """
    Ladda och formatera en prompt för en roll.

    Args:
        role: Rollnamn (ad, architect, backend, frontend, reviewer, tester, devops)
        **kwargs: Variabler att ersätta i prompten (task, context, file, files, focus)

    Returns:
        Formaterad prompt-sträng
    """
    # Ladda base-prompt
    base_file = PROMPTS_DIR / "_base.md"
    base_content = base_file.read_text(encoding="utf-8") if base_file.exists() else ""

    # Ladda roll-specifik prompt
    role_file = PROMPTS_DIR / f"{role}.md"
    if not role_file.exists():
        raise ValueError(f"Ingen prompt finns för roll: {role}")

    role_content = role_file.read_text(encoding="utf-8")

    # Kombinera och formatera
    full_prompt = base_content + "\n\n---\n\n" + role_content

    # Ersätt placeholders
    # Hantera optional context/file med tom sträng som default
    formatted = full_prompt
    for key, value in kwargs.items():
        placeholder = "{" + key + "}"
        if value:
            if key == "context":
                formatted = formatted.replace(placeholder, f"**Kontext:** {value}")
            elif key == "file":
                formatted = formatted.replace(placeholder, f"**Fil:** {value}")
            elif key == "files":
                formatted = formatted.replace(placeholder, value)
            elif key == "focus":
                formatted = formatted.replace(placeholder, value)
            else:
                formatted = formatted.replace(placeholder, str(value))
        else:
            formatted = formatted.replace(placeholder, "")

    # Lägg till feedback-instruktion
    return formatted.strip() + "\n\nVIKTIGT: Säg ifrån om uppdraget är oklart eller om du har en bättre idé."


def get_available_roles() -> list[str]:
    """Lista alla tillgängliga roller med prompts."""
    return [
        f.stem for f in PROMPTS_DIR.glob("*.md")
        if not f.name.startswith("_")
    ]
