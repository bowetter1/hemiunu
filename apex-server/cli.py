#!/usr/bin/env python3
"""Apex CLI — test tool for Daytona sandbox integration."""
import argparse
import json
import sys
import os
import time
import webbrowser

from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams

# State file for tracking projects
STATE_FILE = os.path.expanduser("~/.apex-cli.json")

# Images
IMAGES = {
    "python": "python:3.12-slim-bookworm",
    "node": "node:20-slim",
}


def get_client():
    key = os.environ.get("DAYTONA_API_KEY", "")
    if not key:
        # Try loading from state
        state = load_state()
        key = state.get("api_key", "")
    if not key:
        print("No API key. Set DAYTONA_API_KEY or run: apex config <key>")
        sys.exit(1)
    return Daytona(DaytonaConfig(api_key=key))


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"projects": {}}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def resolve_project(name_or_id):
    """Resolve a short name or ID to full sandbox details."""
    state = load_state()
    projects = state.get("projects", {})

    # Try exact match
    if name_or_id in projects:
        return projects[name_or_id]

    # Try matching sandbox_id prefix
    for name, info in projects.items():
        if info["sandbox_id"].startswith(name_or_id):
            return info

    # Try name substring
    for name, info in projects.items():
        if name_or_id in name:
            return info

    print(f"Project not found: {name_or_id}")
    print(f"Run 'apex list' to see projects.")
    sys.exit(1)


# === Commands ===

def cmd_config(args):
    """Save API key."""
    state = load_state()
    state["api_key"] = args.api_key
    save_state(state)
    print(f"API key saved to {STATE_FILE}")


def cmd_create(args):
    """Create a new project with a Daytona sandbox."""
    client = get_client()
    name = args.name
    image = IMAGES.get(args.image, args.image)

    print(f"Creating sandbox '{name}' ({image})...")
    t0 = time.time()
    sandbox = client.create(CreateSandboxFromImageParams(
        image=image,
        name=f"apex-{name}",
        env_vars={"APEX_PROJECT": name},
    ))
    t1 = time.time()
    print(f"Sandbox ready in {t1-t0:.1f}s")
    print(f"  ID: {sandbox.id}")

    # Setup workspace
    print("Setting up workspace...")
    sandbox.fs.create_folder("/workspace/public", mode="755")
    sandbox.fs.create_folder("/workspace/src", mode="755")
    sandbox.fs.create_folder("/workspace/.apex/versions", mode="755")
    sandbox.fs.upload_file(
        ".apex/\n.env\n__pycache__/\nnode_modules/\n.DS_Store\n".encode("utf-8"),
        "/workspace/.gitignore",
    )

    # Install git
    print("Installing git...")
    sandbox.process.exec("apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1", timeout=180)
    sandbox.process.exec('git config --global user.email "apex@apex.dev"')
    sandbox.process.exec('git config --global user.name "Apex"')
    sandbox.process.exec("git init", cwd="/workspace")
    sandbox.process.exec("git add .", cwd="/workspace")
    sandbox.process.exec('git commit -m "Initial commit"', cwd="/workspace")

    # Save to state
    state = load_state()
    state.setdefault("projects", {})[name] = {
        "sandbox_id": sandbox.id,
        "image": image,
        "created": time.strftime("%Y-%m-%d %H:%M"),
    }
    save_state(state)

    print(f"\nProject '{name}' ready!")
    print(f"  apex exec {name} 'echo hello'")
    print(f"  apex upload {name} index.html")
    print(f"  apex preview {name}")


def cmd_list(args):
    """List all projects."""
    state = load_state()
    projects = state.get("projects", {})

    if not projects:
        print("No projects. Run 'apex create <name>' to create one.")
        return

    client = get_client()
    print(f"{'Name':<20} {'Sandbox ID':<40} {'Status':<12} {'Created'}")
    print("-" * 90)
    for name, info in projects.items():
        status = "?"
        try:
            sb = client.get(info["sandbox_id"])
            status = str(sb.state).replace("SandboxState.", "")
        except Exception:
            status = "DELETED"
        print(f"{name:<20} {info['sandbox_id']:<40} {status:<12} {info.get('created', '?')}")


