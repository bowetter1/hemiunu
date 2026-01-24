"""
Apex Lite - Sprint Loop Tools

Boss + 1 Dev modell med sprint-baserat arbetsflöde.
"""
import subprocess
import os
import sys
import json
from datetime import datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# Startup log
sys.stderr.write(f"[APEX-LITE] Tools loaded at {datetime.now().strftime('%H:%M:%S')}\n")
sys.stderr.flush()

# === CONFIG ===
PROMPTS_DIR = Path(__file__).parent / "prompts"
DEV_TIMEOUT = 600  # 10 min per dev
STATE_FILE = "sprint_state.json"
LOG_FILE = "sprint.log"
VERBOSE = True  # Skriv även till stderr för live-visning

# === LIMITS ===
MAX_SPRINTS = 3  # Max antal sprints
PROJECT_TIMEOUT = 600  # 10 min total för hela projektet

# === BACKGROUND EXECUTION ===
_executor = ThreadPoolExecutor(max_workers=1)
_current_dev = None  # Future för pågående dev
_dev_start_time = None  # När dev startade
_project_start_time = None  # När projektet startade


# === TOOL DEFINITIONS ===
TOOLS = [
    # === RESEARCH TOOLS (VD använder dessa först!) ===
    {
        "name": "web_search",
        "description": "Sök på webben för marknadsanalys. ANVÄND DETTA FÖRST! Förstå konkurrenter, trender, vad som fungerar.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Sökfråga, t.ex. 'best quiz games 2024' eller 'what makes games addictive'"}
            },
            "required": ["query"]
        }
    },
    {
        "name": "web_fetch",
        "description": "Hämta och analysera en specifik webbsida.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL att hämta"},
                "prompt": {"type": "string", "description": "Vad vill du veta från sidan?"}
            },
            "required": ["url", "prompt"]
        }
    },
    # === THINKING ===
    {
        "name": "thinking",
        "description": "Logga vad du tänker/planerar. Använd ofta för synlighet!",
        "inputSchema": {
            "type": "object",
            "properties": {
                "thought": {"type": "string", "description": "Vad tänker du?"}
            },
            "required": ["thought"]
        }
    },
    {
        "name": "plan_sprint",
        "description": "Planera en sprint med mål och dev-spec. Sparar till state.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "number": {"type": "integer", "description": "Sprint-nummer (1, 2, 3...)"},
                "goals": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista av mål för sprinten"
                },
                "spec": {"type": "string", "description": "Komplett dev-specifikation"}
            },
            "required": ["number", "goals", "spec"]
        }
    },
    {
        "name": "start_sprint",
        "description": "Starta current sprint - kör dev i bakgrunden (non-blocking). Du kan planera nästa sprint medan dev jobbar!",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "get_sprint_status",
        "description": "Kolla om pågående sprint är klar. Returnerar 'running' eller 'done' + resultat.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "test_sprint",
        "description": "Kör tester för att verifiera att sprinten fungerar.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "commands": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista av test-kommandon att köra"
                }
            },
            "required": ["commands"]
        }
    },
    {
        "name": "fix_bugs",
        "description": "Be dev fixa buggar som hittades vid testning. Blockerande.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "issues": {"type": "string", "description": "Beskrivning av buggar/problem att fixa"}
            },
            "required": ["issues"]
        }
    },
    {
        "name": "complete_sprint",
        "description": "Markera sprint som klar och gå vidare till nästa.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "notes": {"type": "string", "description": "Anteckningar om vad som levererades"}
            },
            "required": []
        }
    },
    {
        "name": "list_files",
        "description": "Lista alla filer i projektet.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "required": []
        }
    },
    {
        "name": "read_file",
        "description": "Läs innehållet i en fil.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Sökväg till filen"}
            },
            "required": ["path"]
        }
    },
    {
        "name": "write_file",
        "description": "Skriv/skapa en fil. Använd för integration eller config.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Sökväg till filen"},
                "content": {"type": "string", "description": "Filinnehåll"}
            },
            "required": ["path", "content"]
        }
    },
    {
        "name": "run_command",
        "description": "Kör ett shell-kommando (tester, linting, etc).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "cmd": {"type": "string", "description": "Kommando att köra"}
            },
            "required": ["cmd"]
        }
    },
    {
        "name": "view_log",
        "description": "Visa sprint-loggen. Bra för att se vad som hänt.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "lines": {"type": "integer", "description": "Antal rader att visa (default: 30)"}
            },
            "required": []
        }
    },
    # === RETROSPEKTIV (använd när projektet är klart!) ===
    {
        "name": "write_retrospective",
        "description": "Skriv en retrospektiv när projektet är klart. Reflektera över ditt arbete som VD - vad gick bra, vad gick dåligt, lärdomar för framtiden.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "product_name": {"type": "string", "description": "Namnet på produkten du byggde"},
                "vision": {"type": "string", "description": "Vad var visionen/idén?"},
                "what_went_well": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista över saker som gick bra"
                },
                "what_went_badly": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lista över saker som gick dåligt eller kunde förbättras"
                },
                "learnings": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Lärdomar och insikter för framtida projekt"
                },
                "next_steps": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Vad skulle du göra härnäst om du hade mer tid?"
                },
                "rating": {"type": "integer", "description": "Betyg 1-10 på hur nöjd du är med resultatet"}
            },
            "required": ["product_name", "vision", "what_went_well", "what_went_badly", "learnings", "rating"]
        }
    },
]


