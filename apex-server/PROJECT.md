# Apex Server

Multi-tenant SaaS-server för Apex AI-team med persistent minne.

---

## POC Resultat (Validerad Arkitektur)

Vi har byggt och testat två proof-of-concepts som validerar kärnarkitekturen.

### POC 1: LLM + CLI Tools på Server ✅

**Testad:** 2026-01-21
**Live URL:** https://apex-poc-production.up.railway.app

#### Vad vi testade
- Claude Opus via Anthropic API med tool use
- CLI-verktyg (git, npm, gh, railway) installerade i Docker
- Tool loop som kör tills LLM är klar

#### Resultat
```
Task: "Skapa hello.py och gör en git commit"

Iteration 1: write_file("hello.py", "def hello_world()...")
Iteration 2: run_command("git init")
Iteration 3: run_command("git add hello.py")
Iteration 4: run_command("git commit -m 'Initial commit'")
Iteration 5: "Klart!"

✅ Commit skapad: 78bbd9a
```

#### Lärdomar
- **Railway sätter PORT dynamiskt** - Använd `$PORT` i CMD, inte hårdkodat 8000
- **Healthcheck kan vara känslig** - Ta bort eller öka timeout vid debugging
- **Git config behövs** - Sätt user.email och user.name globalt i Dockerfile

---

### POC 2: Mem0 + Qdrant Memory ✅

**Testad:** 2026-01-21

#### Vad vi testade
- Mem0 för automatisk faktaextraktion
- Qdrant som vector store på Railway
- Memory persistence mellan requests

#### Resultat
```
Request 1: "Jag heter Bo och föredrar TypeScript"
└─> Mem0 extraherar: "Föredrar TypeScript framför JavaScript"
└─> Sparas i Qdrant

Request 2: "Skapa en utils fil i mitt föredragna språk"
└─> Memory search hittar TypeScript-preferens (score: 0.35)
└─> LLM skapar string-utils.ts (inte .py!)

✅ AI kom ihåg användarens preferens
```

#### Lärdomar

**Mem0 konfiguration:**
```python
mem0_config = {
    "vector_store": {
        "provider": "qdrant",
        "config": {
            "host": "qdrant.railway.internal",  # Railway intern DNS
            "port": 6333,
            "collection_name": "apex_memories_v2",  # Unik per version
        }
    },
    "embedder": {
        "provider": "openai",  # Kräver OPENAI_API_KEY
        "config": {
            "model": "text-embedding-3-small"
        }
    }
}
```

**Kritiska insikter:**
1. **Mem0 kräver två API-nycklar:**
   - `OPENAI_API_KEY` - för embeddings (text → vektor)
   - `ANTHROPIC_API_KEY` - för LLM (om du använder Claude)

2. **Vector dimension måste matcha:**
   - OpenAI embeddings = 1536 dimensioner
   - HuggingFace MiniLM = 384 dimensioner
   - Byt collection_name om du byter embedder!

3. **Memory search returnerar nested dict:**
   ```python
   result = memory.search(query, user_id=user_id)
   # result = {"results": [{"memory": "...", "score": 0.35}]}
   memories = result.get("results", [])
   ```

4. **Qdrant på Railway:**
   - Lägg till som Docker image: `qdrant/qdrant`
   - Intern DNS: `qdrant.railway.internal:6333`
   - Data försvinner vid container restart (behöver volume för prod)

---

### POC 3: Railway Volume Persistence ✅

**Testad:** 2026-01-21

#### Vad vi testade
- Railway Volume mountad på `/app/storage`
- Fil-persistence efter container restart

#### Resultat
```
1. Skapade fil via API:
   POST /run {"task": "Create persistent-test.txt"}
   → AI skapade filen på /app/storage/persistent-test.txt

2. Verifierade fil finns:
   GET /files/persistent-test.txt
   → {"content": "This file was created to test..."}

3. Triggade redeploy (container restart):
   railway redeploy -y
   → Ny container startade

4. Verifierade fil efter restart:
   GET /files/persistent-test.txt
   → {"content": "This file was created to test..."}

✅ Filen överlevde restart!
```

#### Lärdomar
- **Volume setup:** `railway volume add --mount-path /app/storage`
- Volumes mountas endast vid runtime, inte under build
- Data persisterar över restarts och redeploys
- Perfekt för sprint-filer som AI skapar

---

### POC 4: Multi-Agent Koordinering ✅

**Testad:** 2026-01-21

#### Vad vi testade
- Tre Opus-agenter: Chef, Frontend, Backend
- Kommunikation via meddelandefiler
- Koordinerad filskapning