def cmd_status(args):
    """Show project status."""
    info = resolve_project(args.project)
    client = get_client()

    try:
        sb = client.get(info["sandbox_id"])
    except Exception as e:
        print(f"Sandbox not found: {e}")
        return

    print(f"Project:  {args.project}")
    print(f"Sandbox:  {sb.id}")
    print(f"State:    {sb.state}")
    print(f"Image:    {info.get('image', '?')}")
    print(f"Created:  {info.get('created', '?')}")

    # List workspace files
    try:
        files = sb.fs.list_files("/workspace")
        print(f"\nFiles in /workspace:")
        for f in files:
            icon = "dir " if f.is_dir else "file"
            print(f"  {icon}  {f.name}")
    except Exception:
        pass


def cmd_exec(args):
    """Execute a command in the sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    cmd = " ".join(args.command)
    result = sb.process.exec(cmd, cwd=args.cwd or "/workspace", timeout=args.timeout)
    if result.result:
        print(result.result, end="" if result.result.endswith("\n") else "\n")
    if result.exit_code != 0:
        print(f"[exit {result.exit_code}]", file=sys.stderr)
        sys.exit(result.exit_code)


def cmd_upload(args):
    """Upload a local file to the sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    local_path = args.file
    if not os.path.exists(local_path):
        print(f"File not found: {local_path}")
        sys.exit(1)

    remote_path = args.dest or f"/workspace/public/{os.path.basename(local_path)}"

    with open(local_path, "rb") as f:
        data = f.read()

    # Ensure parent dir exists
    parent = "/".join(remote_path.split("/")[:-1])
    try:
        sb.fs.create_folder(parent, mode="755")
    except Exception:
        pass

    sb.fs.upload_file(data, remote_path)
    print(f"Uploaded {local_path} -> {remote_path} ({len(data)} bytes)")


def cmd_download(args):
    """Download a file from the sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    remote_path = args.path
    if not remote_path.startswith("/"):
        remote_path = f"/workspace/{remote_path}"

    data = sb.fs.download_file(remote_path)
    if data is None:
        print(f"File not found: {remote_path}")
        sys.exit(1)

    local_path = args.output or os.path.basename(remote_path)
    with open(local_path, "wb") as f:
        f.write(data)
    print(f"Downloaded {remote_path} -> {local_path} ({len(data)} bytes)")


def cmd_preview(args):
    """Start HTTP server and open preview URL."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    port = args.port

    # Start server if not running
    check = sb.process.exec(f"lsof -i :{port} 2>/dev/null | grep LISTEN || echo NOT_RUNNING")
    if "NOT_RUNNING" in check.result:
        print(f"Starting HTTP server on port {port}...")
        sb.process.exec(
            f"nohup python3 -m http.server {port} --directory /workspace/public > /dev/null 2>&1 &",
            cwd="/workspace",
        )
        time.sleep(2)

    preview = sb.get_preview_link(port)
    print(f"URL:   {preview.url}")
    print(f"Token: {preview.token[:40]}..." if preview.token else "Token: (none)")

    if not args.no_open:
        webbrowser.open(preview.url)


def cmd_deploy(args):
    """Write HTML content and start preview."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    html_file = args.file
    if not os.path.exists(html_file):
        print(f"File not found: {html_file}")
        sys.exit(1)

    with open(html_file, "rb") as f:
        data = f.read()

    sb.fs.upload_file(data, "/workspace/public/index.html")
    print(f"Uploaded {html_file} -> /workspace/public/index.html")

    # Git commit
    sb.process.exec("git add .", cwd="/workspace")
    sb.process.exec(f'git commit -m "Deploy {os.path.basename(html_file)}"', cwd="/workspace")

    # Start server + get URL
    port = args.port
    sb.process.exec(
        f"nohup python3 -m http.server {port} --directory /workspace/public > /dev/null 2>&1 &",
        cwd="/workspace",
    )
    time.sleep(2)
    preview = sb.get_preview_link(port)
    print(f"\nLive at: {preview.url}")

    if not args.no_open:
        webbrowser.open(preview.url)


def cmd_db(args):
    """Install and start a database in the sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])

    db_type = args.type

    if db_type == "postgres":
        print("Installing PostgreSQL...")
        r = sb.process.exec("apt-get update -qq && apt-get install -y -qq postgresql postgresql-client", timeout=180)
        if r.exit_code != 0:
            print(f"Install failed: {r.result}")
            return
        sb.process.exec("pg_ctlcluster 15 main start")
        sb.process.exec("sed -i 's/peer/trust/g' /etc/postgresql/15/main/pg_hba.conf")
        sb.process.exec("pg_ctlcluster 15 main reload")
        print("PostgreSQL ready!")
        print("  Connection: psql -U postgres")
        print("  Python: psycopg2.connect(dbname='mydb', user='postgres')")

    elif db_type == "redis":
        print("Installing Redis...")
        r = sb.process.exec("apt-get update -qq && apt-get install -y -qq redis-server", timeout=120)
        if r.exit_code != 0:
            print(f"Install failed: {r.result}")
            return
        sb.process.exec("redis-server --daemonize yes")
        print("Redis ready on localhost:6379")

    elif db_type == "sqlite":
        print("SQLite is built into Python — no install needed.")
        print("  Python: sqlite3.connect('/workspace/app.db')")

    else:
        print(f"Unknown database: {db_type}")
        print("Available: postgres, redis, sqlite")