# === STATE HELPERS ===
def load_state(cwd: str) -> dict:
    """Ladda sprint state från JSON."""
    global _project_start_time

    state_path = Path(cwd) / STATE_FILE
    if state_path.exists():
        try:
            state = json.loads(state_path.read_text())
            # Återställ starttid om den finns
            if state.get("started_at") and not _project_start_time:
                _project_start_time = datetime.fromisoformat(state["started_at"])
            return state
        except:
            pass
    # Default state
    return {
        "project_goal": None,
        "current_sprint": 0,
        "status": "planning",  # planning, running, testing, fixing, done
        "sprints": {},
        "next_sprint": None,
        "started_at": None
    }


def save_state(cwd: str, state: dict):
    """Spara sprint state till JSON."""
    state_path = Path(cwd) / STATE_FILE
    state_path.write_text(json.dumps(state, indent=2, ensure_ascii=False))


# === LOGGING ===
def log(cwd: str, message: str, level: str = "INFO"):
    """Logga till sprint.log och stderr (för live-visning)."""
    import sys
    timestamp = datetime.now().strftime("%H:%M:%S")
    log_line = f"[{timestamp}] [{level}] {message}"

    # Skriv alltid till stderr för live-visning
    sys.stderr.write(log_line + "\n")
    sys.stderr.flush()

    # Skriv till fil
    try:
        log_file = Path(cwd) / LOG_FILE
        log_file.parent.mkdir(parents=True, exist_ok=True)
        with open(log_file, "a") as f:
            f.write(log_line + "\n")
    except Exception as e:
        sys.stderr.write(f"[LOG ERROR] Could not write to {cwd}/sprint.log: {e}\n")
        sys.stderr.flush()


def log_section(cwd: str, title: str):
    """Logga en sektion-header."""
    log(cwd, "=" * 50)
    log(cwd, f"  {title}")
    log(cwd, "=" * 50)


def check_timeout(cwd: str) -> tuple[bool, int]:
    """Kolla om projektet har timeout. Returnerar (timed_out, seconds_remaining)."""
    global _project_start_time
    if not _project_start_time:
        return False, PROJECT_TIMEOUT

    elapsed = (datetime.now() - _project_start_time).total_seconds()
    remaining = PROJECT_TIMEOUT - elapsed

    if remaining <= 0:
        log(cwd, f"⏰ PROJEKT TIMEOUT! ({PROJECT_TIMEOUT}s)", "TIMEOUT")
        return True, 0

    return False, int(remaining)


def check_limits(cwd: str, sprint_num: int) -> str | None:
    """Kolla om vi nått gränser. Returnerar felmeddelande eller None."""
    # Kolla timeout
    timed_out, remaining = check_timeout(cwd)
    if timed_out:
        return f"⏰ TIMEOUT! Projektet har kört i {PROJECT_TIMEOUT//60} minuter. Avsluta nu."

    # Kolla max sprints
    if sprint_num > MAX_SPRINTS:
        log(cwd, f"🛑 MAX SPRINTS ({MAX_SPRINTS}) nådd!", "LIMIT")
        return f"🛑 Max {MAX_SPRINTS} sprints nådd! Projektet måste vara klart nu."

    return None


