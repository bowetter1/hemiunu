"""
Base Agent - Gemensam klass för alla agenter.

Hanterar:
- Claude API-anrop via infrastructure/llm
- Tool-execution loop
- Resultathantering
"""
import json
from typing import Optional
from infrastructure.llm import call_claude
from infrastructure.logging import AgentLogger

# Konstanter
MAX_ITERATIONS = 20

# Modeller - Subklasser kan överrida
# Vesir: Opus 4.5 (bästa för komplex planering)
# Worker: Sonnet 4 (kodning)
# Tester: Haiku 3.5 (snabb verifiering)
# Integrator: Sonnet 4 (merge-konflikter)
MODEL_OPUS = "claude-opus-4-5-20251101"
MODEL_SONNET = "claude-sonnet-4-20250514"
MODEL_HAIKU = "claude-haiku-3-5-20241022"
DEFAULT_MODEL = MODEL_SONNET


class BaseAgent:
    """
    Bas-klass för alla Hemiunu-agenter.

    Subklasser definierar:
    - role: Agentens roll (worker, tester, integrator, vesir)
    - get_tools(): Lista av tool-definitioner
    - get_system_prompt(): System-prompten
    - execute_tool(): Hur tools exekveras
    - handle_completion(): Hur avslut hanteras
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
        self._logger = AgentLogger(
            role=self.role,
            task_id=task.get("id", "unknown")[:8]
        )

    def get_tools(self) -> list:
        """Returnera tool-definitioner. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement get_tools()")

    def get_system_prompt(self) -> str:
        """Returnera system-prompten. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement get_system_prompt()")

    def get_initial_message(self) -> str:
        """Returnera första meddelandet till agenten."""
        raise NotImplementedError("Subclass must implement get_initial_message()")

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera ett tool. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement execute_tool()")

    def handle_completion(self, result: dict) -> Optional[dict]:
        """
        Hantera när agenten är klar (task_done, approve, reject, etc.)
        Returnerar dict med resultat, eller None för att fortsätta.
        """
        return None

    def log(self, message: str):
        """Logga ett meddelande (bakåtkompatibel)."""
        self._logger.info(message)

    def run(self) -> dict:
        """
        Kör agenten tills den är klar eller max iterationer nåtts.

        Returns:
            dict med {status, result, error, iterations}
        """
        self._logger.start(self.task.get('description', '')[:60])

        # Initiera konversationen
        self.messages = [{"role": "user", "content": self.get_initial_message()}]

        for self.iteration in range(self.max_iterations):
            self._logger.set_iteration(self.iteration + 1)

            # Anropa Claude via infrastructure
            response = call_claude(
                messages=self.messages,
                system=self.get_system_prompt(),
                tools=self.get_tools(),
                model=self.model
            )

            # Logga LLM-svar
            self._logger.llm_response(
                stop_reason=response.get("stop_reason", "unknown"),
                tool_calls=len(response.get("tool_calls", []))
            )

            # Hantera fel
            if "error" in response:
                self._logger.error(f"API-fel: {response['error']}")
                self._logger.close()
                return {
                    "status": "error",
                    "result": None,
                    "error": response["error"],
                    "iterations": self.iteration + 1
                }

            # Lägg till assistentens svar
            assistant_content = response["content"]
            self.messages.append({"role": "assistant", "content": assistant_content})

            # Hantera svaret baserat på stop_reason
            if response["stop_reason"] == "end_turn":
                # Claude avslutade utan tool - be om avslut
                self._logger.warn("Claude avslutade utan tool, påminner...")
                self.messages.append({
                    "role": "user",
                    "content": "Du måste använda ett avslutande tool för att markera dig som klar."
                })
                continue

            elif response["stop_reason"] == "tool_use":
                # Processa alla tool calls
                tool_results = []

                for tool_call in response.get("tool_calls", []):
                    tool_name = tool_call["name"]
                    tool_input = tool_call.get("arguments") or tool_call.get("input", {})
                    tool_id = tool_call["id"]

                    # Logga tool-anrop med argument
                    self._logger.tool(tool_name, arguments=tool_input)

                    # Exekvera tool
                    result = self.execute_tool(tool_name, tool_input)

                    # Logga tool-resultat
                    self._logger.tool_result(tool_name, result)

                    # Kolla om det är ett avslutande tool
                    completion = self.handle_completion(result)
                    if completion:
                        self._logger.complete(completion.get('status'))
                        self._logger.close()
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
        self._logger.error("Max iterationer nådda")
        self._logger.close()
        return {
            "status": "failed",
            "result": None,
            "error": "Max iterations reached",
            "iterations": self.max_iterations
        }
