# Worker Matrix

> Apex A-Team: Claude + Qwen

---

## A-Team Konfiguration

```
┌─────────────────────────────────────────────────────────────┐
│                     🏆 APEX A-TEAM                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   👔 CHEF (Claude)                                          │
│   └── Koordinerar, beslutar, ser helheten                   │
│                                                             │
│   🏗️ ARCHITECT (Claude)         👨‍💻 CODER (Qwen)            │
│   └── Planerar, designar        └── Skriver kod snabbt     │
│                                                             │
│   🔍 REVIEWER (Claude)          🧪 TESTER (Qwen)            │
│   └── Granskar, säkerhet        └── Testar, validerar      │
│                                                             │
│   🎨 AD (Claude)                🚀 DEVOPS (Qwen)            │
│   └── Design, UX                └── Deploy, infra          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### config.py (Single Source of Truth)

```python
WORKER_CLI = {
    "chef": "claude",      # Koordinering, beslut
    "architect": "claude", # Planering, struktur
    "coder": "qwen",       # Snabb implementation
    "reviewer": "claude",  # Säkerhet, analytisk
    "tester": "qwen",      # Testning
    "ad": "claude",        # Design
    "devops": "qwen",      # Deploy
}
```

---

## Delegation Tools (assign_*)

| Roll | Tool | Beskrivning |
|------|------|-------------|
| 🎨 AD | `assign_ad(task)` | Design-riktlinjer, UX, färger |
| 🏗️ Architect | `assign_architect(task)` | Planering, struktur, PLAN.md |
| 👨‍💻 Coder | `assign_coder(task)` | Skriva kod |
| 👨‍💻 Coders | `assign_coders_parallel([...])` | Flera kodare samtidigt |
| 🔍 Reviewer | `assign_reviewer(files)` | Code review |
| 🧪 Tester | `assign_tester(task)` | Teststrategier, testfall |
| 🚀 DevOps | `assign_devops(task)` | Infra, CI/CD, config |

**Action tools** (kör saker, inte kreativa uppdrag):

🧪 Testning:
- `run_tests(framework?, path?)` - Kör pytest/npm test/bun/go test
- `run_lint(framework?, path?, fix?)` - Kör ruff/flake8/eslint/prettier
- `run_typecheck(framework?, path?)` - Kör mypy/pyright/tsc
- `run_qa(focus)` - AI-analys av projektet

🚀 Deploy:
- `deploy_railway()` - Deploya till Railway
- `check_railway_status()` - Kolla status

🔄 Iteration:
- `retry_step(step)` - Kör om tests/lint/typecheck/deploy/qa
- `rollback_deploy(confirm)` - Ångra senaste deploy
- `revert_file(file, source?)` - Återställ fil från git/backup
- `create_backup(file)` - Skapa backup
- `list_backups()` - Lista backups

📊 Kvalitetsgrindar:
- `evaluate_result(result)` - Parsea PASS/FAIL
- `gate_check(gate)` - GO/NO-GO beslut
- `quality_report()` - Full kvalitetsrapport

🧠 Boss-verktyg:
- `think(situation)` - Reflektera innan beslut
- `plan_next(current, goal)` - Planera nästa steg
- `log_decision(decision, reason)` - Dokumentera beslut
- `get_decisions()` - Hämta beslut
- `summarize_progress()` - Sammanfatta status

📦 Setup:
- `install_deps(manager?)` - Installera dependencies
- `setup_env(variables?)` - Skapa .env
- `init_project(type)` - Skapa projektstruktur
- `check_deps()` - Kolla outdated

---

## Sprint-flöde (18 steg)

```
👔 CHEF (Claude) kör hela flödet:

📦 SETUP
   think ──────────────→ 🧠 "Vad behövs för detta projekt?"
          │
          ▼
   init_project ───────→ 📦 Skapa projektstruktur
          │
          ▼
   install_deps ───────→ 📦 Installera dependencies

🎨 DESIGN & PLANERING
          │
          ▼
   assign_ad ──────────→ 🎨 AD ger design-riktlinjer
          │
          ▼
   assign_architect ───→ 🏗️ Architect skapar PLAN.md
          │
          ▼
   log_decision ───────→ 📝 Dokumentera arkitektur-beslut

👨‍💻 IMPLEMENTATION
          │
          ▼
   team_kickoff ───────→ 👔 "Alla på plats - NU KÖR VI!"
          │
          ▼
   assign_coders ──────→ 👨‍💻 Coder 1 (qwen)  ──→ backend
          │             👨‍💻 Coder 2 (claude) ──→ frontend
          ▼
   assign_tester ──────→ 🧪 Tester skriver testfall