def make_response(text: str) -> dict:
    """Skapa MCP-svar."""
    return {"content": [{"type": "text", "text": text}]}


def load_prompt(name: str, **kwargs) -> str:
    """Ladda och formatera en prompt."""
    path = PROMPTS_DIR / f"{name}.md"
    template = path.read_text()
    return template.format(**kwargs)


# === DEV RUNNER ===
def run_dev(spec: str, cwd: str, name: str = "dev") -> str:
    """Kör en Dev via Claude CLI."""
    prompt = load_prompt("dev", spec=spec)

    cmd = [
        "claude",
        "-p", prompt,
        "--dangerously-skip-permissions"
    ]

    log(cwd, f"👷 DEV [{name}] startar...", "DEV")
    log(cwd, f"   Spec: {len(spec)} tecken", "DEV")
    start_time = datetime.now()

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=DEV_TIMEOUT,
            cwd=cwd
        )
        elapsed = (datetime.now() - start_time).seconds
        output = result.stdout.strip() or result.stderr.strip() or "(ingen output)"
        log(cwd, f"✅ DEV [{name}] klar ({elapsed}s, {len(output)} tecken)", "DEV")
        return output
    except subprocess.TimeoutExpired:
        log(cwd, f"⏰ DEV [{name}] timeout efter {DEV_TIMEOUT}s!", "ERROR")
        return f"ERROR: Timeout efter {DEV_TIMEOUT}s"
    except Exception as e:
        log(cwd, f"❌ DEV [{name}] fel: {e}", "ERROR")
        return f"ERROR: {e}"


# === SPRINT TOOL HANDLERS ===
def thinking(arguments: dict, cwd: str) -> dict:
    """Logga en tanke."""
    thought = arguments.get("thought", "")
    log(cwd, f"💭 BOSS: {thought}", "THINK")
    return make_response(f"💭 {thought}")


def plan_sprint(arguments: dict, cwd: str) -> dict:
    """Planera en sprint med mål och dev-spec."""
    global _project_start_time

    number = arguments.get("number", 1)
    goals = arguments.get("goals", [])
    spec = arguments.get("spec", "")

    if not goals or not spec:
        log(cwd, "❌ plan_sprint anropad utan goals eller spec!", "ERROR")
        return make_response("❌ Saknar goals eller spec!")

    # Kolla gränser
    limit_error = check_limits(cwd, number)
    if limit_error:
        return make_response(limit_error)

    log_section(cwd, f"PLANERAR SPRINT {number}/{MAX_SPRINTS}")
    log(cwd, f"📋 Mål: {', '.join(goals)}", "PLAN")
    log(cwd, f"📋 Spec: {len(spec)} tecken", "PLAN")

    state = load_state(cwd)

    # Om detta är sprint 1, sätt project_goal och starttid
    if number == 1 and state["current_sprint"] == 0:
        _project_start_time = datetime.now()
        state["project_goal"] = goals[0] if goals else "Okänt projekt"
        state["current_sprint"] = 1
        state["started_at"] = _project_start_time.isoformat()
        log(cwd, f"🎯 Projekt: {state['project_goal']}", "PLAN")
        log(cwd, f"⏱️ Timeout: {PROJECT_TIMEOUT//60} min | Max sprints: {MAX_SPRINTS}", "PLAN")

    # Spara sprint-plan
    state["sprints"][str(number)] = {
        "goals": goals,
        "spec": spec,
        "status": "planned",
        "dev_result": None,
        "test_results": None,
        "completed_at": None
    }

    # Om detta är current sprint, uppdatera status
    if number == state["current_sprint"]:
        state["status"] = "planned"

    save_state(cwd, state)
    log(cwd, f"✅ Sprint {number} sparad till state", "PLAN")

    return make_response(f"📋 Sprint {number} planerad!\n\n**Mål:**\n" + "\n".join(f"- {g}" for g in goals))


