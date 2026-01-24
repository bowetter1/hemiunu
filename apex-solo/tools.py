"""
Apex Solo - Tools

Minimala tools för Driver att bygga med.
"""
import os
import subprocess
import json
import urllib.request
import urllib.error
import re
from pathlib import Path
from datetime import datetime


def get_project_dir() -> Path:
    """Hämta projektmapp från env."""
    return Path(os.environ.get("PROJECT_DIR", "."))


def log(message: str, log_type: str = None):
    """Logga till driver.log."""
    project = get_project_dir()
    log_file = project / "driver.log"
    timestamp = datetime.now().strftime("%H:%M:%S")

    # Formatera meddelande
    if log_type:
        formatted = f"[{timestamp}] {log_type}: {message}"
    else:
        formatted = f"[{timestamp}] {message}"

    with open(log_file, "a") as f:
        f.write(f"{formatted}\n")


# =============================================================================
# TOOLS
# =============================================================================

def thinking(thought: str) -> str:
    """
    Logga en tanke eller beslut.

    Använd för att visa resonemang och beslut.
    """
    log(f"THINK: {thought}")
    return "Logged."


def research(url: str, findings: str) -> str:
    """
    Logga research-aktivitet.

    Använd efter att ha surfat till en sida för att dokumentera vad du hittade.

    Args:
        url: URL som besöktes
        findings: Vad du lärde dig / såg
    """
    log(f"BROWSER: {url}")
    log(f"RESEARCH: {findings}")
    return "Research logged."


def browse_url(url: str) -> str:
    """
    Browse a URL and return the page content as text.

    Use this to research visual inspiration, game references, color palettes, etc.

    Args:
        url: Full URL to browse (e.g., "https://itch.io/games/top-rated")
    """
    log(f"BROWSE: {url}")

    try:
        # Set up request with browser-like headers
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
        }

        req = urllib.request.Request(url, headers=headers)

        with urllib.request.urlopen(req, timeout=30) as response:
            html = response.read().decode('utf-8', errors='ignore')

        # Strip HTML tags and clean up
        # Remove script and style elements
        html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
        html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL | re.IGNORECASE)

        # Remove HTML tags
        text = re.sub(r'<[^>]+>', ' ', html)

        # Clean up whitespace
        text = re.sub(r'\s+', ' ', text)
        text = text.strip()

        # Limit length to avoid token overflow
        if len(text) > 8000:
            text = text[:8000] + "\n\n[... truncated ...]"

        log(f"BROWSE_OK: {len(text)} chars from {url}")
        return f"Content from {url}:\n\n{text}"

    except urllib.error.HTTPError as e:
        log(f"BROWSE_ERROR: HTTP {e.code}")
        return f"Error: HTTP {e.code} - {e.reason}"
    except urllib.error.URLError as e:
        log(f"BROWSE_ERROR: {e.reason}")
        return f"Error: Could not reach {url} - {e.reason}"
    except Exception as e:
        log(f"BROWSE_ERROR: {e}")
        return f"Error: {e}"


def extract_colors(url: str) -> str:
    """
    Browse a URL and try to extract color codes (hex values).

    Useful for finding color palettes from design sites.

    Args:
        url: URL to a color palette or design page
    """
    log(f"EXTRACT_COLORS: {url}")

    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        }

        req = urllib.request.Request(url, headers=headers)

        with urllib.request.urlopen(req, timeout=30) as response:
            html = response.read().decode('utf-8', errors='ignore')

        # Find hex color codes
        hex_colors = re.findall(r'#[0-9A-Fa-f]{6}\b', html)
        hex_colors_short = re.findall(r'#[0-9A-Fa-f]{3}\b', html)

        # Find rgb colors
        rgb_colors = re.findall(r'rgb\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)', html, re.IGNORECASE)

        # Deduplicate and limit
        all_colors = list(dict.fromkeys(hex_colors + hex_colors_short))[:20]

        if not all_colors:
            return f"No color codes found on {url}"

        log(f"COLORS_FOUND: {len(all_colors)} colors")
        return f"Colors found on {url}:\n\n" + "\n".join(all_colors)

    except Exception as e:
        log(f"EXTRACT_ERROR: {e}")
        return f"Error extracting colors: {e}"


def vision(name: str, hook: str, target: str, unique: str, feeling: str) -> str:
    """
    Dokumentera projektvisionen.

    Använd efter research för att definiera din vision.

    Args:
        name: Spelets/projektets namn
        hook: Varför är detta oemotståndligt? (en mening)
        target: Målgrupp - vem, när, varför
        unique: Vad gör detta annorlunda?
        feeling: Vad ska användaren känna?
    """
    vision_text = f"""
═══════════════════════════════════════════════════════════
                        VISION
═══════════════════════════════════════════════════════════
SPEL: {name}
HOOK: {hook}
MÅLGRUPP: {target}
UNIKT: {unique}
KÄNSLA: {feeling}
═══════════════════════════════════════════════════════════"""
    log(f"VISION: {name} - {hook}")
    return vision_text