#### Resultat
```
POST /sprint {"task": "Bygg en counter-app"}

PHASE 1: CHEF PLANNING
├── Analyserade uppgiften
├── send_message("backend", "Bygg counter API med GET/POST...")
└── send_message("frontend", "Bygg UI med knapp och display...")

PHASE 2: BACKEND WORKER
├── Läste messages/to_backend.txt
├── Skapade backend/package.json
├── Skapade backend/server.js (Express + CORS)
└── send_message("chef", "Backend klar! API docs: ...")

PHASE 3: FRONTEND WORKER
├── Läste messages/to_frontend.txt
├── Skapade frontend/index.html
├── Skapade frontend/style.css (glassmorfism + animationer)
├── Skapade frontend/script.js (API-anrop)
└── send_message("chef", "Frontend klar!")

PHASE 4: CHEF SUMMARY
├── Läste messages/to_chef.txt (rapporter från workers)
├── list_files() - verifierade alla filer
├── read_file() - granskade koden
└── Sammanfattade resultatet

✅ Komplett counter-app skapad av 3 samarbetande agenter!
```

#### Skapade filer
```
backend/
├── package.json      # Express dependencies
└── server.js         # GET /api/counter, POST /api/counter/increment

frontend/
├── index.html        # Counter UI
├── style.css         # Modern gradient + glassmorfism
└── script.js         # API-anrop med felhantering

messages/
├── to_backend.txt    # Instruktioner från Chef
├── to_frontend.txt   # Instruktioner från Chef
└── to_chef.txt       # Rapporter från workers
```

#### Worker Prompts
```python
WORKER_PROMPTS = {
    "chef": """Du är CHEF - projektledare för ett utvecklingsteam.
    Delegera till Frontend och Backend via send_message.
    Koordinera och sammanfatta resultatet.""",

    "frontend": """Du är FRONTEND WORKER.
    Läs meddelanden från Chef, skapa filer i frontend/,
    svara Chef via send_message.""",

    "backend": """Du är BACKEND WORKER.
    Läs meddelanden från Chef, skapa filer i backend/,
    dokumentera API endpoints, svara Chef."""
}
```

#### Lärdomar
- **Meddelanden via filer fungerar** - Enkelt och robust
- **Sekventiell körning** - Chef → Backend → Frontend → Chef
- **Workers läser varandras filer** - Frontend kan se backend/server.js
- **Opus följer instruktioner väl** - Skapar korrekta filer och rapporterar
- **Varje worker har egen prompt** - Ger tydlig rollfördelning

#### Förbättringar för produktion
- Parallell körning av Backend/Frontend
- WebSocket för realtidsuppdateringar
- Retry vid fel
- Memory (Mem0) per worker för kontext

---

### Validerad Arkitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                         RAILWAY                                  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    apex-poc                              │   │
│  │                                                          │   │
│  │  FastAPI                                                 │   │
│  │     │                                                    │   │
│  │     ├──▶ Anthropic API (Claude Opus)                    │   │
│  │     │         │                                          │   │
│  │     │         ▼                                          │   │
│  │     │    Tool calls: write_file, run_command            │   │
│  │     │         │                                          │   │
│  │     │         ▼                                          │   │
│  │     │    subprocess.run("git commit...")                │   │
│  │     │                                                    │   │
│  │     └──▶ Mem0                                           │   │
│  │               │                                          │   │
│  │               ├──▶ OpenAI API (embeddings)              │   │
│  │               └──▶ Qdrant (vector store)                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────┐                                                │
│  │   qdrant    │ ◀── qdrant.railway.internal:6333              │
│  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

### Environment Variables (Verifierade)

```bash
# Krävs för LLM
ANTHROPIC_API_KEY=sk-ant-xxx

# Krävs för Mem0 embeddings
OPENAI_API_KEY=sk-xxx

# Sätts automatiskt av Railway
PORT=8080  # Dynamisk!
```

---

### Kod som fungerar (från POC)

Se `main.py` för fungerande implementation av:
- LLM tool loop med Anthropic
- Mem0 memory integration
- CLI tool execution via subprocess

---

## Tech Stack

| Komponent | Teknologi |
|-----------|-----------|
| Backend | FastAPI + Python 3.11+ |
| Databas | PostgreSQL (Railway) |
| Vector Store | Qdrant (Railway) |
| AI Memory | Mem0 |
| LLM | Qwen/Claude/Gemini via API |
| Auth | JWT + API Keys |
| Realtime | WebSocket |
| Deploy | Railway |

