#!/usr/bin/env python3
"""
Apex Solo - En AI, en vision, ett projekt.

Användning:
    python cli.py "Bygg en e-commerce för smycken"
"""
import sys
import subprocess
import os
import threading
import time
from pathlib import Path


def load_driver_prompt(task: str) -> str:
    """Ladda driver-prompten."""
    prompt_path = Path(__file__).parent / "prompts" / "boss_v2.md"
    template = prompt_path.read_text()
    return template.format(task=task)


def main():
    if len(sys.argv) < 2:
        print("""
╔═══════════════════════════════════════════════════════════╗
║                       APEX SOLO                           ║
║            VD för ett spelbolag. En vision.               ║
╚═══════════════════════════════════════════════════════════╝

Användning:
    python cli.py "Bygg ett beroendeframkallande minnesspel"
    python cli.py "Bygg en snake-klon som folk faktiskt vill spela"
    python cli.py "Bygg ett casual game för pendlare"

VD:n researchar marknaden, hittar sin nisch, och bygger
något folk VILL använda. Inte bara funktionellt - BEROENDE.
""")
        sys.exit(1)

    task = " ".join(sys.argv[1:])

    # Skapa projektmapp med unik timestamp
    import datetime
    timestamp = datetime.datetime.now().strftime("%H%M")
    name = "".join(c if c.isalnum() else "-" for c in task.lower())[:40].strip("-")
    name = f"{name}-{timestamp}"
    project = Path(__file__).parent / name

    # Om mappen redan finns, lägg till sekunder
    if project.exists():
        timestamp = datetime.datetime.now().strftime("%H%M%S")
        name = "".join(c if c.isalnum() else "-" for c in task.lower())[:40].strip("-")
        name = f"{name}-{timestamp}"
        project = Path(__file__).parent / name

    project.mkdir(exist_ok=False)

    # MCP config
    mcp_config = Path(__file__).parent / "mcp-config.json"

    print(f"""
╔═══════════════════════════════════════════════════════════╗
║                       APEX SOLO                           ║
╚═══════════════════════════════════════════════════════════╝

📋 Projekt: {task}
📂 Mapp: {project}
📝 Log: {project}/driver.log
""")

    # Skapa log-fil
    log_file = project / "driver.log"
    log_file.touch()

    # Kör Driver via Claude med MCP tools
    cmd = [
        "claude",
        "--mcp-config", str(mcp_config),
        "--dangerously-skip-permissions",
        "-p", load_driver_prompt(task)
    ]

    env = os.environ.copy()
    env["PROJECT_DIR"] = str(project)

    print("🎮 VD:n tar över...")
    print(f"📝 Följ loggen: tail -f {log_file}\n")
    print("=" * 60)

    # Tail log i bakgrundstråd
    stop_tail = threading.Event()

    # ANSI färger
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    MAGENTA = "\033[35m"
    RED = "\033[31m"
    BLUE = "\033[34m"

    def format_log_line(line: str) -> str:
        """Formatera logg-rad med färger och ikoner."""
        # Ta bort timestamp för renare output, men behåll den för context
        if line.startswith("["):
            timestamp_end = line.find("]")
            if timestamp_end != -1:
                timestamp = line[1:timestamp_end]
                content = line[timestamp_end + 2:]  # Skip "] "
                time_str = f"{DIM}[{timestamp}]{RESET} "
            else:
                time_str = ""
                content = line
        else:
            time_str = ""
            content = line

        # Formatera baserat på innehåll
        if content.startswith("THINK:"):
            thought = content[6:].strip()
            return f"{time_str}{CYAN}💭 {thought}{RESET}"
        elif content.startswith("WRITE:"):
            file_info = content[6:].strip()
            return f"{time_str}{GREEN}📝 Skrev: {file_info}{RESET}"
        elif content.startswith("READ:"):
            file_info = content[5:].strip()
            return f"{time_str}{BLUE}📖 Läste: {file_info}{RESET}"
        elif content.startswith("RUN:"):
            cmd = content[4:].strip()
            return f"{time_str}{YELLOW}⚡ Kör: {cmd}{RESET}"
        elif content.startswith("LIST:"):
            return f"{time_str}{BLUE}📂 Listar filer{RESET}"
        elif content.startswith("ASSIGN_DEV:"):
            return f"{time_str}{MAGENTA}🚀 {BOLD}Startar sprint...{RESET}"
        elif content.startswith("SPEC:"):
            return None  # Skip spec details, för långt
        elif content.startswith("DEV_DONE:"):
            return f"{time_str}{GREEN}✅ Sprint klar!{RESET}"
        elif content.startswith("DEV_TIMEOUT:"):
            return f"{time_str}{RED}⏱️  Dev timeout{RESET}"
        elif content.startswith("FIX_BUGS:"):
            return f"{time_str}{YELLOW}🔧 Fixar buggar...{RESET}"
        elif content.startswith("FIX_DONE:"):
            return f"{time_str}{GREEN}✅ Buggar fixade{RESET}"
        elif content.startswith("BROWSER:"):
            url = content[8:].strip()
            return f"{time_str}{MAGENTA}🌐 Surfar: {url}{RESET}"
        elif content.startswith("BROWSE:"):
            url = content[7:].strip()
            return f"{time_str}{MAGENTA}🌐 Hämtar: {url}{RESET}"
        elif content.startswith("BROWSE_OK:"):
            info = content[10:].strip()
            return f"{time_str}{GREEN}✅ {info}{RESET}"
        elif content.startswith("EXTRACT_COLORS:"):
            url = content[15:].strip()
            return f"{time_str}{MAGENTA}🎨 Extraherar färger: {url}{RESET}"
        elif content.startswith("COLORS_FOUND:"):
            info = content[13:].strip()
            return f"{time_str}{GREEN}🎨 {info}{RESET}"
        elif content.startswith("RESEARCH:"):
            findings = content[9:].strip()
            return f"{time_str}{CYAN}🔍 Hittade: {findings}{RESET}"
        elif content.startswith("VISION:"):
            vision_info = content[7:].strip()
            return f"{time_str}{BOLD}{GREEN}🎯 VISION: {vision_info}{RESET}"
        else:
            # Multiline thoughts etc
            if content.strip():
                return f"{time_str}   {DIM}{content}{RESET}"
            return None

    def tail_log():
        last_size = 0
        while not stop_tail.is_set():
            try:
                if log_file.exists():
                    current_size = log_file.stat().st_size
                    if current_size > last_size:
                        with open(log_file, 'r') as f:
                            f.seek(last_size)
                            new_content = f.read()
                            if new_content.strip():
                                for line in new_content.strip().split('\n'):
                                    formatted = format_log_line(line)
                                    if formatted:
                                        print(formatted)
                        last_size = current_size
            except:
                pass
            time.sleep(0.3)

    tail_thread = threading.Thread(target=tail_log, daemon=True)
    tail_thread.start()

    try:
        subprocess.run(cmd, cwd=str(project), env=env, timeout=10800)  # 3 timmar - stora spel
    except KeyboardInterrupt:
        print("\n\n⚠️  Avbruten av användare")
    except subprocess.TimeoutExpired:
        print("\n\n⚠️  Timeout (30 min)")
    finally:
        stop_tail.set()
        time.sleep(0.5)  # Låt sista loggarna skrivas ut

    # Sammanfattning
    print("\n" + "=" * 60)
    print(f"\n📂 Projekt: {project}")

    files = [f for f in project.rglob("*") if f.is_file() and not f.name.startswith(".")]
    if files:
        print("\n📁 Skapade filer:")
        total_lines = 0
        for f in sorted(files)[:20]:
            try:
                lines = len(f.read_text().splitlines())
                total_lines += lines
                print(f"   {f.relative_to(project)} ({lines} rader)")
            except:
                size = f.stat().st_size
                print(f"   {f.relative_to(project)} ({size} bytes)")

        if total_lines > 0:
            print(f"\n   Totalt: {total_lines} rader kod")

    print("\n✅ Klart!")


if __name__ == "__main__":
    main()
