# HEMIUNU v2.0 - Proof of Concept

## Vision

Förvandla kaotisk kod till en levande, låg-entropisk organism genom **systemisk fysik**, inte hierarki. Idé-meritokrati över social status.

---

## Kärninsikt

**AI misslyckas inte för att den är dum. Den misslyckas för att uppgiften är för stor för att verifiera.**

```
Dagens AI-problem:           Hemiunu-lösningen:
─────────────────            ──────────────────
Stor uppgift                 Liten uppgift
    │                            │
    ▼                            ▼
AI gissar ──► Fel            AI löser ──► Testar själv ──► Vet att det funkar
```

**Två regler. Inget mer:**
1. Bryt ner tills uppgiften är testbar
2. AI får inte leverera förrän den testat och det funkar

---

## Arkitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                     THE SUBSTRATE (SQLite)                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │   tasks   │  │ contracts │  │   scores  │  │  master   │    │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
   ┌───────────┐        ┌───────────┐        ┌───────────┐
   │   VESIR   │        │  WORKER   │        │CONTROLLER │
   │  (Chef)   │        │ (Builder) │        │(Validator)│
   └───────────┘        └───────────┘        └───────────┘
         │                    │                    │
         │   Delegerar        │   Bygger           │   Validerar
         │   kontrakt         │   max 150 LOC      │   mot kontrakt
         ▼                    ▼                    ▼
   ┌─────────────────────────────────────────────────────────┐
   │                    SCORE ENGINE                         │
   │  +poäng: raderad kod, passerade tester, förenkling      │
   │  -poäng: komplexitet, brutna kontrakt, cirkelberoenden  │
   └─────────────────────────────────────────────────────────┘
```

---

## CLI-spegeln: AI:ns Ögon

Nyckeln till att AI kan testa sig själv: **varje backend-funktion får ett CLI-kommando**.

```
┌─────────────┐         ┌─────────────┐
│   Backend   │◄───────►│     CLI     │
│   (koden)   │ speglar │  (testet)   │
└─────────────┘         └─────────────┘
                             │
                             ▼
                      AI kör CLI
                      ser output
                      vet om det funkar
```

**Utan CLI kodar AI blint. Med CLI kan AI iterera själv.**

```
Agent skriver kod
       │
       ▼
Agent kör CLI-kommando
       │
       ▼
Funkar? ──► Ja ──► Commit
       │
       ▼
      Nej ──► Fixa ──► Kör igen (loop)
```

---

## De 4 Oförhandlingsbara Lagarna

| # | Lag | Beskrivning | Implementation |
|---|-----|-------------|----------------|
| 1 | **Atomgränsen** | Max 150 rader kod per modul | `validate_loc(code) <= 150` |
| 2 | **Eliminerings-prioritet** | Radera > Addera. Förenkling ger högst status | `score += lines_deleted * 2` |
| 3 | **Idé-meritokrati** | Två lösningar tävlar. Lägst komplexitet vinner | `adversarial_solve(contract)` |
| 4 | **Transparens** | Alla ser allt. Worker kan flagga Vesirs fel | `visibility = "all"` |

---

## Databasschema (The Substrate)

```sql
-- Masterplan: Projektets DNA
CREATE TABLE master (
    id TEXT PRIMARY KEY DEFAULT 'root',
    vision TEXT NOT NULL,           -- Yttersta syftet
    principles TEXT,                -- JSON: lista av principer
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tasks: Alla uppgifter i systemet
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    parent_id TEXT,                 -- NULL = rot-uppgift
    contract_id TEXT NOT NULL,
    status TEXT DEFAULT 'TODO',     -- TODO | WORKING | REVIEW | GREEN | RED | SPLIT
    assigned_to TEXT,               -- worker_id
    code TEXT,
    loc INTEGER,                    -- Lines of code
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES tasks(id),
    FOREIGN KEY (contract_id) REFERENCES contracts(id)
);