def cmd_stop(args):
    """Stop a sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])
    sb.stop()
    print(f"Stopped {info['sandbox_id']}")


def cmd_start(args):
    """Start a stopped sandbox."""
    info = resolve_project(args.project)
    client = get_client()
    sb = client.get(info["sandbox_id"])
    sb.start()
    print(f"Started {info['sandbox_id']}")


def cmd_delete(args):
    """Delete a sandbox and remove from state."""
    info = resolve_project(args.project)
    client = get_client()
    try:
        sb = client.get(info["sandbox_id"])
        sb.delete()
    except Exception:
        pass

    state = load_state()
    # Find and remove by sandbox_id
    to_remove = [k for k, v in state.get("projects", {}).items() if v["sandbox_id"] == info["sandbox_id"]]
    for k in to_remove:
        del state["projects"][k]
    save_state(state)
    print(f"Deleted {info['sandbox_id']}")


def main():
    parser = argparse.ArgumentParser(prog="apex", description="Apex CLI — Daytona sandbox tool")
    sub = parser.add_subparsers(dest="subcmd")

    # config
    p = sub.add_parser("config", help="Save API key")
    p.add_argument("api_key")

    # create
    p = sub.add_parser("create", help="Create a new project")
    p.add_argument("name", help="Project name")
    p.add_argument("--image", default="python", help="Image: python, node, or full image name")

    # list
    sub.add_parser("list", aliases=["ls"], help="List projects")

    # status
    p = sub.add_parser("status", help="Show project status")
    p.add_argument("project", help="Project name or sandbox ID")

    # exec
    p = sub.add_parser("exec", help="Run a command in the sandbox")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("command", nargs=argparse.REMAINDER, help="Command to run")
    p.add_argument("--cwd", help="Working directory")
    p.add_argument("--timeout", type=int, default=120, help="Timeout in seconds")

    # upload
    p = sub.add_parser("upload", help="Upload a file to the sandbox")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("file", help="Local file path")
    p.add_argument("--dest", help="Remote path (default: /workspace/public/<filename>)")

    # download
    p = sub.add_parser("download", help="Download a file from the sandbox")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("path", help="Remote path")
    p.add_argument("--output", "-o", help="Local output path")

    # preview
    p = sub.add_parser("preview", help="Open preview URL in browser")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--no-open", action="store_true", help="Don't open browser")

    # deploy
    p = sub.add_parser("deploy", help="Upload HTML and start preview")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("file", help="HTML file to deploy")
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--no-open", action="store_true")

    # db
    p = sub.add_parser("db", help="Install a database")
    p.add_argument("project", help="Project name or sandbox ID")
    p.add_argument("type", help="Database: postgres, redis, sqlite")

    # stop / start / delete
    p = sub.add_parser("stop", help="Stop a sandbox")
    p.add_argument("project")

    p = sub.add_parser("start", help="Start a stopped sandbox")
    p.add_argument("project")

    p = sub.add_parser("delete", help="Delete a sandbox")
    p.add_argument("project")

    args = parser.parse_args()
    if not args.subcmd:
        parser.print_help()
        return

    cmd_map = {
        "config": cmd_config,
        "create": cmd_create,
        "list": cmd_list, "ls": cmd_list,
        "status": cmd_status,
        "exec": cmd_exec,
        "upload": cmd_upload,
        "download": cmd_download,
        "preview": cmd_preview,
        "deploy": cmd_deploy,
        "db": cmd_db,
        "stop": cmd_stop,
        "start": cmd_start,
        "delete": cmd_delete,
    }

    fn = cmd_map.get(args.subcmd)
    if fn:
        fn(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
