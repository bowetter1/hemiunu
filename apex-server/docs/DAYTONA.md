# Daytona Cloud Integration

Daytona provides cloud sandboxes for Apex projects. Each project gets an isolated Linux environment with file storage, process execution, database support, and a public preview URL.

## SDK Reference (v0.136.0)

```
pip install daytona
```

### Client

```python
from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams

client = Daytona(DaytonaConfig(api_key="dtn_...", target="eu"))  # "us" eller "eu"
sandbox = client.create(CreateSandboxFromImageParams(
    image="python:3.12-slim-bookworm",
    name="apex-my-project",
    env_vars={"FOO": "bar"},
))
```

All SDK calls are **synchronous**. In async FastAPI routes, wrap with `asyncio.to_thread()`.

### Filesystem

```python
# CRITICAL: upload_file treats str as LOCAL FILE PATH, not content.
# Always encode text to bytes first.
sandbox.fs.upload_file("hello".encode("utf-8"), "/workspace/file.txt")  # correct
sandbox.fs.upload_file(b"\x89PNG...", "/workspace/image.png")           # correct
sandbox.fs.upload_file("hello", "/workspace/file.txt")                  # WRONG — opens "hello" as file path

# Read — returns bytes | None
data = sandbox.fs.download_file("/workspace/file.txt")
text = data.decode("utf-8") if data else None

# Folders — creates intermediate dirs automatically
sandbox.fs.create_folder("/workspace/a/b/c", mode="755")

# List — returns list[FileInfo] with .name, .is_dir, .size
files = sandbox.fs.list_files("/workspace")

# Check existence
info = sandbox.fs.get_file_info("/workspace/file.txt")  # raises if not found

# Delete
sandbox.fs.delete_file("/workspace/file.txt")
sandbox.fs.delete_file("/workspace/dir", recursive=True)
```

### Process

```python
result = sandbox.process.exec("python3 --version", cwd="/workspace", timeout=60)
# result.exit_code: int
# result.result: str (stdout)
```

### Git

Git is **not installed** in `python:3.12-slim-bookworm`. Install it first:

```python
sandbox.process.exec("apt-get update -qq && apt-get install -y -qq git", timeout=180)
sandbox.process.exec('git config --global user.email "apex@apex.dev"')
sandbox.process.exec('git config --global user.name "Apex"')
```

The SDK also has `sandbox.git.clone(url, path, branch=)` but using `process.exec` for git operations is simpler and gives you exit codes.

### Preview URLs

```python
# Start a server first
sandbox.process.exec("nohup python3 -m http.server 8000 --directory /workspace/public > /dev/null 2>&1 &")

# Get public URL
preview = sandbox.get_preview_link(8000)
preview.url    # "https://8000-{id}.proxy.daytona.works"
preview.token  # auth token for private sandboxes
```

First visit shows a Daytona warning page ("I Understand, Continue"). Can be disabled per-organization in Daytona settings.

### Lifecycle

```python
sandbox.stop()   # ~10s, files persist
sandbox.start()  # ~10s, files survive restart
sandbox.delete() # permanent
```

## Databases

Tested and verified in `python:3.12-slim-bookworm`:

### SQLite
Works out of the box — Python has it built in.

### PostgreSQL

```python
sandbox.process.exec("apt-get update -qq && apt-get install -y -qq postgresql postgresql-client", timeout=180)
sandbox.process.exec("pg_ctlcluster 15 main start")

# Fix: default peer auth blocks root user. Switch to trust for local connections.
sandbox.process.exec("sed -i 's/peer/trust/g' /etc/postgresql/15/main/pg_hba.conf")
sandbox.process.exec("pg_ctlcluster 15 main reload")

# Now works from any user
sandbox.process.exec("psql -U postgres -c 'CREATE DATABASE myapp'")
```

Python connection: `psycopg2.connect(dbname="myapp", user="postgres")`

### Redis

