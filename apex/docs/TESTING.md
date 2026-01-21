# Testing Apex CLI

> Hur man testar Apex och hur Chef delegerar till workers.

---

## Arkitektur

```
┌─────────────────────────────────────────────────────────┐
│                    CLAUDE (Chef/Opus)                    │
│                                                         │
│  Du pratar med Claude som har MCP-tools tillgängliga    │
└─────────────────────┬───────────────────────────────────┘
                      │
                      │ MCP Protocol (JSON-RPC)
                      ▼
┌─────────────────────────────────────────────────────────┐
│                   mcp_agents.py                         │
│                                                         │
│  MCP-server som tar emot tool-anrop från Claude         │
│  och delegerar till rätt CLI                            │
└─────────────────────┬───────────────────────────────────┘
                      │
                      │ subprocess.run()
                      ▼
┌─────────────────────────────────────────────────────────┐
│              CLI Workers (qwen, gemini, etc)            │
│                                                         │
│  qwen -y "prompt..."                                    │
│  gemini -y "prompt..."                                  │
│  claude -p "prompt..." --dangerously-skip-permissions   │
│  codex exec "prompt..."                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Hur Chef startar workers

När du anropar ett MCP-tool, t.ex. `assign_coder`, händer detta:

### 1. Claude anropar MCP-tool
```json
{
  "method": "tools/call",
  "params": {
    "name": "assign_coder",
    "arguments": {
      "task": "Skapa login.py",
      "ai": "qwen"
    }
  }
}
```

### 2. mcp_agents.py tar emot
```python
# I handle_call_tool():
elif name == "assign_coder":
    task = arguments.get("task", "")
    ai = arguments.get("ai")  # "qwen" eller None
    cli = get_worker_cli("coder", ai)  # → "qwen"
```

### 3. CLI körs via subprocess
```python
def run_cli(cli: str, prompt: str, cwd: str):
    if cli == "qwen":
        cmd = ["qwen", "-y", prompt]
    elif cli == "gemini":
        cmd = ["gemini", "-y", prompt]
    # ...

    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.stdout
```

### 4. Output returneras till Claude
```json
{
  "result": {
    "content": [{"type": "text", "text": "👨‍💻 Coder svarar:\n\nJag har skapat login.py..."}]
  }
}
```

---

## Testa MCP-servern manuellt

### 1. Starta servern
```bash
cd /Users/bowetter/Desktop/news/apex
python3 apex/mcp_agents.py
```

### 2. Skicka JSON-RPC (i annan terminal)
```bash
# Initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | python3 apex/mcp_agents.py

# Lista tools
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 apex/mcp_agents.py

# Anropa tool
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"checkin_worker","arguments":{"worker":"tester","question":"Hej!"}}}' | python3 apex/mcp_agents.py
```

---

## Testa via Claude Code

### 1. Konfigurera MCP
Lägg till i din Claude-config (`~/.claude/settings.json` eller projektets `.mcp.json`):

```json
{
  "mcpServers": {
    "agents": {
      "command": "python3",
      "args": ["/Users/bowetter/Desktop/news/apex/apex/mcp_agents.py"]
    }
  }
}
```

### 2. Starta Claude Code
```bash
cd /Users/bowetter/Desktop/news/apex
claude
```

### 3. Testa tools
```
# I Claude-sessionen:

"Kör team_kickoff med vision 'Test' och goals ['Mål 1']"

"Kör checkin_worker med worker 'tester' och question 'Fungerar du?'"

"Kör assign_coder med task 'Skapa hello.py' och ai 'qwen'"
```

---

## Verifieringstester

### Test 1: Nya roller fungerar
```
checkin_worker(worker="tester", question="Hej!")
checkin_worker(worker="ad", question="Hej!")
checkin_worker(worker="devops", question="Hej!")
```
**Förväntat:** Alla svarar (inte "unknown worker" error)

### Test 2: AI parameter fungerar
```
assign_architect(task="Planera X", ai="qwen")
```
**Förväntat:** qwen körs istället för gemini (default)

### Test 3: Engelska rollnamn
```
checkin_worker(worker="tester", question="Test")
```
**Förväntat:** Output säger "Tester:" inte "tester:"

### Test 4: Dialog med minne
```
talk_to(worker="coder", message="Skapa en variabel x = 5")
talk_to(worker="coder", message="Vad är x?")
```
**Förväntat:** Coder minns att x = 5

---

## CLI-flaggor per AI

| AI | Kommando | Session |
|----|----------|---------|
| qwen | `qwen -y "prompt"` | `--continue` |
| gemini | `gemini -y "prompt"` | `--continue` |
| claude | `claude -p "prompt" --dangerously-skip-permissions` | `--continue` |
| codex | `codex exec "prompt"` | (ingen) |

`-y` = auto-accept
`--continue` = behåll session/minne
`--dangerously-skip-permissions` = skippa säkerhetsfrågor

---

## Felsökning

### "Command not found: qwen"
```bash
# Installera CLI:erna
npm install -g @anthropic-ai/claude-code
# eller
pip install qwen-cli gemini-cli
```

### "Ingen output" från worker
- Kolla API-quota för den AI:n
- Testa med annan AI: `ai="qwen"` istället för gemini

### Ändringar syns inte
- MCP-servern måste startas om
- Avsluta Claude-sessionen och starta ny

### Se vad som händer
```bash
# Kolla sprint.log i projektmappen
tail -f /path/to/project/sprint.log
```

---

## Exempel: Full sprint-test

```
1. team_kickoff(
     vision="Enkel todo-app",
     goals=["Skapa HTML", "Lägg till CSS", "JavaScript för interaktivitet"]
   )

2. assign_architect(task="Planera filstruktur för todo-app")

3. assign_coders_parallel(assignments=[
     {"coder_name": "coder_1", "task": "Skapa index.html", "file": "index.html"},
     {"coder_name": "coder_2", "task": "Skapa style.css", "file": "style.css"}
   ])

4. assign_reviewer(files_to_review=["index.html", "style.css"])

5. checkin_worker(worker="tester", question="Kan du testa sidan?")

6. team_retrospective(sprint_summary="Skapade grundläggande todo-app")
```

---

*Senast uppdaterad: 2026-01-19*
