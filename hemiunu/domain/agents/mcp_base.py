"""
MCP Base Agent - Bas-klass för agenter som använder MCP-servrar.

Skillnad från BaseAgent:
- Tools kommer från MCP-server (rollspecifika)
- Tool-execution går via MCP-adapter
- System prompt inkluderar MCP-instruktioner
"""
import json
from typing import Optional
from infrastructure.llm import call_claude
from infrastructure.mcp.adapter import MCPAdapter
from infrastructure.logging import AgentLogger

# Konstanter
MAX_ITERATIONS = 20


class MCPAgent:
    """
    Bas-klass för MCP-baserade agenter.

    Subklasser definierar:
    - role: Agentens roll
    - create_mcp_server(): Returnerar MCP-server för rollen
    - get_initial_message(): Första meddelandet
    - handle_completion(): Hantera avslutande actions
    """

    role: str = "mcp_base"
    model: str = "claude-sonnet-4-20250514"
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

        # Skapa MCP-adapter för denna roll
        self._adapter = MCPAdapter(self.create_mcp_server())

        # Skapa logger
        self._logger = AgentLogger(
            role=self.role,
            task_id=task.get("id")
        )

    def create_mcp_server(self):
        """Skapa MCP-server för denna roll. Överskrids av subklasser."""
        raise NotImplementedError("Subclass must implement create_mcp_server()")

    def get_tools(self) -> list:
        """Hämta tools från MCP-adapter."""
        return self._adapter.get_claude_tools()

    def get_system_prompt(self) -> str:
        """
        Bygg system-prompt.
        Inkluderar MCP-instruktioner och rollspecifik kontext.
        """
        vision = self.context.get("vision", "Inget projekt definierat")
        mcp_instructions = self._adapter.instructions

        return f"""PROJEKT: {vision}

ROLL: {self.role.upper()}

{mcp_instructions}"""

    def get_initial_message(self) -> str:
        """Returnera första meddelandet till agenten."""
        raise NotImplementedError("Subclass must implement get_initial_message()")

    def execute_tool(self, name: str, arguments: dict) -> dict:
        """Exekvera tool via MCP-adapter."""
        return self._adapter.execute(name, arguments)

    def handle_completion(self, result: dict) -> Optional[dict]:
        """
        Hantera när agenten är klar.
        Returnerar dict med resultat, eller None för att fortsätta.
        """
        return None

    def run(self) -> dict:
        """
        Kör agenten tills den är klar eller max iterationer nåtts.

        Returns:
            dict med {status, result, error, iterations}
        """
        task_id = self.task.get('id', 'unknown')
        task_desc = self.task.get('description', '')[:60]

        self._logger.start(description=task_desc)
        self._logger.debug(f"MCP-server: {self._adapter.name}")
        self._logger.debug(f"Model: {self.model}")

        # Initiera konversationen
        self.messages = [{"role": "user", "content": self.get_initial_message()}]

        try:
            for self.iteration in range(self.max_iterations):
                self._logger.set_iteration(self.iteration + 1)
                self._logger.debug(f"Iteration {self.iteration + 1}/{self.max_iterations}")

                # Anropa Claude via infrastructure
                response = call_claude(
                    messages=self.messages,
                    system=self.get_system_prompt(),
                    tools=self.get_tools(),
                    model=self.model
                )

                # Logga LLM-svar med tokens
                usage = response.get("usage", {})
                self._logger.llm_response(
                    stop_reason=response.get("stop_reason", "unknown"),
                    tool_calls=len(response.get("tool_calls", []))
                )
                if usage:
                    self._logger.debug(
                        f"Tokens: {usage.get('input_tokens', 0)} in, "
                        f"{usage.get('output_tokens', 0)} out"
                    )

                # Hantera fel
                if "error" in response:
                    self._logger.error(f"API error: {response['error']}")
                    return {
                        "status": "error",
                        "result": None,
                        "error": response["error"],
                        "iterations": self.iteration + 1
                    }

                # Lägg till assistentens svar (full content med tool_use blocks)
                assistant_content = response["content"]
                self.messages.append({"role": "assistant", "content": assistant_content})

                # Logga ev. text-svar
                assistant_text = response.get("text")
                if assistant_text:
                    self._logger.debug(f"Response: {assistant_text[:100]}...")

                # Hantera svaret baserat på stop_reason
                if response["stop_reason"] == "end_turn":
                    # Claude avslutade utan tool - be om avslut
                    self._logger.warn("No tool used, prompting for completion")
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
                        tool_input = tool_call["arguments"]
                        tool_id = tool_call["id"]

                        # Logga tool-anrop
                        self._logger.tool(tool_name, arguments=tool_input)

                        # Exekvera tool via MCP
                        result = self.execute_tool(tool_name, tool_input)

                        # Logga resultat
                        self._logger.tool_result(tool_name, result)

                        # Kolla om det är ett avslutande tool
                        completion = self.handle_completion(result)
                        if completion:
                            self._logger.complete(
                                completion.get('status'),
                                iterations=self.iteration + 1
                            )
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
            self._logger.error("Max iterations reached")
            return {
                "status": "failed",
                "result": None,
                "error": "Max iterations reached",
                "iterations": self.max_iterations
            }

        finally:
            self._logger.close()