def start_sprint(arguments: dict, cwd: str) -> dict:
    """Starta dev i bakgrunden."""
    global _current_dev, _dev_start_time

    state = load_state(cwd)
    sprint_num = state["current_sprint"]

    # Kolla gränser
    limit_error = check_limits(cwd, sprint_num)
    if limit_error:
        return make_response(limit_error)

    if sprint_num == 0:
        log(cwd, "❌ Ingen sprint planerad!", "ERROR")
        return make_response("❌ Ingen sprint planerad! Använd plan_sprint() först.")

    sprint_key = str(sprint_num)
    if sprint_key not in state["sprints"]:
        log(cwd, f"❌ Sprint {sprint_num} inte planerad!", "ERROR")
        return make_response(f"❌ Sprint {sprint_num} är inte planerad!")

    sprint = state["sprints"][sprint_key]

    if sprint["status"] == "running":
        log(cwd, f"⚠️ Sprint {sprint_num} körs redan", "WARN")
        return make_response(f"⚠️ Sprint {sprint_num} körs redan! Använd get_sprint_status().")

    if sprint["status"] == "completed":
        return make_response(f"✅ Sprint {sprint_num} är redan klar!")

    log_section(cwd, f"STARTAR SPRINT {sprint_num}")
    log(cwd, f"🎯 Mål: {', '.join(sprint['goals'])}", "START")

    # Starta dev i bakgrund
    spec = sprint["spec"]
    _dev_start_time = datetime.now()
    _current_dev = _executor.submit(run_dev, spec, cwd, f"sprint-{sprint_num}")

    sprint["status"] = "running"
    state["status"] = "running"
    save_state(cwd, state)

    log(cwd, f"⚡ Dev startar i bakgrund (non-blocking)", "START")
    log(cwd, f"⏱️ Startad: {_dev_start_time.strftime('%H:%M:%S')}", "START")

    return make_response(f"""⚡ Sprint {sprint_num} startad!

Dev jobbar i bakgrunden. Du kan nu:
1. **Planera nästa sprint** - plan_sprint({sprint_num + 1}, ...)
2. **Kolla status** - get_sprint_status()
3. **Läsa filer** - list_files(), read_file()

Tip: Planera sprint {sprint_num + 1} medan dev jobbar!""")


def get_sprint_status(arguments: dict, cwd: str) -> dict:
    """Kolla om dev är klar."""
    global _current_dev, _dev_start_time

    state = load_state(cwd)
    sprint_num = state["current_sprint"]

    # Kolla timeout
    timed_out, remaining = check_timeout(cwd)
    if timed_out:
        return make_response(f"⏰ TIMEOUT! Projektet har kört i {PROJECT_TIMEOUT//60} minuter. Avsluta nu.")

    time_info = f"⏱️ {remaining//60}m {remaining%60}s kvar"
    log(cwd, f"📊 Kollar status för sprint {sprint_num}... ({time_info})", "STATUS")

    if not _current_dev:
        log(cwd, f"📊 Ingen dev-process aktiv. Status: {state['status']}", "STATUS")
        return make_response(f"📊 Status: {state['status']} | {time_info}\n\nIngen dev-process körs just nu.")

    if _current_dev.done():
        # Räkna ut tid
        elapsed = ""
        if _dev_start_time:
            delta = datetime.now() - _dev_start_time
            elapsed = f" ({delta.seconds}s)"

        try:
            result = _current_dev.result()
            log(cwd, f"✅ Dev KLAR!{elapsed}", "STATUS")
        except Exception as e:
            result = f"ERROR: {e}"
            log(cwd, f"❌ Dev misslyckades: {e}", "ERROR")

        # Uppdatera state
        sprint_key = str(sprint_num)
        state["sprints"][sprint_key]["dev_result"] = result
        state["sprints"][sprint_key]["status"] = "testing"
        state["status"] = "testing"
        save_state(cwd, state)

        _current_dev = None
        _dev_start_time = None

        log_section(cwd, f"SPRINT {sprint_num} DEV KLAR")
        log(cwd, f"📝 Resultat: {len(result)} tecken", "STATUS")

        # Begränsa output för läsbarhet
        result_preview = result[:2000] + "..." if len(result) > 2000 else result

        return make_response(f"""✅ Sprint {sprint_num} - Dev KLAR!{elapsed}

**Dev-rapport:**
{result_preview}

**Nästa steg:**
1. Testa med test_sprint(["python main.py", ...])
2. Om buggar: fix_bugs("beskrivning av problem")
3. Om OK: complete_sprint()""")
    else:
        # Räkna ut hur länge dev jobbat
        elapsed = ""
        if _dev_start_time:
            delta = datetime.now() - _dev_start_time
            elapsed = f" (jobbat {delta.seconds}s)"

        log(cwd, f"⏳ Dev jobbar fortfarande...{elapsed}", "STATUS")

        return make_response(f"""⏳ Sprint {sprint_num} - Dev jobbar fortfarande...{elapsed}

**Status:** running | {time_info}
**Sprint:** {sprint_num}/{MAX_SPRINTS}
**Tip:** Planera sprint {sprint_num + 1} medan du väntar!

Kör get_sprint_status() igen om en stund.""")


