"""
Hemiunu Agent Loop - Huvudloop som driver AI-agenten.

Flöde:
1. Hämta nästa TODO från DB
2. Ge uppgiften till Claude med tools
3. Claude skriver kod + testar via CLI
4. Loop tills Claude säger DONE eller FAILED
5. Uppdatera DB, gå till nästa uppgift
"""
import os
import json
from pathlib import Path
import anthropic
from dotenv import load_dotenv

# Ladda .env fil från hemiunu-mappen
env_path = Path(__file__).parent / ".env"
load_dotenv(env_path, override=True)

# Debug: verifiera att API-nyckeln laddades
api_key = os.getenv("ANTHROPIC_API_KEY")
if not api_key:
    raise RuntimeError(f"ANTHROPIC_API_KEY not found. Check {env_path}")

from substrate.db import (
    get_master,
    get_next_todo,
    get_task,
    update_task,
    create_task,
    get_all_tasks
)
from core.tools import TOOL_DEFINITIONS, execute_tool

# Claude client
client = anthropic.Anthropic()

# Max antal iterationer per uppgift (säkerhet mot oändliga loopar)
MAX_ITERATIONS = 20


def build_system_prompt(vision: str) -> str:
    """Bygg system-prompten för agenten."""
    return f"""Du är en AI-utvecklare i Hemiunu-systemet.

PROJEKTETS VISION:
{vision}

DINA REGLER:
1. Skriv KOD och TESTA den via CLI innan du säger att du är klar
2. Varje modul ska vara max 150 rader
3. Om uppgiften är för komplex, använd split_task för att dela upp den
4. Använd run_command för att köra och testa din kod
5. När koden funkar, använd task_done
6. Om du inte kan lösa uppgiften, använd task_failed

ARBETSFLÖDE:
1. Läs uppgiftsbeskrivningen
2. Skriv koden med write_file
3. Testa med run_command (kör CLI-testet)
4. Om det funkar: task_done
5. Om det inte funkar: fixa och testa igen
6. Om för komplext: split_task

Du har tillgång till hela projektmappen. Skriv riktig, fungerande kod."""


def run_agent_on_task(task: dict) -> str:
    """
    Kör agenten på en uppgift.
    Returnerar: "DONE", "FAILED", eller "SPLIT"
    """
    vision = get_master() or "Inget projekt definierat"
    system_prompt = build_system_prompt(vision)

    # Bygg användarmeddelandet
    user_message = f"""UPPGIFT: {task['description']}

CLI-TEST: {task.get('cli_test', 'Inget specifikt test')}

Implementera denna uppgift. Skriv kod, testa den, och markera som klar."""

    messages = [{"role": "user", "content": user_message}]

    print(f"\n{'='*60}")
    print(f"STARTAR UPPGIFT: {task['id']}")
    print(f"Beskrivning: {task['description']}")
    print(f"{'='*60}\n")

    for iteration in range(MAX_ITERATIONS):
        print(f"\n--- Iteration {iteration + 1} ---")

        # Anropa Claude
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            system=system_prompt,
            tools=TOOL_DEFINITIONS,
            messages=messages
        )

        # Processa svaret
        assistant_content = response.content
        messages.append({"role": "assistant", "content": assistant_content})

        # Kolla om vi är klara eller behöver köra tools
        if response.stop_reason == "end_turn":
            # Claude är klar med att prata, men använde inget tool
            print("Claude avslutade utan att använda tool.")
            # Be Claude avsluta ordentligt
            messages.append({
                "role": "user",
                "content": "Du måste använda task_done, task_failed, eller split_task för att avsluta."
            })
            continue

        elif response.stop_reason == "tool_use":
            # Processa alla tool calls
            tool_results = []

            for block in assistant_content:
                if block.type == "tool_use":
                    tool_name = block.name
                    tool_input = block.input
                    tool_id = block.id

                    print(f"Tool: {tool_name}")
                    print(f"Input: {json.dumps(tool_input, indent=2)[:200]}...")

                    # Exekvera tool
                    result = execute_tool(tool_name, tool_input)
                    print(f"Result: {str(result)[:200]}...")

                    # Kolla om det är en avslutande action
                    if result.get("action") == "DONE":
                        update_task(task["id"], status="GREEN")
                        print(f"\n>>> UPPGIFT KLAR: {result.get('summary')}")
                        return "DONE"

                    elif result.get("action") == "FAILED":
                        update_task(task["id"], status="RED", error=result.get("reason"))
                        print(f"\n>>> UPPGIFT MISSLYCKAD: {result.get('reason')}")
                        return "FAILED"

                    elif result.get("action") == "SPLIT":
                        # Skapa sub-tasks
                        for subtask in result.get("subtasks", []):
                            sub_id = create_task(
                                description=subtask["description"],
                                cli_test=subtask.get("cli_test"),
                                parent_id=task["id"]
                            )
                            print(f">>> Skapade sub-task: {sub_id}")

                        update_task(task["id"], status="SPLIT")
                        print(f"\n>>> UPPGIFT DELAD i {len(result.get('subtasks', []))} delar")
                        return "SPLIT"

                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": tool_id,
                        "content": json.dumps(result)
                    })

            # Skicka tillbaka tool-resultaten
            messages.append({"role": "user", "content": tool_results})

    # Max iterationer nådda
    update_task(task["id"], status="RED", error="Max iterations reached")
    return "FAILED"


def run_tick():
    """Kör en iteration: ta nästa TODO och processa den."""
    task = get_next_todo()

    if not task:
        print("Inga fler uppgifter i kön.")
        return False

    update_task(task["id"], status="WORKING")
    result = run_agent_on_task(task)
    print(f"\nResultat: {result}")
    return True


def show_status():
    """Visa status för alla uppgifter."""
    tasks = get_all_tasks()

    print("\n" + "="*60)
    print("UPPGIFTSSTATUS")
    print("="*60)

    for task in tasks:
        status_icon = {
            "TODO": "[ ]",
            "WORKING": "[~]",
            "GREEN": "[+]",
            "RED": "[X]",
            "SPLIT": "[/]"
        }.get(task["status"], "[?]")

        print(f"{status_icon} {task['id']}: {task['description'][:50]}")
        if task["error"]:
            print(f"    Error: {task['error']}")

    print("="*60 + "\n")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Användning:")
        print("  python agent_loop.py tick     - Kör nästa uppgift")
        print("  python agent_loop.py status   - Visa status")
        print("  python agent_loop.py run      - Kör alla uppgifter")
        sys.exit(1)

    command = sys.argv[1]

    if command == "tick":
        run_tick()
    elif command == "status":
        show_status()
    elif command == "run":
        while run_tick():
            pass
        show_status()
    else:
        print(f"Okänt kommando: {command}")
