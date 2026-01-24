"""Unified LLM client supporting multiple providers"""
import json
from anthropic import Anthropic

from apex_server.config import get_settings

settings = get_settings()


class LLMClient:
    """Unified LLM client supporting Anthropic, Groq, and Google"""

    def __init__(self):
        self.anthropic = Anthropic(api_key=settings.anthropic_api_key) if settings.anthropic_api_key else None
        self.groq_api_key = settings.groq_api_key
        self.gemini_model = None  # TODO: Aktivera Gemini senare

        # TODO: Aktivera när GOOGLE_API_KEY är konfigurerad
        # if settings.google_api_key:
        #     genai.configure(api_key=settings.google_api_key)
        #     self.gemini_model = genai.GenerativeModel('gemini-2.0-flash-exp')

    def call_anthropic(self, model: str, system: str, messages: list, tools: list) -> dict:
        """Call Anthropic API"""
        if not self.anthropic:
            raise ValueError("Anthropic API key not configured")

        response = self.anthropic.messages.create(
            model=model,
            max_tokens=4096,
            system=system,
            tools=tools,
            messages=messages
        )
        return response

    def call_groq(self, model: str, system: str, messages: list, tools: list) -> dict:
        """Call Groq API (OpenAI-compatible)"""
        import httpx

        if not self.groq_api_key:
            raise ValueError("Groq API key not configured")

        # Convert Anthropic-style messages to OpenAI format
        openai_messages = [{"role": "system", "content": system}]

        for msg in messages:
            role = msg["role"]
            content = msg["content"]

            if isinstance(content, str):
                openai_messages.append({"role": role, "content": content})
            elif isinstance(content, list):
                # Handle tool results and complex content
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            openai_messages.append({"role": role, "content": block["text"]})
                        elif block.get("type") == "tool_result":
                            openai_messages.append({
                                "role": "tool",
                                "tool_call_id": block.get("tool_use_id", ""),
                                "content": block.get("content", "")
                            })
                        elif block.get("type") == "tool_use":
                            # This is from assistant - add as assistant with tool_calls
                            openai_messages.append({
                                "role": "assistant",
                                "content": None,
                                "tool_calls": [{
                                    "id": block.get("id", ""),
                                    "type": "function",
                                    "function": {
                                        "name": block.get("name", ""),
                                        "arguments": json.dumps(block.get("input", {}))
                                    }
                                }]
                            })
                    elif hasattr(block, 'type'):  # Anthropic SDK object
                        if block.type == "text":
                            openai_messages.append({"role": role, "content": block.text})
                        elif block.type == "tool_use":
                            openai_messages.append({
                                "role": "assistant",
                                "content": None,
                                "tool_calls": [{
                                    "id": block.id,
                                    "type": "function",
                                    "function": {
                                        "name": block.name,
                                        "arguments": json.dumps(block.input)
                                    }
                                }]
                            })

        # Convert tools to OpenAI format
        openai_tools = []
        for tool in tools:
            openai_tools.append({
                "type": "function",
                "function": {
                    "name": tool["name"],
                    "description": tool.get("description", ""),
                    "parameters": tool.get("input_schema", {})
                }
            })

        # Make request to Groq
        response = httpx.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self.groq_api_key}",
                "Content-Type": "application/json"
            },
            json={
                "model": model,
                "messages": openai_messages,
                "tools": openai_tools if openai_tools else None,
                "max_tokens": 4096,
            },
            timeout=120.0
        )

        if response.status_code != 200:
            raise ValueError(f"Groq API error: {response.status_code} - {response.text}")

        return response.json()

    def call_gemini(self, system: str, messages: list, tools: list) -> dict:
        """Call Google Gemini API"""
        if not self.gemini_model:
            raise ValueError("Google API key not configured")

        # Convert Anthropic-style messages to Gemini format
        gemini_messages = []
        for msg in messages:
            role = "user" if msg["role"] == "user" else "model"
            content = msg["content"]

            if isinstance(content, str):
                gemini_messages.append({"role": role, "parts": [content]})
            elif isinstance(content, list):
                # Handle tool results and complex content
                parts = []
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            parts.append(block["text"])
                        elif block.get("type") == "tool_result":
                            parts.append(f"Tool result ({block.get('tool_use_id', '')}): {block.get('content', '')}")
                        elif block.get("type") == "tool_use":
                            parts.append(f"Using tool: {block.get('name', '')} with args: {json.dumps(block.get('input', {}))}")
                    else:
                        parts.append(str(block))
                if parts:
                    gemini_messages.append({"role": role, "parts": parts})

        # Convert tools to Gemini function declarations
        gemini_tools = []
        for tool in tools:
            func_decl = {
                "name": tool["name"],
                "description": tool.get("description", ""),
                "parameters": tool.get("input_schema", {})
            }
            gemini_tools.append(func_decl)

        # Create chat with system instruction
        chat = self.gemini_model.start_chat(history=gemini_messages[:-1] if len(gemini_messages) > 1 else [])

        # Include tools in generation config
        # Note: genai must be imported when Gemini is enabled
        import google.generativeai as genai
        generation_config = genai.GenerationConfig(
            max_output_tokens=4096,
            temperature=0.7,
        )

        # Make the request
        if gemini_tools:
            response = chat.send_message(
                gemini_messages[-1]["parts"] if gemini_messages else [system],
                generation_config=generation_config,
                tools=[genai.protos.Tool(function_declarations=gemini_tools)]
            )
        else:
            response = chat.send_message(
                gemini_messages[-1]["parts"] if gemini_messages else [system],
                generation_config=generation_config
            )

        return response

    @staticmethod
    def parse_groq_response(response: dict) -> list:
        """Parse Groq (OpenAI format) response into Anthropic-like content blocks"""
        blocks = []

        choices = response.get("choices", [])
        if not choices:
            return blocks

        message = choices[0].get("message", {})

        # Handle text content
        content = message.get("content")
        if content:
            blocks.append({"type": "text", "text": content})

        # Handle tool calls
        tool_calls = message.get("tool_calls", [])
        for tc in tool_calls:
            func = tc.get("function", {})
            try:
                args = json.loads(func.get("arguments", "{}"))
            except json.JSONDecodeError:
                args = {}

            blocks.append({
                "type": "tool_use",
                "id": tc.get("id", f"groq_{func.get('name', '')}"),
                "name": func.get("name", ""),
                "input": args
            })

        return blocks

    @staticmethod
    def parse_gemini_response(response) -> list:
        """Parse Gemini response into Anthropic-like content blocks"""
        blocks = []

        for candidate in response.candidates:
            for part in candidate.content.parts:
                if hasattr(part, 'text') and part.text:
                    blocks.append({"type": "text", "text": part.text})
                elif hasattr(part, 'function_call'):
                    fc = part.function_call
                    blocks.append({
                        "type": "tool_use",
                        "id": f"gemini_{fc.name}",
                        "name": fc.name,
                        "input": dict(fc.args) if fc.args else {}
                    })

        return blocks