def test_sprint(arguments: dict, cwd: str) -> dict:
    """Kör tester för sprinten."""
    commands = arguments.get("commands", [])

    if not commands:
        log(cwd, "❌ Inga testkommandon!", "ERROR")
        return make_response("❌ Inga testkommandon angivna!")

    state = load_state(cwd)
    sprint_num = state["current_sprint"]

    log_section(cwd, f"TESTAR SPRINT {sprint_num}")
    log(cwd, f"🧪 Kör {len(commands)} testkommandon...", "TEST")

    results = []
    all_passed = True
    passed_count = 0

    for i, cmd in enumerate(commands, 1):
        log(cwd, f"🧪 [{i}/{len(commands)}] {cmd}", "TEST")
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=120,
                cwd=cwd
            )
            output = (result.stdout + result.stderr).strip()
            passed = result.returncode == 0
            status = "✅" if passed else "❌"
            log(cwd, f"   {status} Exit {result.returncode}", "TEST")
            results.append(f"{status} `{cmd}` (exit {result.returncode})\n```\n{output[:500]}\n```")
            if passed:
                passed_count += 1
            else:
                all_passed = False
        except subprocess.TimeoutExpired:
            log(cwd, f"   ⏰ Timeout!", "TEST")
            results.append(f"⏰ `{cmd}` - Timeout!")
            all_passed = False
        except Exception as e:
            log(cwd, f"   ❌ Error: {e}", "TEST")
            results.append(f"❌ `{cmd}` - Error: {e}")
            all_passed = False

    # Spara testresultat
    sprint_key = str(sprint_num)
    if sprint_key in state["sprints"]:
        state["sprints"][sprint_key]["test_results"] = {
            "passed": all_passed,
            "details": results
        }
        save_state(cwd, state)

    log(cwd, f"🧪 Resultat: {passed_count}/{len(commands)} OK", "TEST")

    summary = "✅ Alla tester OK!" if all_passed else "❌ Några tester misslyckades"

    return make_response(f"""🧪 Testresultat - Sprint {sprint_num}

{summary}

**Detaljer:**
{chr(10).join(results)}

**Nästa steg:**
{('- complete_sprint() för att avsluta sprinten' if all_passed else '- fix_bugs("beskrivning") för att fixa problemen')}""")


def fix_bugs(arguments: dict, cwd: str) -> dict:
    """Kör dev för att fixa buggar (blockerande)."""
    issues = arguments.get("issues", "")

    if not issues:
        log(cwd, "❌ Ingen beskrivning av buggar!", "ERROR")
        return make_response("❌ Ingen beskrivning av buggar!")

    state = load_state(cwd)
    sprint_num = state["current_sprint"]

    log_section(cwd, f"FIXAR BUGGAR - SPRINT {sprint_num}")
    log(cwd, f"🔧 Problem att fixa:", "FIX")
    for line in issues.strip().split('\n')[:5]:
        log(cwd, f"   {line}", "FIX")
    log(cwd, f"🔧 Startar dev för att fixa (blockerande)...", "FIX")

    # Skapa fix-spec
    fix_spec = f"""FIX BUGS

Fixa följande problem i koden:

{issues}

---

INSTRUKTIONER:
1. Läs befintliga filer
2. Identifiera och fixa problemen
3. Testa att det fungerar
4. Skriv uppdaterade filer

Ändra INTE fungerande delar - bara fixa de specifika problemen."""

    # Kör dev synkront (blockerande)
    state["status"] = "fixing"
    save_state(cwd, state)

    start_time = datetime.now()
    result = run_dev(fix_spec, cwd, f"fixer-{sprint_num}")
    elapsed = (datetime.now() - start_time).seconds

    # Uppdatera state
    state["status"] = "testing"
    save_state(cwd, state)

    log(cwd, f"✅ Fix klar ({elapsed}s)", "FIX")

    result_preview = result[:2000] + "..." if len(result) > 2000 else result

    return make_response(f"""🔧 Bug-fix klar! ({elapsed}s)

**Dev-rapport:**
{result_preview}

**Nästa steg:**
Kör test_sprint() igen för att verifiera fixen.""")


