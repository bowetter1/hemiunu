"""Structured edit generator - Returns edit instructions instead of full HTML"""
from typing import Optional
from anthropic import Anthropic
from pydantic import BaseModel

from apex_server.config import get_settings

settings = get_settings()


class StyleChange(BaseModel):
    """A CSS style change"""
    property: str  # e.g., "fontSize", "color", "padding"
    value: str     # e.g., "4rem", "#3b82f6", "2rem 4rem"


class StructuredEdit(BaseModel):
    """A structured edit instruction"""
    action: str                    # "updateStyle", "updateText", "addClass", "removeClass", "delete", "wrap"
    selector: str                  # CSS selector, e.g., "h1.hero-title", "#main-cta"
    styles: Optional[list[StyleChange]] = None  # For style changes
    text: Optional[str] = None     # For text changes
    className: Optional[str] = None  # For class changes
    html: Optional[str] = None     # For complex replacements
    wrapWith: Optional[str] = None  # For wrap action


class StructuredEditResponse(BaseModel):
    """Response from structured edit endpoint"""
    edits: list[StructuredEdit]
    explanation: str  # What the AI did


def generate_structured_edit(
    html: str,
    instruction: str,
    moodboard: dict = None
) -> StructuredEditResponse:
    """
    Generate structured edit instructions instead of full HTML.
    Much more token-efficient!
    """
    client = Anthropic(api_key=settings.anthropic_api_key)

    # Define the tool for structured output
    edit_tool = {
        "name": "apply_edits",
        "description": "Apply structured edits to the HTML",
        "input_schema": {
            "type": "object",
            "properties": {
                "edits": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "action": {
                                "type": "string",
                                "enum": ["updateStyle", "updateText", "addClass", "removeClass", "delete", "replaceElement"],
                                "description": "Type of edit"
                            },
                            "selector": {
                                "type": "string",
                                "description": "CSS selector to target element(s)"
                            },
                            "styles": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "property": {"type": "string", "description": "CSS property in camelCase (fontSize, backgroundColor, etc.)"},
                                        "value": {"type": "string", "description": "CSS value"}
                                    },
                                    "required": ["property", "value"]
                                },
                                "description": "Style changes (for updateStyle action)"
                            },
                            "text": {
                                "type": "string",
                                "description": "New text content (for updateText action)"
                            },
                            "className": {
                                "type": "string",
                                "description": "Class name (for addClass/removeClass)"
                            },
                            "html": {
                                "type": "string",
                                "description": "Replacement HTML (for replaceElement, use sparingly)"
                            }
                        },
                        "required": ["action", "selector"]
                    }
                },
                "explanation": {
                    "type": "string",
                    "description": "Brief explanation of what changes were made"
                }
            },
            "required": ["edits", "explanation"]
        }
    }

    # Build context
    context = ""
    if moodboard:
        context = f"""
Design context:
- Colors: {', '.join(moodboard.get('palette', []))}
- Fonts: {moodboard.get('fonts', {})}
- Mood: {', '.join(moodboard.get('mood', []))}
"""

    print(f"[STRUCTURED-EDIT] Calling Claude with instruction: {instruction[:50]}...", flush=True)
    print(f"[STRUCTURED-EDIT] HTML length: {len(html)}", flush=True)

    response = client.messages.create(
        model="claude-opus-4-5-20251101",
        max_tokens=1000,  # Much smaller - we're just returning instructions
        tools=[edit_tool],
        tool_choice={"type": "tool", "name": "apply_edits"},
        system=f"""You are a web developer making precise edits to HTML.

{context}

IMPORTANT RULES:
1. Return STRUCTURED EDITS, not full HTML
2. Use CSS selectors to target elements precisely
3. Prefer updateStyle for visual changes
4. Prefer updateText for content changes
5. Use replaceElement ONLY if absolutely necessary
6. Keep edits minimal and precise

CSS selector tips:
- Use classes: ".hero-title", ".cta-button"
- Use IDs: "#main-heading"
- Use tag + class: "h1.title", "section.hero"
- Use hierarchy: ".hero h1", ".nav a"
""",
        messages=[
            {
                "role": "user",
                "content": f"""Current HTML structure (analyze but don't return it):

```html
{html}
```

User instruction: {instruction}

Return structured edits to make this change."""
            }
        ]
    )

    # Extract structured data from tool use
    print(f"[STRUCTURED-EDIT] Response blocks: {len(response.content)}", flush=True)
    for block in response.content:
        print(f"[STRUCTURED-EDIT] Block type: {block.type}", flush=True)
        if block.type == "tool_use" and block.name == "apply_edits":
            data = block.input
            edits = data.get("edits", [])
            print(f"[STRUCTURED-EDIT] Got {len(edits)} edits from Claude", flush=True)
            for i, edit in enumerate(edits):
                print(f"[STRUCTURED-EDIT]   Edit {i+1}: {edit.get('action')} on {edit.get('selector')}", flush=True)
            return StructuredEditResponse(
                edits=[StructuredEdit(**edit) for edit in edits],
                explanation=data.get("explanation", "")
            )

    # Fallback if something went wrong
    print(f"[STRUCTURED-EDIT] No tool_use block found!", flush=True)
    return StructuredEditResponse(edits=[], explanation="Could not generate edits")
