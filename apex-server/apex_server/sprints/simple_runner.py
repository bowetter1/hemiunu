"""Simple Sprint Runner - Just Opus, nothing fancy"""
import json
from pathlib import Path
from datetime import datetime

from sqlalchemy.orm import Session
from anthropic import Anthropic

from apex_server.config import get_settings
from .models import Sprint, SprintStatus, LogEntry, LogType
from .websocket import sprint_ws_manager

settings = get_settings()

SYSTEM_PROMPT = """Du är en expert webbutvecklare. Din uppgift är att bygga en komplett HTML-sida baserat på användarens beskrivning.

Du har tillgång till ett verktyg för att skriva filer. Skapa ENDAST:
- index.html (med ALL CSS inuti <style> taggen i <head>)

VIKTIGT: Lägg ALL CSS direkt i HTML-filen med <style> taggar. Skapa INTE separata .css filer.

Regler:
- Skriv ren, modern HTML5/CSS3
- ALL styling ska vara i <style> taggen inuti index.html
- Gör sidan responsiv med media queries
- Använd moderna CSS features (flexbox, grid, custom properties)
- Använd snygga färger och typografi
- Lägg till hover-effekter och transitions
- Använd svenska texter om inte annat anges

Exempel på struktur:
```html
<!DOCTYPE html>
<html lang="sv">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Min Sida</title>
    <style>
        /* ALL CSS HÄR */
    </style>
</head>
<body>
    <!-- Innehåll -->
</body>
</html>
```

När du är klar, skriv index.html och avsluta."""

TOOLS = [
    {
        "name": "write_file",
        "description": "Skriv en fil till projektmappen",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Filnamn (t.ex. index.html, style.css)"
                },
                "content": {
                    "type": "string",
                    "description": "Filinnehållet"
                }
            },
            "required": ["path", "content"]
        }
    }
]


class SimpleSprintRunner:
    """Minimal sprint runner - one Opus call builds everything"""

    def __init__(self, sprint: Sprint, db: Session):
        self.sprint = sprint
        self.db = db
        self.project_dir = Path(sprint.project_dir)
        self.client = Anthropic(api_key=settings.anthropic_api_key)

    def log(self, log_type: LogType, message: str, data: dict = None):
        """Log a message"""
        entry = LogEntry(
            sprint_id=self.sprint.id,
            log_type=log_type,
            message=message,
            worker="opus",
            data=json.dumps(data) if data else None
        )
        self.db.add(entry)
        self.db.commit()

        # Broadcast via WebSocket
        sprint_ws_manager.broadcast_sync(
            str(self.sprint.id),
            "log",
            {
                "id": entry.id,
                "log_type": log_type.value,
                "message": message,
                "worker": "opus",
                "timestamp": entry.timestamp.isoformat()
            }
        )

    def write_file(self, path: str, content: str):
        """Write a file to project directory"""
        file_path = self.project_dir / path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content)
        self.log(LogType.SUCCESS, f"Skrev {path}", {"path": path, "size": len(content)})
        return f"Skrev {path} ({len(content)} bytes)"

    def run(self):
        """Run the sprint"""
        self.sprint.status = SprintStatus.RUNNING
        self.sprint.started_at = datetime.utcnow()
        self.db.commit()

        self.log(LogType.PHASE, f"Startar: {self.sprint.task}")

        try:
            messages = [
                {"role": "user", "content": f"Bygg denna webbsida: {self.sprint.task}"}
            ]

            # Keep calling until done
            while True:
                self.log(LogType.THINKING, "Opus tänker...")

                response = self.client.messages.create(
                    model="claude-sonnet-4-20250514",
                    max_tokens=8192,
                    system=SYSTEM_PROMPT,
                    tools=TOOLS,
                    messages=messages
                )

                # Track tokens
                self.sprint.input_tokens += response.usage.input_tokens
                self.sprint.output_tokens += response.usage.output_tokens
                self.db.commit()

                # Process response
                assistant_content = []
                has_tool_use = False

                for block in response.content:
                    if block.type == "text":
                        if block.text.strip():
                            self.log(LogType.INFO, block.text[:200])
                        assistant_content.append(block)
                    elif block.type == "tool_use":
                        has_tool_use = True
                        assistant_content.append(block)

                        # Execute tool
                        if block.name == "write_file":
                            result = self.write_file(
                                block.input["path"],
                                block.input["content"]
                            )
                        else:
                            result = f"Unknown tool: {block.name}"

                        # Add tool result to continue conversation
                        messages.append({"role": "assistant", "content": assistant_content})
                        messages.append({
                            "role": "user",
                            "content": [{
                                "type": "tool_result",
                                "tool_use_id": block.id,
                                "content": result
                            }]
                        })
                        assistant_content = []

                # Check if done
                if response.stop_reason == "end_turn" and not has_tool_use:
                    break

                if not has_tool_use:
                    # No tools used, add response and break
                    if assistant_content:
                        messages.append({"role": "assistant", "content": assistant_content})
                    break

            # Done!
            self.sprint.status = SprintStatus.COMPLETED
            self.sprint.completed_at = datetime.utcnow()
            self.db.commit()
            self.log(LogType.SUCCESS, "Sprint klar!")

        except Exception as e:
            self.sprint.status = SprintStatus.FAILED
            self.sprint.error_message = str(e)
            self.sprint.completed_at = datetime.utcnow()
            self.db.commit()
            self.log(LogType.ERROR, f"Fel: {e}")
            raise