---

## Kärnkoncept: Hur AI använder CLI-verktyg

### Vad som körs var

| Typ | Exempel | Var körs det? |
|-----|---------|---------------|
| **System CLI** | `git`, `npm`, `gh`, `railway` | ✅ På servern (Docker) |
| **LLM "tänkande"** | Qwen, Claude, Gemini | ✅ Via API |
| **AI Assistant CLI** | `claude`, `qwen-coder` | ❌ Behövs ej |

### Flöde: AI → Tool → Resultat

```
┌─────────────────────────────────────────────────────────────────────┐
│                           RAILWAY                                    │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                    Docker Container                         │     │
│  │                                                             │     │
│  │   Installerade CLI-verktyg:                                │     │
│  │   ├── git                                                  │     │
│  │   ├── gh (GitHub CLI)                                      │     │
│  │   ├── railway (Railway CLI)                                │     │
│  │   ├── npm, node                                            │     │
│  │   └── python, pip                                          │     │
│  │                                                             │     │
│  │   ┌─────────────┐       ┌─────────────┐                   │     │
│  │   │ Apex Server │       │ LLM API     │                   │     │
│  │   │             │──────▶│ (Qwen etc)  │                   │     │
│  │   │             │       │             │                   │     │
│  │   │             │◀──────│ Tool calls: │                   │     │
│  │   │             │       │ "git commit"│                   │     │
│  │   └──────┬──────┘       └─────────────┘                   │     │
│  │          │                                                  │     │
│  │          ▼                                                  │     │
│  │   ┌─────────────┐                                          │     │
│  │   │ Tool Runner │                                          │     │
│  │   │             │                                          │     │
│  │   │ subprocess: │                                          │     │
│  │   │ git commit  │                                          │     │
│  │   │ npm install │                                          │     │
│  │   │ railway up  │                                          │     │
│  │   └─────────────┘                                          │     │
│  │                                                             │     │
│  └────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────┘
```

### Exempel: Sprint som deployer till Railway

```
1. Användare: "Bygg en todo-app och deploya till Railway"
        │
        ▼
2. Server → Qwen API: "Bygg todo-app" + tools
        │
        ▼
3. Qwen: "Jag vill använda write_file"
   Server: subprocess kör write_file → App.jsx skapad
        │
        ▼
4. Qwen: "Jag vill använda run_command: npm install"
   Server: subprocess kör npm install → OK
        │
        ▼
5. Qwen: "Jag vill använda run_command: git add . && git commit"
   Server: subprocess kör git commit → OK
        │
        ▼
6. Qwen: "Jag vill använda run_command: git push origin main"
   Server: subprocess kör git push → OK
        │
        ▼
7. Qwen: "Jag vill använda run_command: railway up"
   Server: subprocess kör railway up → Deployed!
        │
        ▼
8. Qwen: "Klart! Appen finns på https://todo-app.railway.app"
```

---

## Arkitektur

```
┌─────────────────────────────────────────────────────────────────────┐
│                            RAILWAY                                   │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                      Apex Server                             │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │   │
│  │  │   REST API   │  │ LLM          │  │ Tool Runner  │      │   │
│  │  │   /sprints   │  │ Orchestrator │  │              │      │   │
│  │  │   /auth      │  │              │  │ - write_file │      │   │
│  │  │   /memory    │  │ (tool loop)  │  │ - read_file  │      │   │
│  │  └──────────────┘  └───────┬──────┘  │ - run_cmd    │      │   │
│  │                            │         │ - git ops    │      │   │
│  │                            ▼         └──────────────┘      │   │
│  │                    ┌──────────────┐                        │   │
│  │                    │   LLM APIs   │                        │   │
│  │                    │ Qwen/Claude/ │                        │   │
│  │                    │ Gemini/GPT   │                        │   │
│  │                    └──────────────┘                        │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │ PostgreSQL  │  │   Qdrant    │  │    Mem0     │                 │
│  │  (data)     │  │  (vectors)  │  │  (memory)   │                 │
│  └─────────────┘  └─────────────┘  └─────────────┘                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## LLM Orchestrator (Kärnan)

Vår egen "MCP host" som kör tool loops mot LLM APIs:

```python
# apex_server/services/orchestrator.py

