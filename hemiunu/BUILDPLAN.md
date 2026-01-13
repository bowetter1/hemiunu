# HEMIUNU - Byggplan

## Vad vi har byggt (POC v1)

```
✅ substrate/db.py      - SQLite persistens
✅ core/tools.py        - run_command, read/write_file
✅ agent_loop.py        - En agent som testar sin egen kod
✅ cli.py               - init, add, tick, status
```

**Testat:** En agent löste `is_prime()` - skrev kod, testade, markerade klar.

---

## Vad vi ska bygga (v2)

### Roller

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   VESIR           Ser hela planen, bryter ner i uppgifter       │
│      │                                                          │
│      ▼                                                          │
│   WORKER ◄──────► TESTARE (Twin-Spawn)                          │
│      │               │                                          │
│      │               │  Oberoende test                          │
│      ▼               ▼                                          │
│   [KOD]    +    [TEST]  ──► Båda gröna? ──► COMMIT              │
│                                    │                            │
│                                    ▼                            │
│                              INTEGRATÖR                         │
│                              (vid konflikt)                     │
│                                    │                            │
│                                    ▼                            │
│                                 DEPLOY                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Fas 1: Grundläggande roller (Vecka 1)

### 1.1 Databasschema - utöka
```
Fil: substrate/db.py

Nya tabeller:
- agents (id, role, model, status)
- test_results (task_id, worker_id, tester_id, passed, output)
- conflicts (id, branch_a, branch_b, status, resolution)
- deploy_log (id, timestamp, branches, status, error)
```

### 1.2 Worker-agent (refaktorera befintlig)
```
Fil: agents/worker.py (~80 LOC)

Input:  Task med beskrivning + kontrakt
Output: Kod + CLI-kommando för testning
Tools:  read_file, write_file, run_command, task_done, task_failed, split_task
Regel:  Max 150 LOC, annars split_task
```

### 1.3 Testare-agent (ny)
```
Fil: agents/tester.py (~80 LOC)

Input:  Task-beskrivning + Worker's CLI-test
Output: Oberoende testsvit
Tools:  read_file, write_file, run_command, approve, reject
Regel:  Ser ALDRIG Worker's kod innan test är skrivet
        Kör Worker's test + egna tester
```

### 1.4 Orchestrator - Twin-Spawn
```
Fil: orchestrator.py (~100 LOC)

Flöde:
1. Hämta nästa TODO
2. Spawna Worker + Testare parallellt
3. Worker skriver kod
4. Testare skriver test (utan att se koden)
5. Testare kör tester på Worker's kod
6. Om grönt: commit
7. Om rött: Worker får feedback, försök igen
```

---

## Fas 2: Git-integration (Vecka 2)

### 2.1 Branch-hantering
```
Fil: core/git.py (~60 LOC)

Funktioner:
- create_branch(task_id) -> branch_name
- commit_changes(task_id, message)
- push_branch(branch_name)
- get_branch_status(branch_name) -> ahead/behind
```

### 2.2 Worker uppdateras
```
Efter task_done:
1. git checkout -b feature/task-{id}
2. git add .
3. git commit -m "feat: {beskrivning}"
4. git push origin feature/task-{id}
5. Uppdatera DB: branch = feature/task-{id}
```

---

## Fas 3: Deploy-cykel (Vecka 3)

### 3.1 Deploy-script
```
Fil: deploy_cycle.py (~100 LOC)

Körs: Var 15:e minut (cron)

Flöde:
1. git checkout main && git pull
2. Hämta GREEN branches från DB
3. För varje branch:
   - git merge origin/{branch} --no-edit
   - Om konflikt: skapa conflict-record, fortsätt
4. git push origin main
5. Kör integrationstester
6. Om grönt: markera DEPLOYED
7. Om rött: git reset --hard, notifiera
```

### 3.2 Integratör-agent (vid konflikter)
```
Fil: agents/integrator.py (~100 LOC)

Input:  Två branches med konflikt
Output: Löst merge eller ABORT
Tools:  read_conflict, read_branch_a, read_branch_b,
        resolve_conflict, run_tests, complete_merge, abort_merge
```

---

## Fas 4: Vesir + Nedbrytning (Vecka 4)

### 4.1 Vesir-agent
```
Fil: agents/vesir.py (~100 LOC)

Input:  Stort uppdrag från användare
Output: Lista av atomära tasks med kontrakt
Tools:  analyze_codebase, create_task, define_contract,
        estimate_complexity, reject_task
Regel:  Varje task måste ha:
        - Beskrivning
        - Input/Output-schema
        - CLI-test
        - Max 150 LOC estimat
```