def complete_sprint(arguments: dict, cwd: str) -> dict:
    """Markera sprint som klar och gå till nästa."""
    notes = arguments.get("notes", "")

    state = load_state(cwd)
    sprint_num = state["current_sprint"]
    sprint_key = str(sprint_num)

    if sprint_key not in state["sprints"]:
        log(cwd, f"❌ Sprint {sprint_num} finns inte!", "ERROR")
        return make_response(f"❌ Sprint {sprint_num} finns inte!")

    log_section(cwd, f"SPRINT {sprint_num} KLAR!")

    # Markera som klar
    state["sprints"][sprint_key]["status"] = "completed"
    state["sprints"][sprint_key]["completed_at"] = datetime.now().isoformat()
    if notes:
        state["sprints"][sprint_key]["notes"] = notes
        log(cwd, f"📝 Anteckningar: {notes[:100]}", "DONE")

    # Gå till nästa sprint
    next_sprint = sprint_num + 1
    state["current_sprint"] = next_sprint

    # Kolla om vi nått max sprints
    completed_sprints = len([s for s in state["sprints"].values() if s["status"] == "completed"])

    if completed_sprints >= MAX_SPRINTS:
        state["status"] = "done"
        next_status = f"🏁 PROJEKT KLART! Max {MAX_SPRINTS} sprints uppnått."
        log(cwd, f"🏁 PROJEKT KLART - {MAX_SPRINTS} sprints avklarade!", "DONE")
        # Räkna ut total tid
        timed_out, remaining = check_timeout(cwd)
        total_time = PROJECT_TIMEOUT - remaining
        log(cwd, f"⏱️ Total tid: {total_time}s", "DONE")
    # Kolla om nästa sprint redan är planerad
    elif str(next_sprint) in state["sprints"]:
        state["status"] = "planned"
        next_status = f"Sprint {next_sprint} är redan planerad! Kör start_sprint()."
        log(cwd, f"➡️ Sprint {next_sprint} redan planerad - redo att starta!", "DONE")
    else:
        state["status"] = "planning"
        next_status = f"Planera sprint {next_sprint} med plan_sprint()."
        log(cwd, f"➡️ Nästa: Planera sprint {next_sprint}", "DONE")

    save_state(cwd, state)

    log(cwd, f"📊 {completed_sprints}/{MAX_SPRINTS} sprints klara", "DONE")

    return make_response(f"""🎉 Sprint {sprint_num} KLAR!

**Levererat:**
{notes or '(inga anteckningar)'}

**Sammanfattning:**
- Sprint: {sprint_num}
- Status: completed
- Nästa: Sprint {next_sprint}

**Nästa steg:**
{next_status}""")


# === FILE/COMMAND HANDLERS ===
def list_files(arguments: dict, cwd: str) -> dict:
    """Lista projektfiler."""
    files = []
    for f in Path(cwd).rglob("*"):
        if f.is_file() and not f.name.startswith(".") and "__pycache__" not in str(f):
            rel = f.relative_to(cwd)
            size = f.stat().st_size
            files.append(f"{rel} ({size} bytes)")

    if not files:
        return make_response("📁 Inga filer ännu")

    return make_response("📁 Filer:\n" + "\n".join(sorted(files)[:50]))


def read_file(arguments: dict, cwd: str) -> dict:
    """Läs en fil."""
    path = arguments.get("path", "")
    full_path = Path(cwd) / path

    if not full_path.exists():
        return make_response(f"❌ Filen finns inte: {path}")

    try:
        content = full_path.read_text()
        return make_response(f"📄 {path}:\n```\n{content[:5000]}\n```")
    except Exception as e:
        return make_response(f"❌ Kunde inte läsa: {e}")