class LLMOrchestrator:
    """Kör tool loops mot LLM API - som Claude CLI gör, men på servern"""

    def __init__(self, tools: list[Tool], memory: ApexMemory):
        self.tools = {t.name: t for t in tools}
        self.memory = memory

    async def run(self, sprint: Sprint, worker: str, task: str) -> str:
        # 1. Hämta kontext från minne
        context = await self.memory.get_context(sprint, worker, task)

        # 2. Välj LLM baserat på tenant config
        llm = self.get_llm_client(sprint.tenant.worker_config[worker])

        messages = [
            {"role": "system", "content": PROMPTS[worker] + context},
            {"role": "user", "content": task}
        ]

        # 3. Tool loop
        while True:
            response = await llm.complete(
                messages=messages,
                tools=self.tool_definitions
            )

            if not response.tool_calls:
                break  # Klart - LLM gav slutsvar

            # 4. Kör varje tool på servern
            for call in response.tool_calls:
                tool = self.tools[call.name]
                result = await tool.execute(
                    sprint_dir=sprint.project_dir,
                    **call.arguments
                )
                messages.append({
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result
                })

        # 5. Spara till minne
        await self.memory.add(sprint, worker, response.content)

        return response.content
```

---

## Tools som körs på servern

```python
# apex_server/services/tools.py

class WriteFileTool(Tool):
    name = "write_file"
    description = "Write content to a file"

    async def execute(self, sprint_dir: str, path: str, content: str) -> str:
        full_path = Path(sprint_dir) / path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(content)
        return f"✓ Wrote {len(content)} bytes to {path}"


class ReadFileTool(Tool):
    name = "read_file"
    description = "Read a file"

    async def execute(self, sprint_dir: str, path: str) -> str:
        full_path = Path(sprint_dir) / path
        if not full_path.exists():
            return f"✗ File not found: {path}"
        return full_path.read_text()


class RunCommandTool(Tool):
    name = "run_command"
    description = "Run a shell command (git, npm, railway, etc.)"

    ALLOWED_COMMANDS = ["git", "npm", "npx", "node", "gh", "railway", "python", "pip"]

    async def execute(self, sprint_dir: str, command: str) -> str:
        # Säkerhetskontroll
        cmd_start = command.split()[0]
        if cmd_start not in self.ALLOWED_COMMANDS:
            return f"✗ Command not allowed: {cmd_start}"

        result = subprocess.run(
            command,
            shell=True,
            cwd=sprint_dir,
            capture_output=True,
            timeout=120,
            env={**os.environ, "GIT_AUTHOR_NAME": "Apex AI", ...}
        )

        output = result.stdout.decode() + result.stderr.decode()
        return f"$ {command}\n{output}"


class ListFilesTool(Tool):
    name = "list_files"
    description = "List files in a directory"

    async def execute(self, sprint_dir: str, path: str = ".") -> str:
        full_path = Path(sprint_dir) / path
        files = list(full_path.rglob("*"))
        return "\n".join(str(f.relative_to(sprint_dir)) for f in files[:100])
```

---

## Memory-arkitektur (Mem0 + Qdrant)

### Tre nivåer av minne

```
┌─────────────────────────────────────────────────┐
│                   TENANT                         │
│  "Företaget använder Python 3.12, FastAPI"      │
│  "Kodstandard: black, ruff, pytest"             │
│  "Deploy alltid till Railway"                   │
│                                                  │
│   ┌─────────────────────────────────────────┐   │
│   │              SPRINT                      │   │
│   │  "Projektet är en e-handel med React"   │   │
│   │  "Använder Stripe för betalningar"      │   │
│   │  "GitHub repo: user/ecommerce-app"      │   │
│   │                                          │   │
│   │   ┌──────────┐  ┌──────────┐            │   │
│   │   │ BACKEND  │  │ FRONTEND │            │   │
│   │   │ "Skapade │  │ "Byggde  │            │   │
│   │   │ /api/pay"│  │ CartPage"│            │   │
│   │   └──────────┘  └──────────┘            │   │
│   └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Memory Service

```python
# apex_server/services/memory.py

from mem0 import Memory

class ApexMemory:
    def __init__(self, config):
        self.mem = Memory.from_config(config)

    async def get_context(self, sprint: Sprint, worker: str, query: str) -> str:
        """Hämta relevant kontext från alla nivåer"""
        memories = []

        # Tenant-minnen (kodstandard, preferenser)
        memories += self.mem.search(query, user_id=f"tenant:{sprint.tenant_id}")

        # Sprint-minnen (projektbeslut)
        memories += self.mem.search(query, user_id=f"sprint:{sprint.id}")

        # Worker-minnen (vad denna worker gjort)
        memories += self.mem.search(query, user_id=f"worker:{sprint.id}:{worker}")

        if not memories:
            return ""

        return "## Relevant Context\n" + "\n".join(
            f"- {m['memory']}" for m in memories
        )

    async def add(self, sprint: Sprint, worker: str, content: str):
        """Lägg till minne (Mem0 extraherar fakta automatiskt)"""
        self.mem.add(
            content,
            user_id=f"worker:{sprint.id}:{worker}",
            metadata={"sprint_id": str(sprint.id), "worker": worker}
        )
```