def write_file(path: str, content: str) -> str:
    """
    Skriv eller uppdatera en fil.

    Args:
        path: Relativ sökväg från projektmappen
        content: Filinnehåll
    """
    project = get_project_dir()
    file_path = project / path

    # Skapa parent directories
    file_path.parent.mkdir(parents=True, exist_ok=True)

    # Skriv fil
    file_path.write_text(content)

    lines = len(content.splitlines())
    log(f"WRITE: {path} ({lines} rader)")

    return f"Wrote {path} ({lines} lines)"


def read_file(path: str) -> str:
    """
    Läs en fil.

    Args:
        path: Relativ sökväg från projektmappen
    """
    project = get_project_dir()
    file_path = project / path

    if not file_path.exists():
        log(f"READ: {path} (finns ej)")
        return f"Error: {path} does not exist"

    log(f"READ: {path}")
    return file_path.read_text()


def list_files() -> str:
    """Lista alla filer i projektet."""
    project = get_project_dir()
    log("LIST: filer")

    files = []
    for f in sorted(project.rglob("*")):
        if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f):
            rel = f.relative_to(project)
            try:
                lines = len(f.read_text().splitlines())
                files.append(f"{rel} ({lines} lines)")
            except:
                files.append(str(rel))

    if not files:
        return "No files yet."

    return "\n".join(files)


