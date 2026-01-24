# Scaling Apex to 20 Agents

## Current State (7-10 workers)

```
                    CHEF (Claude)
                         │
    ┌────────────────────┼────────────────────┐
    │                    │                    │
  ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐ ┌─┴─┐
  │AD │ │Arch│ │BE │ │FE │ │Test│ │Rev│ │DevOps│
  └───┘ └───┘ └───┘ └───┘ └───┘ └───┘ └───────┘
```

**Bottlenecks:**
- 1 session per role (can't have 3 backend workers)
- Sequential subprocess calls
- 4 min timeout per worker
- No task queue - fire-and-wait

---

## Target State: 20 Agents

### Architecture: Hierarchical Teams

```
                         CHEF (Claude Opus)
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────┴────┐          ┌────┴────┐          ┌────┴────┐
    │ PRODUCT │          │   DEV   │          │   QA    │
    │  LEAD   │          │  LEAD   │          │  LEAD   │
    │(Claude) │          │(Claude) │          │(Claude) │
    └────┬────┘          └────┬────┘          └────┬────┘
         │                    │                    │
    ┌────┴────┐     ┌─────────┼─────────┐    ┌────┴────┐
    │         │     │         │         │    │         │
  ┌─┴─┐    ┌──┴──┐ ┌┴─┐ ┌──┴──┐ ┌───┴───┐  ┌┴─┐    ┌──┴──┐
  │AD │    │Arch │ │BE│ │ BE  │ │  BE   │  │T1│    │ T2  │
  │ 1 │    │  1  │ │1 │ │  2  │ │   3   │  │  │    │     │
  └───┘    └─────┘ └──┘ └─────┘ └───────┘  └──┘    └─────┘
                      │
              ┌───────┼───────┐
              │       │       │
            ┌─┴─┐   ┌─┴─┐   ┌─┴─┐
            │FE │   │FE │   │FE │
            │ 1 │   │ 2 │   │ 3 │
            └───┘   └───┘   └───┘
```

### Team Structure (20 agents)

| Team | Lead | Workers | Total |
|------|------|---------|-------|
| Product | Product Lead | AD, Architect | 3 |
| Dev - Backend | Dev Lead | BE-1, BE-2, BE-3 | 4 |
| Dev - Frontend | Dev Lead | FE-1, FE-2, FE-3 | 3 |
| Dev - Integration | Dev Lead | Integration | 1 |
| QA | QA Lead | Tester-1, Tester-2, Reviewer, Security, E2E | 6 |
| Infrastructure | DevOps Lead | DevOps-1, DevOps-2 | 3 |
| **Total** | **4 leads** | **16 workers** | **20** |

---

## Implementation

### 1. Worker Pool with Instance IDs

```python
# Current: one session per role
WORKER_SESSIONS = {
    "backend": "session-123"  # Only ONE backend!
}

# New: pool of workers per role
WORKER_POOL = {
    "backend": {
        "backend-1": {"session": "abc", "status": "idle", "ai": "claude"},
        "backend-2": {"session": "def", "status": "busy", "ai": "codex"},
        "backend-3": {"session": "ghi", "status": "idle", "ai": "claude"},
    },
    "frontend": {
        "frontend-1": {"session": "jkl", "status": "idle", "ai": "claude"},
        "frontend-2": {"session": "mno", "status": "busy", "ai": "codex"},
        "frontend-3": {"session": "pqr", "status": "idle", "ai": "claude"},
    },
    # ...
}

def get_available_worker(role: str) -> str | None:
    """Get an idle worker from the pool."""
    for worker_id, state in WORKER_POOL.get(role, {}).items():
        if state["status"] == "idle":
            state["status"] = "busy"
            return worker_id
    return None

def release_worker(worker_id: str):
    """Return worker to pool."""
    role = worker_id.rsplit("-", 1)[0]
    if worker_id in WORKER_POOL.get(role, {}):
        WORKER_POOL[role][worker_id]["status"] = "idle"
```

### 2. Task Queue (Redis or SQLite)

```python
# task_queue.py
from dataclasses import dataclass
from enum import Enum
import uuid

class TaskStatus(Enum):
    PENDING = "pending"
    ASSIGNED = "assigned"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"

@dataclass
class Task:
    id: str
    role: str  # "backend", "frontend", etc.
    prompt: str
    priority: int = 0
    status: TaskStatus = TaskStatus.PENDING
    assigned_to: str | None = None  # worker instance ID
    result: str | None = None

class TaskQueue:
    """Central task queue for worker coordination."""

    def __init__(self):
        self.tasks: dict[str, Task] = {}
        self.pending: list[str] = []

    def add_task(self, role: str, prompt: str, priority: int = 0) -> str:
        task = Task(
            id=str(uuid.uuid4()),
            role=role,
            prompt=prompt,
            priority=priority
        )
        self.tasks[task.id] = task
        self.pending.append(task.id)
        self.pending.sort(key=lambda x: self.tasks[x].priority, reverse=True)
        return task.id

    def get_next_task(self, role: str) -> Task | None:
        """Get next pending task for a role."""
        for task_id in self.pending:
            task = self.tasks[task_id]
            if task.role == role and task.status == TaskStatus.PENDING:
                return task
        return None

    def assign_task(self, task_id: str, worker_id: str):
        task = self.tasks[task_id]
        task.status = TaskStatus.ASSIGNED
        task.assigned_to = worker_id
        self.pending.remove(task_id)
```

### 3. Team Leads (Sub-coordinators)

```python
# team_leads.py
TEAM_LEAD_PROMPT = """
You are {team_name} LEAD. You coordinate {team_size} workers.

YOUR WORKERS:
{worker_list}

YOUR RESPONSIBILITIES:
1. Break the task into sub-tasks
2. Assign sub-tasks to available workers
3. Monitor progress and handle failures
4. Report summary back to Chef

TOOLS:
- assign_worker(worker_id, task) - assign task to specific worker
- check_worker_status(worker_id) - check if worker is done
- get_worker_result(worker_id) - get worker output
- report_to_chef(summary) - report completion

TASK FROM CHEF:
{task}
"""

def create_team_lead(team_name: str, workers: list[str], task: str) -> str:
    """Create a team lead prompt."""
    return TEAM_LEAD_PROMPT.format(
        team_name=team_name,
        team_size=len(workers),
        worker_list="\n".join(f"- {w}" for w in workers),
        task=task
    )
```

### 4. Async Execution (for 20 concurrent)

```python
# async_runner.py
import asyncio
from typing import Callable

async def run_cli_async(cli: str, prompt: str, cwd: str, worker_id: str) -> str:
    """Run CLI asynchronously."""
    cmd = build_command(cli, prompt, worker_id)

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd
    )

    try:
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(),
            timeout=240
        )
        return stdout.decode()
    except asyncio.TimeoutError:
        proc.kill()
        return "ERROR: Timeout"

async def run_parallel_workers(tasks: list[dict], max_concurrent: int = 20):
    """Run up to 20 workers concurrently."""
    semaphore = asyncio.Semaphore(max_concurrent)

    async def run_with_semaphore(task):
        async with semaphore:
            return await run_cli_async(
                task["cli"],
                task["prompt"],
                task["cwd"],
                task["worker_id"]
            )

    results = await asyncio.gather(*[
        run_with_semaphore(t) for t in tasks
    ])
    return results
```

### 5. Modified assign_parallel for 20 workers

```python
# delegation.py (updated)

def assign_parallel_v2(arguments: dict, cwd: str) -> dict:
    """Run up to 20 workers in parallel using worker pool."""
    assignments = arguments.get("assignments", [])

    # Get available workers from pool
    worker_assignments = []
    for a in assignments:
        role = a["worker"]
        worker_id = get_available_worker(role)

        if not worker_id:
            # No worker available - add to queue or create new
            worker_id = create_worker_instance(role)

        worker_assignments.append({
            "worker_id": worker_id,
            "task": a["task"],
            "context": a.get("context", ""),
            "file": a.get("file", ""),
        })

    # Run all workers concurrently (async)
    results = asyncio.run(run_parallel_workers([
        {
            "cli": get_worker_cli(wa["worker_id"].rsplit("-", 1)[0]),
            "prompt": build_prompt(wa),
            "cwd": cwd,
            "worker_id": wa["worker_id"]
        }
        for wa in worker_assignments
    ]))

    # Release workers back to pool
    for wa in worker_assignments:
        release_worker(wa["worker_id"])

    return make_response(f"Completed {len(results)} parallel tasks")
```

---

## Configuration

### config.py updates

```python
# Worker pool configuration
WORKER_POOL_CONFIG = {
    "ad": {"min": 1, "max": 2, "default_ai": "claude"},
    "architect": {"min": 1, "max": 2, "default_ai": "claude"},
    "backend": {"min": 1, "max": 5, "default_ai": "codex"},
    "frontend": {"min": 1, "max": 5, "default_ai": "claude"},
    "tester": {"min": 1, "max": 3, "default_ai": "claude"},
    "reviewer": {"min": 1, "max": 2, "default_ai": "claude"},
    "security": {"min": 1, "max": 2, "default_ai": "codex"},
    "devops": {"min": 1, "max": 2, "default_ai": "claude"},
    "e2e": {"min": 1, "max": 2, "default_ai": "claude"},
}

# Team configuration
TEAMS = {
    "product": ["ad", "architect"],
    "backend": ["backend"],
    "frontend": ["frontend"],
    "qa": ["tester", "reviewer", "security", "e2e"],
    "infra": ["devops"],
}

# Max concurrent workers
MAX_CONCURRENT_WORKERS = 20
```

---

## Sprint Flow with 20 Agents

### Phase 1: Parallel Planning (3 workers)
```
assign_parallel([
    {worker: "devops", task: "Probe environment"},
    {worker: "ad", task: "Design system"},
    {worker: "architect", task: "Create PLAN.md with 15-20 modules"}
])
```

### Phase 2: Mega Parallel Build (15-20 workers!)
```
# Architect outputs 15-20 modules
# Chef runs ALL in parallel:

assign_parallel([
    # Backend team (5 workers)
    {worker: "backend", task: "Module 1: auth.py"},
    {worker: "backend", task: "Module 2: models.py"},
    {worker: "backend", task: "Module 3: api_users.py"},
    {worker: "backend", task: "Module 4: api_items.py"},
    {worker: "backend", task: "Module 5: database.py"},

    # Frontend team (5 workers)
    {worker: "frontend", task: "Module 6: index.html"},
    {worker: "frontend", task: "Module 7: style.css"},
    {worker: "frontend", task: "Module 8: app.js"},
    {worker: "frontend", task: "Module 9: components/auth.js"},
    {worker: "frontend", task: "Module 10: components/list.js"},

    # More frontend (5 workers)
    {worker: "frontend", task: "Module 11: components/form.js"},
    {worker: "frontend", task: "Module 12: components/modal.js"},
    {worker: "frontend", task: "Module 13: utils/api.js"},
    {worker: "frontend", task: "Module 14: utils/validation.js"},
    {worker: "frontend", task: "Module 15: main.py server"},
])
```

### Phase 3: Integration (1-2 workers)
```
assign_frontend("Integrate all modules", ai="claude")
assign_backend("Wire up all endpoints", ai="claude")
```

### Phase 4: QA Blitz (6 workers parallel!)
```
assign_parallel([
    {worker: "ad", task: "Final design review"},
    {worker: "tester", task: "Write unit tests"},
    {worker: "tester", task: "Write integration tests"},
    {worker: "reviewer", task: "Code review backend"},
    {worker: "reviewer", task: "Code review frontend"},
    {worker: "security", task: "OWASP audit"},
    {worker: "e2e", task: "Playwright verification"},
])
```

---

## Benefits of 20 Agents

| Metric | 8 Workers | 20 Workers | Improvement |
|--------|-----------|------------|-------------|
| Module parallelism | 8 at once | 20 at once | 2.5x |
| Build time | ~10 min | ~4 min | 2.5x faster |
| QA coverage | 3 parallel | 6 parallel | 2x |
| Specialization | Limited | Deep | Better quality |

---

## Implementation Phases

### Phase 1: Worker Pool (Week 1)
- [ ] Add instance IDs to workers
- [ ] Implement worker pool manager
- [ ] Update session tracking

### Phase 2: Async Execution (Week 1)
- [ ] Convert to asyncio
- [ ] Handle 20 concurrent subprocesses
- [ ] Improve timeout handling

### Phase 3: Task Queue (Week 2)
- [ ] Implement SQLite task queue
- [ ] Add task priorities
- [ ] Handle retries

### Phase 4: Team Leads (Week 2)
- [ ] Create team lead prompts
- [ ] Implement sub-coordination
- [ ] Test hierarchical execution

### Phase 5: Integration (Week 3)
- [ ] Update Chef prompt
- [ ] Add monitoring/logging
- [ ] Performance testing

---

## Apex-Server Specific Implementation

The apex-server already uses direct LLM API calls (Anthropic, Google, Groq) instead of CLI subprocesses.
This is a better foundation for scaling.

### Current Workers Architecture in apex-server

```python
# apex_server/workers/config.py
ROLES = {
    "chef":      {"name": "Chef",      "icon": "👨‍🍳", "model": "opus"},
    "ad":        {"name": "AD",        "icon": "🎨",  "model": "haiku"},
    "architect": {"name": "Architect", "icon": "🏗️",  "model": "haiku"},
    # ... 9 roles total
}

TEAMS = {
    "a-team": { ... },   # Opus + Haiku mix
    "groq-team": { ... } # All Groq (fast & cheap)
}
```

### Changes Needed for 20 Workers

#### 1. Worker Pool Manager (new file)

```python
# apex_server/workers/pool.py
from dataclasses import dataclass, field
from typing import Optional
import asyncio
import uuid

@dataclass
class WorkerInstance:
    id: str
    role: str
    model: str
    status: str = "idle"  # idle, busy, error
    session_id: Optional[str] = None
    current_task_id: Optional[str] = None

@dataclass
class WorkerPool:
    """Pool of worker instances per role."""
    instances: dict[str, WorkerInstance] = field(default_factory=dict)
    _lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def get_worker(self, role: str) -> Optional[WorkerInstance]:
        """Get an available worker for a role."""
        async with self._lock:
            for worker in self.instances.values():
                if worker.role == role and worker.status == "idle":
                    worker.status = "busy"
                    return worker
            return None

    async def release_worker(self, worker_id: str):
        """Release a worker back to the pool."""
        async with self._lock:
            if worker_id in self.instances:
                self.instances[worker_id].status = "idle"
                self.instances[worker_id].current_task_id = None

    def add_worker(self, role: str, model: str) -> WorkerInstance:
        """Add a new worker instance to the pool."""
        worker = WorkerInstance(
            id=f"{role}-{uuid.uuid4().hex[:8]}",
            role=role,
            model=model
        )
        self.instances[worker.id] = worker
        return worker

# Global pool
WORKER_POOL = WorkerPool()

def initialize_pool(team: str = "a-team"):
    """Initialize worker pool with configured team."""
    from .config import TEAMS, WORKER_POOL_CONFIG

    team_config = TEAMS[team]["workers"]

    for role, count in WORKER_POOL_CONFIG.items():
        model = team_config.get(role, "haiku")
        for _ in range(count["initial"]):
            WORKER_POOL.add_worker(role, model)

WORKER_POOL_CONFIG = {
    "chef": {"initial": 1, "max": 1},
    "ad": {"initial": 2, "max": 3},
    "architect": {"initial": 2, "max": 3},
    "backend": {"initial": 4, "max": 6},
    "frontend": {"initial": 4, "max": 6},
    "tester": {"initial": 2, "max": 4},
    "reviewer": {"initial": 2, "max": 3},
    "security": {"initial": 1, "max": 2},
    "devops": {"initial": 2, "max": 3},
}
```

#### 2. Async Parallel Execution

```python
# apex_server/workers/executor.py
import asyncio
from typing import Any
import anthropic
import google.generativeai as genai
from groq import Groq

async def call_anthropic(model: str, prompt: str, tools: list) -> dict:
    """Call Anthropic API asynchronously."""
    client = anthropic.AsyncAnthropic()
    response = await client.messages.create(
        model=model,
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
        tools=tools,
    )
    return response

async def call_groq(model: str, prompt: str, tools: list) -> dict:
    """Call Groq API asynchronously."""
    client = Groq()
    # Groq is sync but fast enough to run in thread
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(None, lambda: client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        tools=tools,
    ))
    return response

async def execute_worker_task(
    worker_id: str,
    prompt: str,
    tools: list,
    model: str,
    provider: str
) -> dict:
    """Execute a task with a specific worker."""
    if provider == "anthropic":
        return await call_anthropic(model, prompt, tools)
    elif provider == "groq":
        return await call_groq(model, prompt, tools)
    # Add more providers...

async def execute_parallel_tasks(tasks: list[dict]) -> list[dict]:
    """Execute multiple tasks in parallel (up to 20)."""
    semaphore = asyncio.Semaphore(20)

    async def run_with_limit(task):
        async with semaphore:
            worker = await WORKER_POOL.get_worker(task["role"])
            if not worker:
                # Create new worker if pool allows
                worker = WORKER_POOL.add_worker(task["role"], task["model"])

            try:
                result = await execute_worker_task(
                    worker.id,
                    task["prompt"],
                    task["tools"],
                    task["model"],
                    task["provider"]
                )
                return {"worker_id": worker.id, "result": result, "status": "success"}
            except Exception as e:
                return {"worker_id": worker.id, "error": str(e), "status": "error"}
            finally:
                await WORKER_POOL.release_worker(worker.id)

    return await asyncio.gather(*[run_with_limit(t) for t in tasks])
```

#### 3. Database Model Updates

```python
# apex_server/sprints/models.py - add WorkerInstance table
class WorkerInstance(Base):
    __tablename__ = "worker_instances"

    id = Column(String, primary_key=True)
    sprint_id = Column(UUID, ForeignKey("sprints.id"))
    role = Column(String)  # "backend", "frontend", etc.
    instance_num = Column(Integer)  # 1, 2, 3 for backend-1, backend-2, etc.
    model = Column(String)  # "haiku", "opus", etc.
    status = Column(String)  # "idle", "busy", "error"
    session_id = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    sprint = relationship("Sprint", back_populates="worker_instances")
    tasks = relationship("WorkerTask", back_populates="worker_instance")


class WorkerTask(Base):
    __tablename__ = "worker_tasks"

    id = Column(Integer, primary_key=True, autoincrement=True)
    worker_instance_id = Column(String, ForeignKey("worker_instances.id"))
    sprint_id = Column(UUID, ForeignKey("sprints.id"))
    prompt = Column(Text)
    result = Column(Text, nullable=True)
    status = Column(String)  # "pending", "running", "completed", "failed"
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    input_tokens = Column(Integer, default=0)
    output_tokens = Column(Integer, default=0)

    # Relationships
    worker_instance = relationship("WorkerInstance", back_populates="tasks")
    sprint = relationship("Sprint", back_populates="worker_tasks")
```

#### 4. WebSocket Updates for 20 Workers

```python
# apex_server/sprints/websocket.py - update for parallel worker events
async def broadcast_worker_event(sprint_id: str, event: dict):
    """Broadcast worker event to all connected clients."""
    message = {
        "type": "worker_event",
        "sprint_id": sprint_id,
        "worker_id": event["worker_id"],  # e.g., "backend-2"
        "worker_role": event["role"],
        "status": event["status"],  # "started", "progress", "completed", "error"
        "message": event.get("message", ""),
        "timestamp": datetime.utcnow().isoformat(),
    }
    await sprint_ws_manager.broadcast(sprint_id, json.dumps(message))

# Example events:
# {"type": "worker_event", "worker_id": "backend-1", "status": "started"}
# {"type": "worker_event", "worker_id": "backend-2", "status": "started"}
# {"type": "worker_event", "worker_id": "frontend-1", "status": "started"}
# ... (up to 20 parallel!)
# {"type": "worker_event", "worker_id": "backend-1", "status": "completed"}
```

#### 5. Frontend Updates for 20 Workers

```javascript
// apex_server/web/static/app.js - show 20 workers in grid
function renderWorkerGrid(workers) {
    const grid = document.getElementById('worker-grid');
    grid.innerHTML = '';

    // Group by role
    const byRole = {};
    workers.forEach(w => {
        if (!byRole[w.role]) byRole[w.role] = [];
        byRole[w.role].push(w);
    });

    // Render each role as a row
    for (const [role, instances] of Object.entries(byRole)) {
        const row = document.createElement('div');
        row.className = 'worker-row';
        row.innerHTML = `
            <span class="role-name">${role}</span>
            <div class="instances">
                ${instances.map(w => `
                    <div class="worker-dot ${w.status}" title="${w.id}">
                        ${w.status === 'busy' ? '⚡' : '●'}
                    </div>
                `).join('')}
            </div>
        `;
        grid.appendChild(row);
    }
}
```

---

## Summary: Scaling Path

| Component | Current | Target |
|-----------|---------|--------|
| Worker instances | 1 per role | 2-6 per role |
| Max concurrent | ~8 | 20 |
| Execution | Sequential/ThreadPool | Async |
| Session tracking | Global dict | Per-instance DB |
| API calls | Sync | Async |
| Frontend | Single worker view | Worker grid |

**Total effort estimate:** 2-3 weeks for full implementation
