"""
Claude API Client.
"""
import os
from pathlib import Path
from dotenv import load_dotenv
from anthropic import Anthropic

# Ladda .env från projekt-root
_project_root = Path(__file__).parent.parent.parent
load_dotenv(_project_root / ".env")

# Konfiguration
DEFAULT_MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 4096

# Singleton client
_client = None


def get_client() -> Anthropic:
    """Hämta eller skapa Anthropic-klient."""
    global _client
    if _client is None:
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY saknas i environment")
        _client = Anthropic(api_key=api_key)
    return _client


def call_claude(
    messages: list,
    system: str,
    tools: list = None,
    model: str = DEFAULT_MODEL,
    max_tokens: int = MAX_TOKENS
) -> dict:
    """
    Anropa Claude API.

    Args:
        messages: Konversationshistorik
        system: System-prompt
        tools: Lista med tool-definitioner
        model: Modell att använda
        max_tokens: Max tokens i svar

    Returns:
        dict med {content, stop_reason, tool_calls}
    """
    client = get_client()

    kwargs = {
        "model": model,
        "max_tokens": max_tokens,
        "system": system,
        "messages": messages
    }

    if tools:
        kwargs["tools"] = tools

    response = client.messages.create(**kwargs)

    # Parsa svar
    result = {
        "content": [],  # Full content för assistant message
        "text": None,   # Bara text-delen (convenience)
        "stop_reason": response.stop_reason,
        "tool_calls": [],
        # Token-användning
        "usage": {
            "input_tokens": response.usage.input_tokens,
            "output_tokens": response.usage.output_tokens,
        }
    }

    for block in response.content:
        if block.type == "text":
            result["content"].append({"type": "text", "text": block.text})
            result["text"] = block.text
        elif block.type == "tool_use":
            result["content"].append({
                "type": "tool_use",
                "id": block.id,
                "name": block.name,
                "input": block.input
            })
            result["tool_calls"].append({
                "id": block.id,
                "name": block.name,
                "arguments": block.input
            })

    return result