```python
sandbox.process.exec("apt-get install -y -qq redis-server", timeout=120)
sandbox.process.exec("redis-server --daemonize yes")
# Ready on localhost:6379
```

### MongoDB
Does **not** install on `slim` images (missing repos/dependencies). Options:
- Use a dedicated MongoDB image: `CreateSandboxFromImageParams(image="mongo:7")`
- Use docker-compose inside the sandbox
- Use `mongomock` for testing

## Architecture

```
Railway (Apex Server)          Daytona Cloud (Sandboxes)
┌─────────────────────┐        ┌──────────────────────┐
│ FastAPI + PostgreSQL │        │ Sandbox per project   │
│                     │        │ ┌──────────────────┐  │
│ DaytonaService ─────────────>│ │ /workspace/       │  │
│   create_sandbox()  │  SDK   │ │ ├── public/       │  │
│   get_sandbox()     │  calls │ │ ├── .apex/        │  │
│   exec_command()    │        │ │ ├── src/          │  │
│   get_preview_url() │        │ │ └── .gitignore    │  │
│                     │        │ └──────────────────┘  │
│ FileSystemService   │        │                       │
│ (legacy, local disk)│        │ PostgreSQL, Redis,    │
│                     │        │ Python, Node, etc.    │
│ DaytonaFileSystem   │        │                       │
│ Service (new)       │        │ Preview URL:          │
│                     │        │ https://8000-{id}     │
└─────────────────────┘        │   .proxy.daytona.works│
                               └──────────────────────┘
```

## Configuration

Environment variables (set in Railway):

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `DAYTONA_API_KEY` | str | `""` | Daytona Cloud API key |
| `DAYTONA_ENABLED` | bool | `false` | Enable sandbox creation |
| `DAYTONA_DEFAULT_IMAGE` | str | `python:3.12-slim-bookworm` | Default Docker image |

## Key Files

| File | Purpose |
|------|---------|
| `integrations/daytona_service.py` | Singleton managing sandbox lifecycle |
| `projects/filesystem.py` | `DaytonaFileSystemService` + `get_filesystem()` factory |
| `projects/routes.py` | Sandbox endpoints + async wrapping |
| `projects/models.py` | `sandbox_id`, `sandbox_status`, `sandbox_preview_url` columns |
| `projects/generator/base.py` | Pipeline uses `get_filesystem()` factory |

## Gotchas

1. **`upload_file(str, dst)` = local file path.** Text content must be `.encode("utf-8")` to bytes first. This is the #1 bug source.

2. **Sync SDK in async FastAPI.** All Daytona calls block the event loop. Wrap with `await asyncio.to_thread(daytona_service.method, args)`.

3. **Git not in slim images.** `python:3.12-slim-bookworm` has no git. Install with apt-get (takes ~30s) and configure `user.email`/`user.name` before commits.

4. **PostgreSQL peer auth.** Default `pg_hba.conf` uses `peer` auth which fails when connecting as root. Change to `trust` for sandbox use.

5. **Sandbox caching.** `DaytonaService` caches sandboxes by `project_id`. If a project gets a new sandbox, validate `sandbox_id` matches the cache.

6. **Preview warning page.** First visit to any preview URL shows a Daytona warning. Can be disabled in organization settings.

7. **Process output.** `process.exec()` returns `ExecuteResponse` with `.exit_code` and `.result` (stdout). Stderr is not separate — redirect with `2>&1` if needed.

8. **Timeouts.** `apt-get install` needs `timeout=180`, `git clone` needs `timeout=120`. Default is too short for package installs.

9. **Region availability.** `target="us"` kan ge "Region us is not available to the organization". Använd `target="eu"` istället. Kontrollera vilken region som är tillgänglig för ditt konto.

10. **SDK-metoder ändras.** `d.get(sandbox_id)` fungerar, inte `d.get_sandbox()` eller `d.get_current_sandbox()`. `process.exec()` returnerar `.result` (inte `.output`). Kolla alltid `dir(obj)` vid osäkerhet.