def write_file(arguments: dict, cwd: str) -> dict:
    """Skriv en fil."""
    path = arguments.get("path", "")
    content = arguments.get("content", "")
    full_path = Path(cwd) / path

    try:
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_text(content)
        log(cwd, f"📝 Skrev fil: {path} ({len(content)} chars)")
        return make_response(f"✅ Skrev {path} ({len(content)} chars)")
    except Exception as e:
        return make_response(f"❌ Kunde inte skriva: {e}")


def run_command(arguments: dict, cwd: str) -> dict:
    """Kör ett shell-kommando."""
    cmd = arguments.get("cmd", "")

    if not cmd:
        return make_response("❌ Inget kommando angivet")

    log(cwd, f"🔧 Kör: {cmd}", "CMD")

    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=cwd
        )
        output = result.stdout + result.stderr
        status = "✅" if result.returncode == 0 else "❌"
        log(cwd, f"{status} Exit {result.returncode}", "CMD")
        return make_response(f"{status} Exit {result.returncode}:\n```\n{output[:3000]}\n```")
    except subprocess.TimeoutExpired:
        log(cwd, "⏰ Timeout!", "CMD")
        return make_response("⏰ Timeout (120s)")
    except Exception as e:
        log(cwd, f"❌ Fel: {e}", "CMD")
        return make_response(f"❌ Fel: {e}")


def view_log(arguments: dict, cwd: str) -> dict:
    """Visa sprint-loggen."""
    lines = arguments.get("lines", 30)
    log_path = Path(cwd) / LOG_FILE

    if not log_path.exists():
        return make_response("📜 Ingen logg ännu")

    try:
        content = log_path.read_text()
        all_lines = content.strip().split('\n')

        # Ta de senaste raderna
        recent = all_lines[-lines:] if len(all_lines) > lines else all_lines

        return make_response(f"📜 Logg (senaste {len(recent)} rader):\n```\n" + "\n".join(recent) + "\n```")
    except Exception as e:
        return make_response(f"❌ Kunde inte läsa logg: {e}")


# === WEB RESEARCH TOOLS ===
def web_search(arguments: dict, cwd: str) -> dict:
    """Sök på webben via Claude CLI."""
    query = arguments.get("query", "")

    if not query:
        return make_response("❌ Ingen sökfråga angiven!")

    log(cwd, f"🔍 RESEARCH: {query}", "SEARCH")

    # Använd Claude CLI för web search
    prompt = f"""Sök på webben efter: {query}

Sammanfatta de viktigaste resultaten:
- Vilka produkter/spel finns?
- Vad gör de bra?
- Vilka trender ser du?
- Vad saknas på marknaden?

Var konkret och actionable."""

    try:
        result = subprocess.run(
            ["claude", "-p", prompt, "--allowedTools", "WebSearch"],
            capture_output=True,
            text=True,
            timeout=60,
            cwd=cwd
        )
        output = result.stdout.strip() or result.stderr.strip() or "(inga resultat)"
        log(cwd, f"🔍 Sökning klar ({len(output)} tecken)", "SEARCH")

        # Begränsa output
        if len(output) > 3000:
            output = output[:3000] + "\n\n... (trunkerad)"

        return make_response(f"🔍 **Sökresultat: {query}**\n\n{output}")
    except subprocess.TimeoutExpired:
        log(cwd, "⏰ Sökning timeout!", "SEARCH")
        return make_response("⏰ Sökningen tog för lång tid")
    except Exception as e:
        log(cwd, f"❌ Sökfel: {e}", "SEARCH")
        return make_response(f"❌ Kunde inte söka: {e}")