### 4.2 Golden Thread
```
Fil: core/context.py (~40 LOC)

Funktion: inject_context(agent, task)

Varje agent får:
- Masterplanens vision
- Hur denna task passar in
- Beroenden till andra tasks
- Begränsningar
```

---

## Fas 5: Lab-diversitet + Minne (Vecka 5)

### 5.1 Multi-LLM stöd
```
Fil: core/llm.py (~80 LOC)

Providers:
- Anthropic (Claude)
- OpenAI (GPT-4)
- Google (Gemini)

Logik:
- Default: Claude
- Vid 3 fails: byt till GPT-4
- Vid 3 fails: byt till Gemini
- Logga vilken modell som löste vad
```

### 5.2 Failure Memory
```
Fil: substrate/memory.py (~60 LOC)

Tabell: failures (task_pattern, error_type, solution, count)

Vid ny task:
- Sök efter liknande tidigare failures
- Injicera i prompt: "OBS: Liknande task failade pga X. Undvik Y."
```

---

## Fas 6: AI-Beställare (Vecka 6)

### 6.1 Acceptance-agent
```
Fil: agents/acceptor.py (~80 LOC)

Input:  Färdig feature (alla tasks gröna)
Output: ACCEPT eller REJECT med feedback
Tools:  run_e2e_test, check_user_value, verify_requirements
Regel:  Testar NYTTA, inte bara korrekthet
        "Kan en användare faktiskt göra X med detta?"
```

---

## Filstruktur (slutgiltig)

```
hemiunu/
├── BUILDPLAN.md              # Denna fil
├── hemiunu_poc.md            # Designdokument
│
├── substrate/
│   ├── db.py                 # SQLite + schema
│   └── memory.py             # Failure memory
│
├── core/
│   ├── tools.py              # Bas-verktyg
│   ├── git.py                # Git-operationer
│   ├── context.py            # Golden Thread
│   └── llm.py                # Multi-LLM
│
├── agents/
│   ├── base.py               # Gemensam agent-klass
│   ├── vesir.py              # Strategisk nedbrytning
│   ├── worker.py             # Kodskrivning
│   ├── tester.py             # Oberoende testning
│   ├── integrator.py         # Merge-konflikter
│   └── acceptor.py           # Acceptanstest
│
├── orchestrator.py           # Huvudloop, Twin-Spawn
├── deploy_cycle.py           # Cron-jobb för deploy
│
├── cli.py                    # Användarinterface
│
└── tests/
    ├── test_worker.py
    ├── test_tester.py
    ├── test_integration.py
    └── fixtures/
```

---

## Prioritetsordning

```
MÅSTE HA (MVP):
1. Worker + Testare (Twin-Spawn)
2. Git-integration (branch per task)
3. Deploy-cykel (var 15 min)
4. Integratör (lösa konflikter)

BRA ATT HA:
5. Vesir (automatisk nedbrytning)
6. Golden Thread (kontext-injektion)
7. Lab-diversitet (multi-LLM)

NICE TO HAVE:
8. Failure Memory
9. AI-Beställare
10. Score Engine
```

---

## Test-scenarion

### Scenario 1: Enkel task (redan testat ✅)
```
Input:  "Implementera is_prime(n)"
Output: Fungerande kod + test
```

### Scenario 2: Twin-Spawn
```
Input:  "Implementera password hashing"
Output: Worker's kod + Testare's oberoende tester
        Båda måste vara gröna
```

### Scenario 3: Parallella workers
```
Input:  3 tasks samtidigt
Output: 3 branches, mergade var 15 min
```

### Scenario 4: Merge-konflikt
```
Input:  2 workers ändrar samma fil
Output: Integratör löser konflikten
```

### Scenario 5: Stor uppgift
```
Input:  "Bygg auth-system med login/logout/register"
Output: Vesir bryter ner i 5-10 atomära tasks
        Varje task körs av Worker+Testare
```

---

## Nästa steg

1. [ ] Utöka databasschemat (agents, test_results, conflicts)
2. [ ] Refaktorera agent_loop.py → agents/worker.py
3. [ ] Skapa agents/tester.py (Twin-Spawn)
4. [ ] Skapa orchestrator.py med parallell körning
5. [ ] Testa Scenario 2 (Twin-Spawn)

---

*"Bygg inkrementellt. Testa varje steg. Committa när grönt."*
