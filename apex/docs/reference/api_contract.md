# API Contract

Teknisk referens för Apex MCP-verktyg.

---

## Roller

Alla tools stödjer dessa roller:
- `ad` - Art Director
- `architect` - Architect
- `coder` - Coder
- `tester` - Tester
- `reviewer` - Reviewer
- `devops` - DevOps

## AI Parameter

De flesta tools accepterar en valfri `ai` parameter:
- `qwen` - Snabb, bra på implementation ✅
- `claude` - Analytisk, säkerhet, stor context ✅
- ~~`gemini`~~ - Disabled (token-brist)
- ~~`codex`~~ - Disabled (token-brist)

Om `ai` inte anges används default för rollen (se WORKER_MATRIX.md).

---

## Team Management

### team_kickoff
Starta sprint med kickoff-möte.

```json
{
  "vision": "Vad bygger vi? Varför?",
  "goals": ["Mål 1", "Mål 2", "Mål 3"]
}
```

### team_standup
Snabb statusuppdatering från teamet.

```json
{
  "question": "Hur går det? Några blockers?"
}
```

### team_retrospective
Avsluta sprint, samla feedback.

```json
{
  "sprint_summary": "Sammanfattning av vad som gjordes"
}
```

---

## Delegation

### assign_architect
Ge Architect ett uppdrag.

```json
{
  "task": "Planera strukturen för X",
  "context": "Extra information",
  "ai": "claude"  // optional, default: claude
}
```

### assign_coder
Ge Coder ett uppdrag.

```json
{
  "task": "Implementera Y",
  "file": "src/path/to/file.py",
  "ai": "qwen"  // optional, default: qwen
}
```

### assign_coders_parallel
Ge uppgifter till flera Coders samtidigt.

```json
{
  "assignments": [
    {"coder_name": "coder_1", "task": "Backend endpoint", "file": "src/api.py"},
    {"coder_name": "coder_2", "task": "Frontend UI", "file": "src/app.js"}
  ]
}
```

### assign_reviewer
Be Reviewer granska kod.

```json
{
  "files_to_review": ["src/api.py", "src/app.js"],
  "focus": "Säkerhet och felhantering",
  "ai": "claude"  // optional, default: claude
}
```

---

## Dialog & Kommunikation

### talk_to
Prata fritt med en worker. **Har minne** - worker kommer ihåg tidigare i konversationen.

```json
{
  "worker": "coder",  // ad|architect|coder|tester|reviewer|devops
  "message": "Hur går det med login-modulen?",
  "ai": "qwen"  // optional
}
```

### checkin_worker
Snabb check-in med en worker.

```json
{
  "worker": "architect",  // ad|architect|coder|tester|reviewer|devops
  "question": "Hur ligger du till?",
  "ai": "claude"  // optional
}
```

### announce
Skicka meddelande till hela teamet (ingen fråga, bara info).

```json
{
  "message": "Vi byter fokus till bugfix",
  "tone": "informativ"  // informativ|motiverande|brådskande
}
```

### share_context
Dela information med en eller flera workers.

```json
{
  "context": "Här är specen för auth-modulen...",
  "to_workers": ["coder", "tester"],
  "note": "Prioritera detta"
}
```

### forward_feedback
Vidarebefordra feedback mellan workers.

```json
{
  "feedback": "Reviewers kommentarer...",
  "from_role": "Reviewer",
  "to_worker": "coder",
  "your_comment": "Kan du fixa punkt 1-3?",
  "ai": "qwen"  // optional
}
```

### sync_workers
Låt två workers prata med varandra.

```json
{
  "worker1": "architect",
  "worker2": "coder",
  "topic": "API-design",
  "goal": "Komma överens om endpoints"
}
```

### reassign_with_feedback
Skicka tillbaka uppgift med feedback.

```json
{
  "worker": "coder",
  "original_task": "Skapa login",
  "feedback": "Saknas error handling",
  "file": "src/auth.py",
  "encouragement": "Bra start!",
  "ai": "qwen"  // optional
}
```

### new_session
Starta ny session (rensa minne).

```json
{
  "worker": "coder",
  "intro": "Nu börjar vi på ny feature",
  "ai": "qwen"  // optional
}
```

---

## Playbook

### read_playbook
Läs projektets playbook.

```json
{}
```

### update_playbook
Uppdatera en sektion i playbook.

```json
{
  "section": "current",  // vision|team|sprints|current|notes
  "content": "Just nu jobbar vi på auth"
}
```

---

## Filer

### read_file
Läs en fil i projektet.

```json
{
  "file": "src/app.js"
}
```

### list_files
Lista alla filer i projektet.

```json
{}
```

---

## QA & Deploy

### run_qa
Kör kvalitetstester.

```json
{
  "focus": "integration"  // integration|UI|API
}
```

### deploy_railway
Deploya till Railway.

```json
{
  "with_database": "postgres"  // none|postgres|mongo
}
```

### check_railway_status
Kolla deployment-status, loggar och URL.

```json
{}
```

---

## Övrigt

### ask_user
Fråga användaren.

```json
{
  "question": "Vilken design föredrar du?",
  "options": ["Modern", "Klassisk", "Minimalistisk"]
}
```

### open_browser
Öppna fil i webbläsare.

```json
{
  "file": "index.html"
}
```

---

*Senast uppdaterad: 2026-01-19*
