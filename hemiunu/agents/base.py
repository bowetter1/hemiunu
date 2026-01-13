"""
Hemiunu Base Agent - Gemensam klass för alla agenter.
Hanterar Claude API-anrop och tool-execution.
"""
import os
import json
from pathlib import Path
from typing import Optional, Callable
import anthropic
from dotenv import load_dotenv

# Ladda .env
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(env_path, override=True)

# Claude client
client = anthropic.Anthropic()

# Default model
DEFAULT_MODEL = "claude-sonnet-4-20250514"
MAX_ITERATIONS = 20


class BaseAgent:
    """
    Bas-klass för alla Hemiunu-agenter.

    Subklasser definierar:
    - role: Agentens roll (worker, tester, integrator, etc.)
    - tools: Lista av tool-definitioner
    - system_prompt: System-prompten
    - handle_result: Hur tool-resultat hanteras
    """

    role: str = "base"
    model: str = DEFAULT_MODEL
    max_iterations: int = MAX_ITERATIONS

    def __init__(self, task: dict, context: dict = None):
        """
        Initiera agenten.

        Args:
            task: Uppgiften som ska utföras
            context: Extra kontext (vision, beroenden, etc.)
        """
        self.task = task
        self.context = context or {}
        self.messages = []
        self.iteration = 0

    def get_tools(self) -> list:
        """Returnera tool-definitioner. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement get_tools()")

    def get_system_prompt(self) -> str:
        """Returnera system-prompten. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement get_system_prompt()")

    def get_initial_message(self) -> str:
        """Returnera första meddelandet till agenten. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement get_initial_message()")

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett tool. Överskrids av subklasser för rollspecifika tools."""
        raise NotImplementedError("Subclass must implement execute_tool()")

    def handle_completion(self, result: dict) -> Optional[dict]:
        """
        Hantera när agenten är klar (task_done, approve, reject, etc.)
        Returnerar dict med resultat, eller None för att fortsätta.
        """
        return None

    def log(self, message: str):
        """Logga ett meddelande."""
        print(f"[{self.role.upper()}] {message}")

    def run(self) -> dict:
        """
        Kör agenten tills den är klar eller max iterationer nåtts.

        Returns:
            dict med {status, result, error, iterations}
        """
        self.log(f"Startar på uppgift: {self.task.get('id', 'unknown')}")

        # Initiera konversationen
        self.messages = [{"role": "user", "content": self.get_initial_message()}]

        for self.iteration in range(self.max_iterations):
            self.log(f"Iteration {self.iteration + 1}")

            # Anropa Claude
            try:
                response = client.messages.create(
                    model=self.model,
                    max_tokens=4096,
                    system=self.get_system_prompt(),
                    tools=self.get_tools(),
                    messages=self.messages
                )
            except Exception as e:
                self.log(f"API-fel: {e}")
                return {
                    "status": "error",
                    "result": None,
                    "error": str(e),
                    "iterations": self.iteration + 1
                }

            # Lägg till assistentens svar
            assistant_content = response.content
            self.messages.append({"role": "assistant", "content": assistant_content})

            # Hantera svaret baserat på stop_reason
            if response.stop_reason == "end_turn":
                # Claude avslutade utan tool - be om avslut
                self.log("Claude avslutade utan tool, påminner...")
                self.messages.append({
                    "role": "user",
                    "content": "Du måste använda ett avslutande tool för att markera dig som klar."
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

                        self.log(f"Tool: {tool_name}")

                        # Exekvera tool
                        result = self.execute_tool(tool_name, tool_input)

                        # Kolla om det är ett avslutande tool
                        completion = self.handle_completion(result)
                        if completion:
                            self.log(f"Avslut: {completion.get('status')}")
                            completion["iterations"] = self.iteration + 1
                            return completion

                        tool_results.append({
                            "type": "tool_result",
                            "tool_use_id": tool_id,
                            "content": json.dumps(result)
                        })

                # Skicka tillbaka tool-resultaten
                self.messages.append({"role": "user", "content": tool_results})

        # Max iterationer nådda
        self.log("Max iterationer nådda")
        return {
            "status": "failed",
            "result": None,
            "error": "Max iterations reached",
            "iterations": self.max_iterations
        }
