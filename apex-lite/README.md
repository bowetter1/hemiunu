# Apex Lite

**Boss + Devs** - En ny typ av AI-organisation.

## Filosofi

```
APEX (team):     Chef → AD → Architect → Backend → Frontend → Tester → ...
APEX LITE:       Boss → Devs (parallellt)
```

**Insikt:** En solo-AI som håller hela kontexten slår ett team som måste synka.

**Lösning:** Boss delar upp arbetet i **självständiga moduler** (2000+ rader var) som Devs bygger parallellt - minimal sync.

## Arkitektur

```
     Människa
        ↓
    ┌───────┐
    │ BOSS  │  ← Analyserar, delar upp, driver framåt
    │(Opus) │
    └───┬───┘
        │
   ┌────┼────┐
   ↓    ↓    ↓
  Dev  Dev  Dev   ← Bygger kompletta moduler (2000+ rader)
```

## Användning

```bash
cd apex-lite
python cli.py "Bygg ett quiz-spel"
python cli.py "Bygg en e-commerce site med produkter och varukorg"
```

## Boss-uppgift

1. **Analysera** uppdraget
2. **Dela upp** i självständiga moduler
3. **Definiera interfaces** mellan moduler
4. **Starta devs** parallellt
5. **Integrera** vid behov

## Uppdelningsguide

| Projekt | Moduler | Exempel |
|---------|---------|---------|
| Litet | 1 | Quiz, timer, calculator |
| Medium | 2 | Todo med auth, blog |
| Stort | 3-4 | E-commerce, dashboard |

**Regel:** Hellre 1 stor modul än 3 små med beroenden.

## Tools (Boss)

**Delegation:**
- `assign_dev(spec)` - Starta en dev
- `assign_devs_parallel(modules)` - Starta flera devs

**Kommunikation:**
- `write_context(message, author)` - Skriv till delad CONTEXT.md
- `read_context()` - Läs vad devs rapporterat
- `thinking(thought)` - Logga tankar

**Filer:**
- `list_files()` - Se filer
- `read_file(path)` - Läs fil
- `write_file(path, content)` - Skriv fil

**Kommandon:**
- `run_command(cmd)` - Kör shell (tester, etc.)

## vs Apex Team

| Aspekt | Apex Team | Apex Lite |
|--------|-----------|-----------|
| Roller | 10 specialister | Boss + Devs |
| Sync | CONTEXT.md, PLAN.md | Minimal (modul-spec) |
| Fokus | Orkestrering | Decomposition |
| Overhead | Hög (koordinering) | Låg |

## Filer

```
apex-lite/
├── cli.py              # Entry point
├── mcp_server.py       # MCP server
├── mcp-config.json     # MCP config
├── tools.py            # Tools
├── prompts/
│   ├── boss.md         # Boss prompt
│   └── dev.md          # Dev prompt
└── README.md
```