✅ KVALITETSKONTROLL
          │
          ▼
   run_tests ──────────→ 🧪 pytest/npm test
   run_lint ───────────→ 🔍 ruff/eslint
   run_typecheck ──────→ 📝 mypy/tsc
          │
          ▼
   gate_check ─────────→ 📊 GO/NO-GO?
          │                  ↓ NO-GO → retry_step
          ▼
   assign_reviewer ────→ 🔍 Reviewer granskar kod

🚀 DEPLOY
          │
          ▼
   gate_check("pre_deploy") → 📊 Alla checks gröna?
          │
          ▼
   deploy_railway ─────→ 🚀 DevOps deployar → Live URL
          │
          ▼
   mcp__playwright__browser_snapshot → 📸 Verifiera live-siten!
          │                  ↓ FEL → rollback_deploy + retry

🎉 AVSLUT
          │
          ▼
   team_demo ──────────→ 👔 Chef visar resultat
          │
          ▼
   team_retrospective ─→ 🎉 Alla reflekterar
          │
          ▼
   summarize_progress ─→ 📊 Sammanfatta leverans
```

### Steg-tabell

| Fas | Steg | Tool | Output |
|-----|------|------|--------|
| 📦 Setup | 1 | `think` | Reflektera |
| | 2 | `init_project` | Projektstruktur |
| | 3 | `install_deps` | Dependencies |
| 🎨 Design | 4 | `assign_ad` | Design-riktlinjer |
| | 5 | `assign_architect` | PLAN.md |
| | 6 | `log_decision` | Beslut loggat |
| 👨‍💻 Impl | 7 | `team_kickoff` | "Nu kör vi!" |
| | 8 | `assign_coders_parallel` | Kod |
| | 9 | `assign_tester` | Testfall |
| ✅ QA | 10 | `run_tests` | PASS/FAIL |
| | 11 | `run_lint` | CLEAN/ISSUES |
| | 12 | `gate_check` | GO/NO-GO |
| | 13 | `assign_reviewer` | APPROVED |
| 🚀 Deploy | 14 | `gate_check("pre_deploy")` | GO |
| | 15 | `deploy_railway` | Live URL |
| | 16 | `mcp__playwright__browser_snapshot` | Verifierad |
| 🎉 Avslut | 17 | `team_demo` | Resultat |
| | 18 | `summarize_progress` | Rapport |

---

## Tillgängliga AI:er

| AI | Styrka | Roller | Status |
|----|--------|--------|--------|
| **claude** | Analytisk, säkerhet, stor context | Chef, Architect, Reviewer, AD | ✅ Aktiv |
| **qwen** | Snabb, pålitlig, bra på kod | Coder, Tester, DevOps | ✅ Aktiv |
| ~~gemini~~ | ~~2M context~~ | ~~-~~ | ❌ Disabled |
| ~~codex~~ | ~~Spec-following~~ | ~~-~~ | ❌ Disabled |

---

## Parallella Coders

```
┌─────────────────────────────────────────┐
│  assign_coders_parallel([...])          │
├─────────────────────────────────────────┤
│  Coder 1  →  qwen   →  fil1.py         │
│  Coder 2  →  claude →  fil2.py         │
│  Coder 3  →  qwen   →  fil3.py  (cykel)│
└─────────────────────────────────────────┘
```

**Max 2 coders med eget minne** (en per aktiv AI).

```python
PARALLEL_CODER_CLIS = ["qwen", "claude"]

# Cyklar: coder[0]=qwen, coder[1]=claude, coder[2]=qwen...
cli = PARALLEL_CODER_CLIS[i % len(PARALLEL_CODER_CLIS)]
```

---

## Dialog & Minne

Workers har **minne** inom en session:

```
talk_to(coder, "Skapa login.py")
talk_to(coder, "Hur går det?")      ← minns uppdraget!
talk_to(coder, "Lägg till logout")  ← bygger vidare!

new_session(coder, "Ny feature")    ← rensar minnet
```

---

## CLI-kommandon

| AI | Kommando | Session |
|----|----------|---------|
| qwen | `qwen -y "prompt"` | `--continue` |
| claude | `claude -p "prompt" --dangerously-skip-permissions` | `--continue` |

---

## Ändra team-sammansättning

Ändra i `config.py`:

```python
# Exempel: Byt Architect till qwen
WORKER_CLI = {
    "architect": "qwen",  # ← ändra här
    ...
}
```

Alla tools använder `get_worker_cli()` som läser från denna config.

---

## Möten

| Möte | När | Vad |
|------|-----|-----|
| `team_kickoff` | Efter architect | Presentera planen |
| `team_standup` | Under sprint | Check-in med alla |
| `team_demo` | Efter kodning | Visa resultatet |
| `team_retrospective` | Sist | Feedback & lärdomar |

---

*Senast uppdaterad: 2026-01-19*