-- Contracts: Gränssnittsdefinitioner
CREATE TABLE contracts (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    description TEXT NOT NULL,      -- Vad ska uppnås?
    master_link TEXT,               -- Koppling till Masterplan
    input_schema TEXT,              -- JSON Schema
    output_schema TEXT,             -- JSON Schema
    acceptance_criteria TEXT,       -- JSON: testbara kriterier
    locked BOOLEAN DEFAULT FALSE,   -- När TRUE: får ej ändras
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

-- Scores: Meritokratisk poängsättning
CREATE TABLE scores (
    id TEXT PRIMARY KEY,
    agent_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    action TEXT NOT NULL,           -- SOLVE | SPLIT | DELETE | SIMPLIFY | BREAK
    delta INTEGER NOT NULL,         -- +/- poäng
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Adversarial: Konkurrerande lösningar
CREATE TABLE adversarial (
    id TEXT PRIMARY KEY,
    contract_id TEXT NOT NULL,
    solution_a TEXT,
    solution_b TEXT,
    winner TEXT,                    -- 'a' | 'b' | NULL (pågår)
    complexity_a INTEGER,
    complexity_b INTEGER,
    decided_at TIMESTAMP,
    FOREIGN KEY (contract_id) REFERENCES contracts(id)
);
```

---

## Agent-definitioner

### 1. Vesir (Chef-agent)

```python
class Vesir:
    """
    Systemarkitekt. Delegerar eller delar upp.
    Får ALDRIG skriva kod direkt.
    """

    def analyze(self, task: Task, master: Master) -> Decision:
        """
        Returnerar:
        - DELEGATE: Uppgiften är atomär, skicka till Worker
        - SPLIT: Uppgiften är för komplex, dela upp i 2-10 sub-tasks
        """

    def split(self, task: Task) -> list[Contract]:
        """
        Skapar 2-10 nya kontrakt.
        Varje kontrakt måste:
        1. Länka till Master (master_link)
        2. Ha tydlig input/output schema
        3. Ha testbara acceptance_criteria
        """

    def handle_red(self, task: Task, feedback: str) -> Action:
        """
        När Controller returnerar RED:
        - Analysera: Var kontraktet dåligt?
        - Beslut: Omformulera kontrakt ELLER be ny Worker
        """
```

### 2. Worker (Byggar-agent)

```python
class Worker:
    """
    Atomär kodare. Max 150 rader.
    Ser BARA sitt kontrakt + Master-vision.
    """

    def solve(self, contract: Contract, master: Master) -> Code:
        """
        1. Läs master_link - förstå varför detta behövs
        2. Implementera enligt input/output schema
        3. Självvalidera mot acceptance_criteria
        4. STOPPA om LOC > 150 → returnera NEEDS_SPLIT
        """

    def flag_contract_error(self, contract: Contract, issue: str) -> Flag:
        """
        Transparens-lagen: Worker HAR RÄTT att ifrågasätta
        dåligt formulerade kontrakt. Flaggan går till Vesir.
        """
```

### 3. Controller (Validerar-agent)

```python
class Controller:
    """
    Oberoende granskare.
    Ser BARA kontrakt + färdig kod.
    Ser ALDRIG hur koden skrevs.
    """

    def validate(self, contract: Contract, code: Code) -> Result:
        """
        1. Parsa acceptance_criteria
        2. Kör kod mot test-cases
        3. Verifiera output matchar output_schema
        4. Returnera GREEN eller RED + feedback
        """

    def measure_complexity(self, code: Code) -> int:
        """
        Cyklomatisk komplexitet + LOC + beroenden.
        Används för adversarial jämförelser.
        """
```

---

## Flödet: Split-or-Solve

```
                    ┌─────────────────┐
                    │   MASTER DNA    │
                    │ (System-Readme) │
                    └────────┬────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ STEG 1: VESIR ANALYSERAR                                    │
│                                                             │
│   Uppgift ──► Jämför med Master ──► Estimera komplexitet    │
│                                            │                │
│                        ┌───────────────────┴───────────────┐│
│                        ▼                                   ▼│
│                   [< 150 LOC]                        [> 150]│
│                        │                                   ││
│                        ▼                                   ▼│
│                   DELEGATE                              SPLIT│
└─────────────────────────────────────────────────────────────┘
                        │                                   │
                        ▼                                   │
┌─────────────────────────────────┐                         │
│ STEG 2: WORKER BYGGER           │                         │
│                                 │                         │
│   Läs kontrakt + master_link    │    ┌────────────────────┘
│            │                    │    │
│            ▼                    │    ▼
│   Skriv kod (max 150 LOC)       │  Skapa 2-10 nya kontrakt
│            │                    │  Rekursivt tillbaka till STEG 1
│            ▼                    │
│   Självtest mot criteria        │
│            │                    │
│            ▼                    │
│   status = REVIEW               │
└─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ STEG 3: CONTROLLER VALIDERAR                                │
│                                                             │
│   Hämta kontrakt (SER EJ Worker's process)                  │
│            │                                                │
│            ▼                                                │
│   Kör acceptance_criteria som tester                        │
│            │                                                │
│            ▼                                                │
│   ┌────────┴────────┐                                       │
│   ▼                 ▼                                       │
│ [PASS]           [FAIL]                                     │
│   │                 │                                       │
│   ▼                 ▼                                       │
│ GREEN             RED + feedback                            │
│   │                 │                                       │
│   ▼                 └──────► Tillbaka till VESIR            │
│ DONE                        (Omformulera eller ny Worker)   │
└─────────────────────────────────────────────────────────────┘
```

---

## Adversarial Mode (Idé-meritokrati)

```
┌─────────────────────────────────────────────────────────────┐
│ När: Komplex uppgift med flera möjliga lösningar            │
│                                                             │
│   Kontrakt ──► Spawna 2 Workers parallellt                  │
│                     │                                       │
│         ┌───────────┴───────────┐                           │
│         ▼                       ▼                           │
│    Worker A                Worker B                         │
│    (Lösning A)             (Lösning B)                      │
│         │                       │                           │
│         └───────────┬───────────┘                           │
│                     ▼                                       │
│              Controller jämför:                             │
│              - Komplexitet (lägre = bättre)                 │
│              - Test-täckning                                │
│              - LOC                                          │
│                     │                                       │
│                     ▼                                       │
│              VINNARE väljs matematiskt                      │
│              (Ingen diskussion, ingen ego)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Poängsystem (Score Engine)

```python
SCORE_RULES = {
    # Positiva actions
    "SOLVE_GREEN":      +10,    # Löste uppgift, validerad grön
    "DELETE_CODE":      +2,     # Per raderad rad (eliminerings-prioritet)
    "SIMPLIFY":         +5,     # Minskade komplexitet utan funktionsförlust
    "FLAG_BAD_CONTRACT": +3,    # Identifierade dåligt kontrakt (transparens)
    "WIN_ADVERSARIAL":  +15,    # Vann idé-tävling

    # Negativa actions
    "SOLVE_RED":        -5,     # Levererade kod som failade
    "BREAK_CONTRACT":   -20,    # Ändrade låst kontrakt
    "EXCEED_LOC":       -10,    # Överskred 150-radersgränsen
    "ADD_COMPLEXITY":   -3,     # Ökade cyklomatisk komplexitet
    "CIRCULAR_DEP":     -15,    # Skapade cirkelberoende
}
```

---

## Filstruktur för POC

```
hemiunu/
├── README.md                 # Denna fil
├── requirements.txt          # anthropic, sqlite3
│
├── substrate/
│   ├── __init__.py
│   ├── db.py                # SQLite setup + migrations
│   └── schema.sql           # Databasschema
│
├── agents/
│   ├── __init__.py
│   ├── base.py              # Gemensam agent-logik
│   ├── vesir.py             # Chef/arkitekt
│   ├── worker.py            # Kodare
│   └── controller.py        # Validator
│
├── core/
│   ├── __init__.py
│   ├── contract.py          # Kontrakt-hantering
│   ├── score.py             # Poängsystem
│   └── adversarial.py       # Tävlingslogik
│
├── orchestrator.py          # Huvudloop som driver systemet
│
└── tests/
    ├── test_flow.py         # End-to-end test
    └── fixtures/
        └── sample_task.json # Exempeluppgift
```

---

## Första Testet

**Uppgift:** "Skriv ett bibliotek för primtalsberäkning"

```json
{
  "master": {
    "vision": "Matematiska verktyg för kryptografi",
    "principles": ["Korrekthet före hastighet", "Inga externa beroenden"]
  },
  "initial_task": {
    "description": "Primtalsbibliotek med is_prime() och generate_primes(n)",
    "acceptance_criteria": [
      "is_prime(7) == True",
      "is_prime(8) == False",
      "generate_primes(10) == [2, 3, 5, 7]",
      "Inga externa dependencies"
    ]
  }
}
```

**Förväntat flöde:**

1. Vesir analyserar → Enkelt nog, DELEGATE
2. Worker implementerar → ~30 LOC
3. Controller validerar → GREEN
4. Score: +10 (SOLVE_GREEN)

---

## Kommandoradsinterface (MVP)

```bash
# Initiera nytt projekt med Master-vision
python -m hemiunu init --vision "Beskrivning av projektet"

# Lägg till uppgift
python -m hemiunu add-task "Implementera X" --criteria "test1" "test2"

# Kör en iteration (process nästa TODO)
python -m hemiunu tick

# Visa status
python -m hemiunu status

# Visa poängtabell
python -m hemiunu scores
```

---

## Git & Deploy: Tidsbaserad Cykel

### Problemet med parallella agenter

```
Agent 1 ──► commit ──► push ──► deploy ──┐
Agent 2 ──► commit ──► push ──► deploy ──┼──► KAOS
Agent 3 ──► commit ──► push ──► deploy ──┘

- Merge conflicts
- Deployar över varandra
- Trasig prod
```

### Lösningen: Schemalagd deploy

Agenter jobbar alltid. Deploy sker på fasta tider (t.ex. var 15:e minut).

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Agenter jobbar parallellt hela tiden:                     │
│                                                             │
│   Agent 1 ──► branch-1 ──► lokal test ──► commit ──► push   │
│   Agent 2 ──► branch-2 ──► lokal test ──► commit ──► push   │
│   Agent 3 ──► branch-3 ──► lokal test ──► commit ──► push   │
│                                                             │
│   (Ingen väntar. Ingen lås. Alla kör.)                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                         │
            Var 15:e minut (cron)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   DEPLOY-CYKEL                              │
│                                                             │
│   1. Hämta alla branches med status GREEN                   │
│   2. Merge till main (en i taget)                           │
│   3. Om konflikt → skippa branchen, notifiera agent         │
│   4. Deploy main till staging                               │
│   5. Kör integrationstester                                 │
│   6. Om grönt → deploy prod                                 │
│   7. Om rött → rollback, notifiera                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Tidsflöde (exempel)

```
00:00  Agent 1 pushar branch-1 ✓
00:03  Agent 2 pushar branch-2 ✓
00:07  Agent 3 pushar branch-3 ✓
00:12  Agent 1 pushar branch-1 (fix) ✓

00:15  ════════ DEPLOY-CYKEL ════════
       → Merge branch-1 ✓
       → Merge branch-2 ✓
       → Merge branch-3 (konflikt!) ✗ skippas
       → Deploy staging
       → Integrationstest ✓
       → Deploy prod ✓
       ══════════════════════════════

00:16  Agent 3 får besked: "Konflikt i branch-3"
00:18  Agent 3: git pull --rebase, fixar, pushar

00:30  ════════ DEPLOY-CYKEL ════════
       → Merge branch-3 ✓
       → Deploy ✓
       ══════════════════════════════
```

### Implementation

```python
# cron: */15 * * * * python deploy_cycle.py

def deploy_cycle():
    # 1. Hämta gröna branches
    green_branches = db.query("SELECT branch FROM tasks WHERE status = 'GREEN'")

    merged = []
    for branch in green_branches:
        # 2. Försök merge
        result = run(f"git merge origin/{branch} --no-edit")

        if result.returncode != 0:  # Konflikt
            run("git merge --abort")
            notify_agent(branch, "CONFLICT: Rebase och fixa")
        else:
            merged.append(branch)

    if not merged:
        return  # Inget att deploya

    # 3. Push och deploy
    run("git push origin main")
    run("./deploy-staging.sh")

    # 4. Testa
    if run("./integration-tests.sh").returncode == 0:
        run("./deploy-prod.sh")
        for branch in merged:
            mark_deployed(branch)
    else:
        run("./rollback.sh")
        notify_all("DEPLOY FAILED - rollback utförd")
```

### Fördelar

| Lås-baserad deploy | Tidsbaserad deploy |
|--------------------|-------------------|
| Agenter väntar på varandra | Agenter jobbar alltid |
| Komplex koordinering | Ingen koordinering |
| En deploy åt gången | Batcha många ändringar |
| Realtid | 15 min delay (acceptabelt) |
| Race conditions | Inga race conditions |

---

## Agent-flödet: Lokal → Commit → Deploy

```
┌─────────────────────────────────────────────────────────────┐
│  FAS 1: LOKAL UTVECKLING                                    │
│  ───────────────────────                                    │
│                                                             │
│  Agent får uppgift                                          │
│       │                                                     │
│       ▼                                                     │
│  Skriver kod + CLI-kommando                                 │
│       │                                                     │
│       ▼                                                     │
│  Kör CLI lokalt ◄────────┐                                  │
│       │                  │                                  │
│       ▼                  │                                  │
│  Funkar? ───► Nej ───────┘                                  │
│       │                                                     │
│      Ja                                                     │
│       │                                                     │
└───────┼─────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  FAS 2: COMMIT                                              │
│  ─────────────                                              │
│                                                             │
│  git checkout -b feature/task-123                           │
│  git add .                                                  │
│  git commit -m "feat: beskrivning"                          │
│  git push origin feature/task-123                           │
│                                                             │
│  Markera task som GREEN i databasen                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
        │
        │  (Väntar på nästa deploy-cykel)
        ▼
┌─────────────────────────────────────────────────────────────┐
│  FAS 3: DEPLOY (var 15:e minut)                             │
│  ──────────────────────────────                             │
│                                                             │
│  Automatisk process:                                        │
│  - Merge alla GREEN branches                                │
│  - Deploy till staging                                      │
│  - Kör integrationstester                                   │
│  - Deploy till prod (om grönt)                              │
│                                                             │
│  Agent notifieras om resultat                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Nästa Steg

1. [ ] Implementera `substrate/db.py` - SQLite setup
2. [ ] Implementera `agents/base.py` - Gemensam LLM-anrop
3. [ ] Implementera `agents/vesir.py` - Split-or-delegate
4. [ ] Implementera `agents/worker.py` - Atomär kodning
5. [ ] Implementera `agents/controller.py` - Validering
6. [ ] Implementera `orchestrator.py` - Huvudloop
7. [ ] Testa med primtals-exemplet
8. [ ] Lägg till adversarial mode

---

## Framgångskriterier för POC

| Kriterie | Mätning |
|----------|---------|
| Atomär kod | Ingen modul > 150 LOC |
| Oberoende validering | Controller ser aldrig Worker's prompt |
| Rekursiv delning | Komplex uppgift delas automatiskt |
| Meritokrati | Poängsystem styr, inte "vem som pratade högst" |
| Transparens | Alla kontrakt synliga i DB |

---

*"Sök inte kreativa lösningar. Sök matematisk ordning."*
