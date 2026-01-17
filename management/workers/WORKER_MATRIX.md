# Worker Matrix

> Vilken worker för vilken uppgift? Denna guide hjälper dig välja rätt.

---

## Snabbval

| Uppgift | Bästa worker | Backup |
|---------|--------------|--------|
| **Implementation** | Codex | Gemini |
| **Refactoring** | Codex | Gemini |
| **Kreativ kod/UI** | Gemini | Qwen |
| **Research/Analys** | Claude Task | Gemini |
| **Läsa stor kodbas** | Gemini (2M context) | Claude Explore |
| **Snabb enkel fix** | Codex `-m o4-mini` | Qwen |
| **Komplex arkitektur** | Codex `-m o3` | Gemini |

---

## Worker Capabilities

| Worker | Kan skriva filer | CLI | YOLO-flag | Interaktiv |
|--------|------------------|-----|-----------|------------|
| **Codex** | ✅ Ja | `codex exec` | `--full-auto` | Nej (exec) |
| **Gemini** | ✅ Ja | `gemini` | `-y` | Ja |
| **Qwen** | ✅ Ja | `qwen` | `-y` | Ja |
| **Droid** | ✅ Ja | `droid` | - | **Endast interaktiv** |
| **Claude Task** | ❌ Sandbox | (inbyggd) | - | Nej |

---

## Codex

### Styrkor
- Följer specs strikt
- Bra på implementation
- Flera modellval
- Stabil i bakgrund

### Modellval
```bash
codex exec "uppgift"              # Default (balanserad)
codex exec -m o3 "uppgift"        # Komplex arkitektur, svåra problem
codex exec -m o4-mini "uppgift"   # Snabba, enkla tasks
```

### Användning
```bash
# Standard
codex exec "Läs src/main.py och lägg till logging"

# Med spec-fil
codex exec "$(cat management/specs/feature.md)"

# Full auto (ingen approval)
codex exec --full-auto "Fixa typo i README"
```

### Begränsningar
- Kan ta slut på tokens
- Ingen nätverksåtkomst i sandbox

---

## Gemini

### Styrkor
- 2M token context (kan läsa HELA kodbasen)
- Kreativ problemlösning
- Bra på UI/frontend
- Snabb

### Användning
```bash
# Standard (kräver -y för auto-approval)
gemini -y "Implementera dark mode i CSS"

# Med spec-fil
gemini -y "$(cat management/specs/feature.md)"

# Läs hela kodbasen
gemini -y "Läs alla filer i src/ och ge arkitektur-analys"
```

### Begränsningar
- Kan ibland ignorera "koda inte" instruktioner
- Mindre strikt än Codex på spec-following

---

## Qwen

### Styrkor
- Bra mönster-följare
- Pålitlig backup till Codex/Gemini
- Noggrann

### Användning
```bash
# Kräver -y för auto-approval
qwen -y "Lägg till achievement sound till audioManager"

# Med spec-fil
qwen -y "$(cat management/specs/feature.md)"
```

### Begränsningar
- Behöver `-y` flag (glöm inte!)
- Lite långsammare än Gemini

---

## Droid

### Styrkor
- (Otestad i pipeline)

### Begränsningar
- **Kräver interaktivt terminalläge**
- Fungerar INTE i bakgrund
- Kan inte användas som pipeline-worker

### Status
```
❌ Rekommenderas EJ för Chef-workflow
✅ Kan användas för manuell interaktiv dev
```

---

## Claude Task Agents

### Styrkor
- Inbyggda i Claude Code
- Bra på research och analys
- Snabba för läsning
- Explore, Plan, Bash subagents

### Begränsningar
- **KAN INTE SKRIVA FILER (sandbox)**
- Endast för research/analys

### Användning
```
Använd för:
✅ Analysera kodbas
✅ Hitta filer
✅ Researcha arkitektur
✅ Planera approach

Använd INTE för:
❌ Implementation
❌ Skriva kod
❌ Modifiera filer
```

---

## Beslutsträd

```
Behöver du skriva/ändra filer?
│
├─ NEJ → Claude Task (research)
│
└─ JA → Är det komplext?
         │
         ├─ JA → Codex -m o3
         │       (eller Gemini för kreativt)
         │
         └─ NEJ → Codex -m o4-mini
                  (eller Qwen som backup)
```

---

## Parallellisering

### Oberoende tasks → Kör parallellt
```bash
# Terminal 1
codex exec "Backend: lägg till endpoint" &

# Terminal 2
gemini -y "Frontend: lägg till UI-komponent" &

# Vänta på båda
wait
```

### Beroende tasks → Kör sekventiellt
```bash
# Först backend
codex exec "Backend: lägg till endpoint"

# Sen frontend (beror på backend)
gemini -y "Frontend: anropa nya endpoint"
```

---

## Felhantering

| Symptom | Trolig orsak | Lösning |
|---------|--------------|---------|
| "Cannot write file" | Fel worker (Claude Task) | Byt till Codex/Gemini |
| Syntax error i output | Dålig spec | Förtydliga spec, kör igen |
| Worker fastnar | Oklart uppdrag | Kill, ny tydligare spec |
| "Out of tokens" | Codex token-limit | Byt till Gemini/Qwen |
| "Raw mode not supported" | Droid i bakgrund | Använd annan worker |
| Ignorerar instruktioner | Gemini freestyle | Byt till Codex (striktare) |

---

## Rekommenderad Setup

```
┌─────────────────────────────────────────────────┐
│                 CHEF (Opus)                      │
│  Planerar • Skriver specs • Reviewar • Deployar │
├─────────────────────────────────────────────────┤
│                   WORKERS                        │
│                                                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│  │ Codex   │  │ Gemini  │  │  Qwen   │          │
│  │ Primary │  │ Creative│  │ Backup  │          │
│  └─────────┘  └─────────┘  └─────────┘          │
│                                                  │
│  ┌─────────────────────────────────────┐        │
│  │        Claude Task Agents           │        │
│  │     (Research only - no writes)     │        │
│  └─────────────────────────────────────┘        │
└─────────────────────────────────────────────────┘
```

---

*Senast uppdaterad: 2026-01-17*