def search_github(query: str, limit: int = 5) -> str:
    """
    Sök GitHub efter relevanta repos.

    Args:
        query: Sökfråga (t.ex. "javascript 2d game engine minimal")
        limit: Max antal resultat (default 5)
    """
    log(f"GITHUB_SEARCH: {query}")

    try:
        result = subprocess.run(
            ["gh", "search", "repos", query, "--limit", str(limit),
             "--json", "name,url,description,stargazersCount"],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            return f"Error: {result.stderr}"

        # Formatera output
        import json
        repos = json.loads(result.stdout) if result.stdout else []

        if not repos:
            return "Inga repos hittades."

        output = []
        for r in repos:
            stars = r.get('stargazersCount', 0)
            desc = r.get('description', 'Ingen beskrivning')[:100]
            output.append(f"⭐ {stars:,} | {r['name']}\n   {r['url']}\n   {desc}")

        log(f"GITHUB_FOUND: {len(repos)} repos")
        return "\n\n".join(output)

    except subprocess.TimeoutExpired:
        return "Error: GitHub search timeout"
    except Exception as e:
        return f"Error: {e}"


def clone_repo(repo_url: str, folder: str = "lib") -> str:
    """
    Klona ett GitHub-repo till projektet.

    Args:
        repo_url: GitHub URL (https://github.com/user/repo)
        folder: Mapp att klona till (default: "lib")
    """
    project = get_project_dir()
    target = project / folder

    log(f"GITHUB_CLONE: {repo_url} → {folder}")

    try:
        # Shallow clone för snabbhet
        result = subprocess.run(
            ["git", "clone", "--depth", "1", repo_url, str(target)],
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            log(f"CLONE_ERROR: {result.stderr}")
            return f"Error: {result.stderr}"

        # Lista vad som klonades
        files = list(target.rglob("*"))
        file_count = len([f for f in files if f.is_file()])

        log(f"CLONE_DONE: {file_count} filer")
        return f"Klonade {repo_url} till {folder}/ ({file_count} filer)"

    except subprocess.TimeoutExpired:
        return "Error: Clone timeout (120s)"
    except Exception as e:
        log(f"CLONE_ERROR: {e}")
        return f"Error: {e}"


def npm_install(package: str) -> str:
    """
    Installera npm-paket (för frontend-libs).

    Args:
        package: Paketnamn (t.ex. "phaser" eller "matter-js")
    """
    project = get_project_dir()
    log(f"NPM_INSTALL: {package}")

    try:
        # Skapa package.json om det inte finns
        package_json = project / "package.json"
        if not package_json.exists():
            package_json.write_text('{"name": "game", "version": "1.0.0"}')

        result = subprocess.run(
            ["npm", "install", package],
            cwd=str(project),
            capture_output=True,
            text=True,
            timeout=120
        )

        if result.returncode != 0:
            return f"Error: {result.stderr}"

        log(f"NPM_DONE: {package}")
        return f"Installerade {package}"

    except subprocess.TimeoutExpired:
        return "Error: npm install timeout"
    except FileNotFoundError:
        return "Error: npm not found (Node.js inte installerat?)"
    except Exception as e:
        return f"Error: {e}"


def run_command(command: str) -> str:
    """
    Kör ett shell-kommando.

    Args:
        command: Kommando att köra
    """
    project = get_project_dir()
    log(f"RUN: {command}")

    try:
        result = subprocess.run(
            command,
            shell=True,
            cwd=str(project),
            capture_output=True,
            text=True,
            timeout=60
        )

        output = result.stdout
        if result.stderr:
            output += f"\nSTDERR:\n{result.stderr}"

        if result.returncode != 0:
            output += f"\nExit code: {result.returncode}"

        return output or "Command completed (no output)"

    except subprocess.TimeoutExpired:
        return "Error: Command timed out (60s)"
    except Exception as e:
        return f"Error: {e}"


# =============================================================================
# TOOL DEFINITIONS (for MCP)
# =============================================================================

TOOLS = [
    {
        "name": "thinking",
        "description": "Logga en tanke eller beslut. Använd ofta för att visa resonemang.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "thought": {
                    "type": "string",
                    "description": "Din tanke eller beslut"
                }
            },
            "required": ["thought"]
        }
    },
    {
        "name": "browse_url",
        "description": "Browse a URL and return page content as text. Use this to research visual inspiration, game references, color palettes from sites like itch.io, dribbble, coolors.co etc.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "Full URL to browse (e.g., 'https://itch.io/games/top-rated')"
                }
            },
            "required": ["url"]
        }
    },
    {
        "name": "extract_colors",
        "description": "Browse a URL and extract hex color codes. Useful for grabbing color palettes from design sites like coolors.co.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "URL to a color palette or design page"
                }
            },
            "required": ["url"]
        }
    },
    {
        "name": "research",
        "description": "Log research findings. Use AFTER browse_url to document what you learned from a page.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {
                    "type": "string",
                    "description": "URL som besöktes"
                },
                "findings": {
                    "type": "string",
                    "description": "Vad du lärde dig / observerade"
                }
            },
            "required": ["url", "findings"]
        }
    },
    {
        "name": "vision",
        "description": "Dokumentera projektvisionen efter research. Definiera namn, hook, målgrupp, etc.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {
                    "type": "string",
                    "description": "Spelets/projektets namn"
                },
                "hook": {
                    "type": "string",
                    "description": "Varför är detta oemotståndligt? (en mening)"
                },
                "target": {
                    "type": "string",
                    "description": "Målgrupp - vem, när, varför"
                },
                "unique": {
                    "type": "string",
                    "description": "Vad gör detta annorlunda?"
                },
                "feeling": {
                    "type": "string",
                    "description": "Vad ska användaren känna?"
                }
            },
            "required": ["name", "hook", "target", "unique", "feeling"]
        }
    },
    {
        "name": "write_file",
        "description": "Skriv eller uppdatera en fil i projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Relativ sökväg (t.ex. 'main.py' eller 'static/css/style.css')"
                },
                "content": {
                    "type": "string",
                    "description": "Filinnehåll"
                }
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "read_file",
        "description": "Läs en fil från projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Relativ sökväg"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "list_files",
        "description": "Lista alla filer i projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "run_command",
        "description": "Kör ett shell-kommando (t.ex. 'python main.py', 'pip install ...').",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Kommando att köra"
                }
            },
            "required": ["command"]
        }
    },
    {
        "name": "search_github",
        "description": "Sök GitHub efter relevanta repos, engines, libraries. Använd innan du bygger något komplext.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Sökfråga (t.ex. 'javascript 2d game engine minimal')"
                },
                "limit": {
                    "type": "integer",
                    "description": "Max antal resultat (default 5)"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "clone_repo",
        "description": "Klona ett GitHub-repo till projektet. Bra för game engines, libraries, boilerplate.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "repo_url": {
                    "type": "string",
                    "description": "GitHub URL (https://github.com/user/repo)"
                },
                "folder": {
                    "type": "string",
                    "description": "Mapp att klona till (default: 'lib')"
                }
            },
            "required": ["repo_url"]
        }
    },
    {
        "name": "npm_install",
        "description": "Installera npm-paket för frontend (t.ex. 'phaser', 'matter-js', 'pixi.js').",
        "inputSchema": {
            "type": "object",
            "properties": {
                "package": {
                    "type": "string",
                    "description": "Paketnamn"
                }
            },
            "required": ["package"]
        }
    },
]

HANDLERS = {
    "thinking": lambda args: thinking(args["thought"]),
    "browse_url": lambda args: browse_url(args["url"]),
    "extract_colors": lambda args: extract_colors(args["url"]),
    "research": lambda args: research(args["url"], args["findings"]),
    "vision": lambda args: vision(args["name"], args["hook"], args["target"], args["unique"], args["feeling"]),
    "write_file": lambda args: write_file(args["path"], args["content"]),
    "read_file": lambda args: read_file(args["path"]),
    "list_files": lambda args: list_files(),
    "run_command": lambda args: run_command(args["command"]),
    "search_github": lambda args: search_github(args["query"], args.get("limit", 5)),
    "clone_repo": lambda args: clone_repo(args["repo_url"], args.get("folder", "lib")),
    "npm_install": lambda args: npm_install(args["package"]),
}