11. **Next.js builds OOM:ar i sandbox.** 1GB cgroup räcker inte för `next build` med Turbopack. Använd Railway/Fly.io Docker builder istället. Sandbox funkar bra för Vite builds och preview/development.

## Node.js Sandboxes

Image: `node:20-slim`

### npm vs pnpm

**pnpm OOM:ar i 1GB cgroup** (exit code 137). Använd npm:

```python
sb.process.exec(
    "cd /workspace/app && npm install --legacy-peer-deps --no-optional --ignore-scripts",
    timeout=300
)
```

`--legacy-peer-deps` hanterar peer dependency-konflikter. `--ignore-scripts` hoppar over postinstall-scripts som kan kräva extra minne.

### Vite Build

Cgroup-gräns = 1GB. Vite build behöver ~700MB. Sätt max heap:

```python
sb.process.exec(
    "cd /workspace/app && NODE_OPTIONS='--max-old-space-size=768' npx vite build 2>&1",
    timeout=300
)
```

**Frigör minne före build** — döda zombie-processer:

```python
sb.process.exec("""
for p in /proc/[0-9]*/cmdline; do
    pid=$(dirname $p | xargs basename)
    cmd=$(cat $p 2>/dev/null | tr '\\0' ' ')
    case $cmd in *node*) kill -9 $pid 2>/dev/null;; esac
done
""")
```

### Static Server (SPA)

`serve` npm-paketet binder inte pålitligt till angiven port i Daytona. Använd custom server:

```javascript
const http = require("http");
const fs = require("fs");
const path = require("path");
const PORT = 3000;
const DIR = "/workspace/app/dist";
const MIME = {
  ".html":"text/html",".js":"application/javascript",
  ".css":"text/css",".json":"application/json",
  ".png":"image/png",".svg":"image/svg+xml",
  ".ico":"image/x-icon",".woff2":"font/woff2"
};
http.createServer((req, res) => {
  const url = req.url.split("?")[0];
  let filePath = path.join(DIR, url === "/" ? "index.html" : url);
  const ext = path.extname(filePath);
  if (!ext) filePath = path.join(DIR, "index.html"); // SPA fallback
  fs.readFile(filePath, (err, data) => {
    if (err) {
      fs.readFile(path.join(DIR, "index.html"), (e2, d2) => {
        res.writeHead(200, {"Content-Type":"text/html"});
        res.end(d2);
      });
      return;
    }
    res.writeHead(200, {"Content-Type": MIME[ext] || "application/octet-stream"});
    res.end(data);
  });
}).listen(PORT);
```

### node:20-slim — saknade verktyg

Dessa finns **inte**: `ps`, `fuser`, `ss`, `pgrep`, `pkill`, `killall`, `curl`, `python3`, `wget`.

Dessa **finns**: `node`, `npm`, `npx`, `bash`, `sh`, `sed`, `grep`, `awk`, `kill`, `cat`, `ls`, `find`, `xargs`, `basename`, `dirname`.

Iterera `/proc/[0-9]*/cmdline` för processöversikt istället för `ps`.

### Upload-gräns

`sb.fs.upload_file()` har en gräns på ~5MB. Större filer returnerar 400 Bad Request. **Bygg inne i sandboxen** istället för att uploada build-artefakter.

## Performance (measured)

| Operation | Time |
|-----------|------|
| Create sandbox | ~10s |
| Upload file | <1s |
| Download file | <1s |
| List files | <1s |
| Process exec (simple) | <1s |
| apt-get install git | ~30s |
| apt-get install postgresql | ~45s |
| npm install (React-app) | ~45s |
| Vite build (React-app) | ~27s |
| Stop sandbox | ~10s |
| Start sandbox | ~10s |
| Delete sandbox | <1s |
| Preview URL generation | <1s |