def web_fetch(arguments: dict, cwd: str) -> dict:
    """Hämta och analysera en webbsida via Claude CLI."""
    url = arguments.get("url", "")
    prompt = arguments.get("prompt", "Sammanfatta innehållet")

    if not url:
        return make_response("❌ Ingen URL angiven!")

    log(cwd, f"🌐 FETCH: {url}", "FETCH")

    # Använd Claude CLI för web fetch
    full_prompt = f"""Hämta och analysera denna sida: {url}

Fråga: {prompt}

Var konkret och relevant för speldesign/produktutveckling."""

    try:
        result = subprocess.run(
            ["claude", "-p", full_prompt, "--allowedTools", "WebFetch"],
            capture_output=True,
            text=True,
            timeout=60,
            cwd=cwd
        )
        output = result.stdout.strip() or result.stderr.strip() or "(inget innehåll)"
        log(cwd, f"🌐 Fetch klar ({len(output)} tecken)", "FETCH")

        # Begränsa output
        if len(output) > 3000:
            output = output[:3000] + "\n\n... (trunkerad)"

        return make_response(f"🌐 **{url}**\n\n{output}")
    except subprocess.TimeoutExpired:
        log(cwd, "⏰ Fetch timeout!", "FETCH")
        return make_response("⏰ Hämtningen tog för lång tid")
    except Exception as e:
        log(cwd, f"❌ Fetch-fel: {e}", "FETCH")
        return make_response(f"❌ Kunde inte hämta: {e}")


# === RETROSPECTIVE ===
def write_retrospective(arguments: dict, cwd: str) -> dict:
    """Skriv VD:ns retrospektiv till RETROSPECTIVE.md."""
    product_name = arguments.get("product_name", "Okänt projekt")
    vision = arguments.get("vision", "")
    what_went_well = arguments.get("what_went_well", [])
    what_went_badly = arguments.get("what_went_badly", [])
    learnings = arguments.get("learnings", [])
    next_steps = arguments.get("next_steps", [])
    rating = arguments.get("rating", 5)

    log(cwd, f"📝 Skriver retrospektiv för: {product_name}", "RETRO")

    # Skapa markdown
    stars = "⭐" * rating + "☆" * (10 - rating)

    content = f"""# Retrospektiv: {product_name}

> *VD:ns reflektion efter avslutat projekt*

---

## Vision
{vision}

---

## Betyg: {rating}/10 {stars}

---

## Vad gick bra ✅

{chr(10).join(f"- {item}" for item in what_went_well) if what_went_well else "- (inget noterat)"}

---

## Vad kunde förbättras ⚠️

{chr(10).join(f"- {item}" for item in what_went_badly) if what_went_badly else "- (inget noterat)"}

---

## Lärdomar 💡

{chr(10).join(f"- {item}" for item in learnings) if learnings else "- (inga lärdomar noterade)"}

---

## Nästa steg (om jag hade mer tid) 🚀

{chr(10).join(f"- {item}" for item in next_steps) if next_steps else "- (inga nästa steg noterade)"}

---

## Sammanfattning

Som VD för detta spelbolag har jag lärt mig mycket under detta projekt.
{"Jag är nöjd med resultatet!" if rating >= 7 else "Det finns utrymme för förbättring." if rating >= 5 else "Detta var en lärorik utmaning."}

*Genererad av Apex Lite VD*
"""

    # Skriv till fil
    retro_path = Path(cwd) / "RETROSPECTIVE.md"
    try:
        retro_path.write_text(content)
        log(cwd, f"✅ Retrospektiv sparad: RETROSPECTIVE.md", "RETRO")
        return make_response(f"""📝 **Retrospektiv sparad!**

**Produkt:** {product_name}
**Betyg:** {rating}/10 {stars}

Filen `RETROSPECTIVE.md` innehåller din kompletta reflektion.

{'🎉 Bra jobbat!' if rating >= 7 else '💪 Fortsätt utvecklas!' if rating >= 5 else '📚 Varje projekt är en lärdom!'}""")
    except Exception as e:
        log(cwd, f"❌ Kunde inte skriva retrospektiv: {e}", "ERROR")
        return make_response(f"❌ Kunde inte skriva retrospektiv: {e}")


# === HANDLER MAP ===
HANDLERS = {
    # Research
    "web_search": web_search,
    "web_fetch": web_fetch,
    # Thinking
    "thinking": thinking,
    # Sprint
    "plan_sprint": plan_sprint,
    "start_sprint": start_sprint,
    "get_sprint_status": get_sprint_status,
    "test_sprint": test_sprint,
    "fix_bugs": fix_bugs,
    "complete_sprint": complete_sprint,
    # Files
    "list_files": list_files,
    "read_file": read_file,
    "write_file": write_file,
    "run_command": run_command,
    "view_log": view_log,
    # Retrospective
    "write_retrospective": write_retrospective,
}