---

## Projektstruktur

```
apex-server/
├── PROJECT.md              # Detta dokument
├── pyproject.toml          # Python dependencies
├── Dockerfile              # Container med CLI-verktyg
├── railway.toml            # Railway config
├── docker-compose.yml      # Lokal utveckling
├── alembic.ini             # Migration config
├── alembic/
│   └── versions/
│
├── apex_server/
│   ├── __init__.py
│   ├── main.py             # FastAPI app
│   ├── config.py           # Settings
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py         # Dependency injection
│   │   └── routes/
│   │       ├── auth.py
│   │       ├── sprints.py
│   │       ├── memory.py
│   │       └── ws.py
│   │
│   ├── domain/
│   │   ├── __init__.py
│   │   ├── models.py       # Pydantic schemas
│   │   └── entities.py     # SQLAlchemy models
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── orchestrator.py # LLM tool loop
│   │   ├── tools.py        # Tool implementations
│   │   ├── memory.py       # Mem0 integration
│   │   ├── llm_clients.py  # Qwen/Claude/Gemini clients
│   │   └── sprint_runner.py
│   │
│   ├── infrastructure/
│   │   ├── __init__.py
│   │   ├── database.py
│   │   └── mem0_config.py
│   │
│   └── prompts/            # Worker system prompts
│       ├── backend.txt
│       ├── frontend.txt
│       └── devops.txt
│
├── tests/
└── storage/                # Sprint-filer (gitignored)
```

---

## Datamodell

### Tenant
```python
class Tenant:
    id: UUID
    name: str
    slug: str                    # unique
    max_concurrent_sprints: int  # default 3
    worker_config: JSON          # {"backend": "qwen", "frontend": "claude"}
    github_token: str            # encrypted, för git push
    railway_token: str           # encrypted, för deploy
    created_at: datetime
```

### User
```python
class User:
    id: UUID
    email: str
    password_hash: str
    name: str
    role: str                    # "admin" | "member"
    tenant_id: FK -> Tenant
    created_at: datetime
```

### Sprint
```python
class Sprint:
    id: UUID
    task: text
    status: enum                 # pending, running, completed, failed, cancelled
    project_dir: str             # /storage/{sprint_id}/
    github_repo: str             # user/repo (optional)
    railway_project: str         # project-id (optional)
    started_at: datetime
    completed_at: datetime
    error_message: text
    tenant_id: FK -> Tenant
    created_by_id: FK -> User
```

### WorkerRun
```python
class WorkerRun:
    id: UUID
    worker_name: str             # backend, frontend, devops
    llm_provider: str            # qwen, claude, gemini
    status: str                  # running, completed, failed
    tokens_used: int
    sprint_id: FK -> Sprint
    started_at: datetime
    ended_at: datetime
```

### LogEntry
```python
class LogEntry:
    id: int
    timestamp: datetime
    level: str
    source: str                  # "system", "backend", "frontend"
    message: text
    data: JSON
    sprint_id: FK -> Sprint
```

---

## API Endpoints

### Auth
```
POST   /api/v1/auth/register
POST   /api/v1/auth/login
POST   /api/v1/auth/api-keys
```

### Sprints
```
GET    /api/v1/sprints
POST   /api/v1/sprints
GET    /api/v1/sprints/{id}
POST   /api/v1/sprints/{id}/cancel
GET    /api/v1/sprints/{id}/logs
GET    /api/v1/sprints/{id}/files
GET    /api/v1/sprints/{id}/files/{path}
POST   /api/v1/sprints/{id}/download    # ZIP av alla filer
```

### Memory
```
GET    /api/v1/memory
POST   /api/v1/memory
DELETE /api/v1/memory/{id}
```

### WebSocket
```
WS     /api/v1/ws/sprints/{id}          # Realtime logs & status
```

---

## Dockerfile (med CLI-verktyg)

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js (för npm, npx)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh

# Railway CLI
RUN npm install -g @railway/cli

# Python dependencies
COPY pyproject.toml .
RUN pip install --no-cache-dir .

COPY . .

# Storage directory
RUN mkdir -p /app/storage

CMD ["uvicorn", "apex_server.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Dependencies

```toml
[project]
name = "apex-server"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
    # Web
    "fastapi>=0.109.0",
    "uvicorn[standard]>=0.27.0",
    "python-multipart>=0.0.6",
    "websockets>=12.0",

    # Database
    "sqlalchemy>=2.0.25",
    "alembic>=1.13.1",
    "psycopg2-binary>=2.9.9",

    # Auth
    "python-jose[cryptography]>=3.3.0",
    "passlib[bcrypt]>=1.7.4",

    # LLM Clients
    "openai>=1.10.0",          # Qwen (OpenAI-compatible)
    "anthropic>=0.18.0",       # Claude
    "google-generativeai>=0.4.0",  # Gemini

    # Memory
    "mem0ai>=0.1.0",
    "qdrant-client>=1.7.0",

    # Utils
    "httpx>=0.26.0",
    "pydantic>=2.5.0",
    "pydantic-settings>=2.1.0",
    "jinja2>=3.1.3",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "ruff>=0.1.0",
]
```

---

## Railway Setup

### railway.toml
```toml
[build]
builder = "DOCKERFILE"

[deploy]
healthcheckPath = "/health"
healthcheckTimeout = 30
restartPolicyType = "ON_FAILURE"
```

### Services

| Service | Template |
|---------|----------|
| apex-server | GitHub repo |
| postgres | Railway PostgreSQL |
| qdrant | Railway Qdrant |

### Environment Variables
```bash
# Auto från Railway
DATABASE_URL=${{Postgres.DATABASE_URL}}
QDRANT_URL=http://${{Qdrant.RAILWAY_PRIVATE_DOMAIN}}:6333

# LLM API keys
QWEN_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-xxx
GOOGLE_API_KEY=xxx

# Auth
JWT_SECRET=<generate>
```

---

## Lokal utveckling

### docker-compose.yml
```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: apex
      POSTGRES_PASSWORD: apex
      POSTGRES_DB: apex
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage

volumes:
  postgres_data:
  qdrant_data:
```

### Starta
```bash
docker-compose up -d
pip install -e ".[dev]"
alembic upgrade head
uvicorn apex_server.main:app --reload
```

---

## Implementation - Fas 1

1. **Grundstruktur**
   - [ ] pyproject.toml
   - [ ] Dockerfile
   - [ ] apex_server/main.py
   - [ ] apex_server/config.py

2. **Databas**
   - [ ] apex_server/infrastructure/database.py
   - [ ] apex_server/domain/entities.py
   - [ ] Alembic migration

3. **LLM Orchestrator**
   - [ ] apex_server/services/llm_clients.py
   - [ ] apex_server/services/tools.py
   - [ ] apex_server/services/orchestrator.py

4. **Memory**
   - [ ] apex_server/infrastructure/mem0_config.py
   - [ ] apex_server/services/memory.py

5. **API**
   - [ ] apex_server/api/routes/auth.py
   - [ ] apex_server/api/routes/sprints.py

6. **Deploy**
   - [ ] railway.toml
   - [ ] Test på Railway

---

## Storage & Deploy Arkitektur

### Flöde: Volume → GitHub → Railway

```
┌─────────────────────────────────────────────────────────────────────┐
│                           RAILWAY                                    │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Apex Server                                │  │
│  │                                                               │  │
│  │   AI skriver filer via tools                                 │  │
│  │        │                                                      │  │
│  │        ▼                                                      │  │
│  │   ┌─────────────────────┐                                    │  │
│  │   │   Railway Volume    │  ← Persistent lagring              │  │
│  │   │   /app/storage      │    (överlever restart)             │  │
│  │   │                     │                                     │  │
│  │   │   /sprint-123/      │                                     │  │
│  │   │     ├── src/        │                                     │  │
│  │   │     ├── package.json│                                     │  │
│  │   │     └── .git/       │                                     │  │
│  │   └─────────────────────┘                                    │  │
│  │        │                                                      │  │
│  │        │ git push                                             │  │
│  │        ▼                                                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────┬──────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          GITHUB                                      │
│                                                                      │
│   Repository: user/my-project                                       │
│   ├── main branch                                                   │
│   └── Webhook → Railway                                             │
│                    │                                                 │
└────────────────────┼────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     RAILWAY (Deploy Target)                          │
│                                                                      │
│   Auto-deploy från GitHub                                           │
│   ├── Build                                                          │
│   └── Deploy till produktion                                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Railway Volume Setup

```bash
# Lägg till volume via Railway CLI eller dashboard
railway volume create apex-storage
railway volume attach apex-storage --mount /app/storage
```

**Viktigt om Railway Volumes:**
- Data persisterar över restarts och redeploys
- Mountas endast vid runtime (inte under build)
- Går inte att accessa under build-steget
- Perfekt för sprint-filer som AI skapar

### Hur AI pushar till GitHub

```python
# 1. AI skapar projekt
write_file("src/index.js", "console.log('hello')")
write_file("package.json", '{"name": "my-app"}')

# 2. AI initierar git
run_command("git init")
run_command("git add .")
run_command("git commit -m 'Initial commit'")

# 3. AI kopplar till GitHub (med tenant's token)
run_command("git remote add origin https://github.com/user/my-project.git")
run_command("git push -u origin main")

# 4. Railway auto-deployar (om kopplat till repot)
```

### Environment för Git Push

```python
# I tool execution
env = {
    **os.environ,
    "GIT_AUTHOR_NAME": "Apex AI",
    "GIT_AUTHOR_EMAIL": "ai@apex.dev",
    "GH_TOKEN": tenant.github_token,  # För autentisering
}
subprocess.run(command, env=env, ...)
```

### Fördelar med denna arkitektur

| Fördelar | Beskrivning |
|----------|-------------|
| **Persistent** | Filer försvinner inte vid restart |
| **Git-backed** | All kod pushas till GitHub för säkerhet |
| **Auto-deploy** | Railway kan auto-deploya från GitHub |
| **Standard workflow** | Samma som mänskliga utvecklare använder |
| **Auditable** | Full commit-historik på GitHub |

---

## Fas 2: Full MCP-lösning

Kopiera och adaptera från apex CLI (`/apex/apex/`):

### Prompts (kopiera rakt av)
```
apex_server/mcp/prompts/
├── _base.md        # Delad kontext för alla workers
├── chef.md         # CEO/Orchestrator (388 rader, Flight Checklist)
├── ad.md           # Art Director
├── architect.md    # Arkitekt
├── backend.md      # Backend-utvecklare
├── frontend.md     # Frontend-utvecklare
├── tester.md       # Test-skrivare
├── reviewer.md     # Kodgranskare
└── devops.md       # DevOps
```

### Tools (adaptera för API)
```
apex_server/mcp/tools/
├── __init__.py     # ALL_TOOLS, ALL_HANDLERS
├── delegation.py   # assign_ad, assign_backend, assign_parallel, etc.
├── communication.py # talk_to, checkin_worker, reassign_with_feedback
├── boss.py         # thinking, log_decision, summarize_progress
├── files.py        # read_file, write_file, list_files
├── meetings.py     # team_kickoff, sprint_planning, team_demo
├── testing.py      # run_tests, run_lint, run_typecheck
└── deploy.py       # deploy_railway, check_railway_status
```

### Orchestrator
- Ersätt `subprocess.run(["claude", ...])` med `anthropic.messages.create()`
- Ersätt `subprocess.run(["gemini", ...])` med `google.generativeai`
- Behåll samma tool-loop och session-hantering

---

## Fas 3: Web-förbättringar (Roadmap)

Baserat på analys av apex CLI vs web-behov.

### Prioritet 1: Grundläggande UX

#### 1.1 Real-time WebSocket
```
CLI:  Loggar skrivs till fil → användaren läser filen
Web:  WebSocket push → loggar visas direkt i browser

Endpoint: WS /api/v1/ws/sprints/{id}
Events:
  - log: {type, worker, message, timestamp}
  - status: {phase, progress, active_workers}
  - file: {action: created|modified, path, size}
```

#### 1.2 Visuell progress
```
┌──────────────────────────────────────────────────────┐
│  PRE-FLIGHT                                          │
│  [✓] DevOps  [✓] CRITERIA.md  [✓] Kickoff           │
├──────────────────────────────────────────────────────┤
│  SPRINT 1: Core Setup                                │
│  [✓] AD+Architect  [▶] Backend+Frontend  [ ] Test   │
│                                                      │
│  ████████████████░░░░░░░░  65%                      │
├──────────────────────────────────────────────────────┤
│  WORKERS                                             │
│  🎨 AD          ✅ klar                              │
│  🏗️ Architect   ✅ klar                              │
│  ⚙️ Backend     🔄 arbetar... (iteration 3)         │
│  🖼️ Frontend    ⏳ väntar                            │
└──────────────────────────────────────────────────────┘
```

#### 1.3 Interaktiv Chef-dialog
```
┌──────────────────────────────────────────────────────┐
│  💬 Chef frågar:                                     │
│                                                      │
│  "Vilken databas vill du använda för detta projekt?" │
│                                                      │
│  [PostgreSQL]  [SQLite]  [MongoDB]  [Ingen]         │
│                                                      │
│  Eller skriv eget svar: [________________] [Skicka] │
└──────────────────────────────────────────────────────┘
```

### Prioritet 2: Insikter & Kontroll

#### 2.1 Kostnadsvisning
```
┌─────────────────────────────────────┐
│  💰 Token-användning                │
│                                     │
│  Chef (Opus)      12,450 tokens     │
│  Backend (Gemini)  8,230 tokens     │
│  Frontend (Opus)   6,120 tokens     │
│  ─────────────────────────────      │
│  Totalt:          26,800 tokens     │
│  Kostnad:         ~$0.42            │
└─────────────────────────────────────┘
```

#### 2.2 Förhandsvisning av app
```
┌──────────────────────────────────────────────────────┐
│  🖥️ Live Preview                    [↗ Öppna]        │
├──────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────┐ │
│  │                                                │ │
│  │     iframe med localhost:8000                  │ │
│  │     (dev-server startas automatiskt)          │ │
│  │                                                │ │
│  └────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

#### 2.3 Cancel/Pause
- Avbryt sprint mitt i körningen
- Pausa och återuppta senare
- Hoppa över steg (t.ex. skippa tester)

### Prioritet 3: Integrationer

#### 3.1 GitHub-integration
```
Automatiskt per sprint:
1. Skapa nytt repo (eller använd befintligt)
2. Commit efter varje fas
3. Skapa PR när klart
4. Visa commit-historik i UI

Settings per tenant:
- github_token (encrypted)
- default_org
- repo_template
```

#### 3.2 Railway auto-deploy
```
Efter godkänd sprint:
1. Länka repo till Railway
2. Sätt environment variables
3. Deploya automatiskt
4. Visa deploy-URL i UI
```

#### 3.3 Historik & Templates
```
┌──────────────────────────────────────────────────────┐
│  📁 Tidigare sprints                                 │
├──────────────────────────────────────────────────────┤
│  ✅ Todo-app med React       2024-01-20   [Återskapa]│
│  ✅ API för väderdata        2024-01-19   [Återskapa]│
│  ❌ E-handel (misslyckades)  2024-01-18   [Se loggar]│
└──────────────────────────────────────────────────────┘

[+ Skapa från template]
  - Blank FastAPI
  - React + FastAPI
  - Next.js fullstack
```

### Prioritet 4: Avancerat

#### 4.1 Multi-LLM per worker
```python
# Tenant config
worker_config = {
    "chef": "claude-opus",      # Bäst på orchestration
    "ad": "claude-opus",        # Bäst på design
    "architect": "claude-opus", # Bäst på planering
    "backend": "gemini-pro",    # Snabb på kod
    "frontend": "claude-opus",  # Bra på UI
    "tester": "gemini-pro",     # Snabb på tester
    "reviewer": "gemini-pro",   # Snabb på review
    "devops": "claude-opus",    # Bäst på config
}
```

#### 4.2 Mem0 integration
```
Per tenant:
- Kodstandarder, preferenser
- Vanliga mönster

Per sprint:
- Projektbeslut
- API-kontrakt

Per worker:
- Vad de gjort i denna sprint
```

#### 4.3 Parallell execution
```python
# Äkta parallell körning med asyncio
async def run_parallel(assignments):
    tasks = [
        run_worker(a["worker"], a["task"])
        for a in assignments
    ]
    results = await asyncio.gather(*tasks)
    return results
```

---

## Implementation Checklist

### Fas 2: MCP-lösning ✅
- [x] Kopiera prompts från apex CLI
- [x] Adaptera tools för API (inte subprocess)
- [x] Implementera SprintRunner med full orchestration
- [x] Lägg till Gemini-stöd
- [ ] Testa hela flödet (deploy till Railway)

### Fas 3: Web-förbättringar
- [ ] WebSocket för real-time logs
- [ ] Visuell progress-indikator
- [ ] Interaktiv Chef-dialog (question modal)
- [ ] Token/kostnadsvisning
- [ ] Dev-server preview (iframe)
- [ ] Cancel/pause-funktionalitet
- [ ] GitHub-integration
- [ ] Railway auto-deploy
- [ ] Sprint-historik
- [ ] Templates

---
