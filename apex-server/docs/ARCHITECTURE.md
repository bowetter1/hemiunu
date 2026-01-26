# Apex Arkitektur

## Översikt

```
┌─────────────────────────────────────────────────────────────┐
│  macOS App                                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  FastAPI Server (Railway)                                   │
├─────────────────────────────────────────────────────────────┤
│  • REST API                                                 │
│  • WebSocket för real-time                                  │
│  • Generator (Opus integration)                             │
└─────────────────────────────────────────────────────────────┘
          │                              │
          ▼                              ▼
┌──────────────────────┐    ┌──────────────────────────────────┐
│  PostgreSQL          │    │  Railway Volume (/data)          │
├──────────────────────┤    ├──────────────────────────────────┤
│  • users             │    │  /data/projects/{project_id}/    │
│  • projects (meta)   │    │  ├── .git/                       │
│  • pages (meta)      │    │  ├── public/                     │
│  • page_versions     │    │  │   ├── index.html              │
│    (endast meta)     │    │  │   └── styles.css              │
│                      │    │  ├── .apex/                      │
└──────────────────────┘    │  │   └── versions/{page_id}/     │
                            │  │       ├── v1.html             │
                            │  │       └── v2.html             │
                            │  └── src/                        │
                            │      └── app.py                  │
                            └──────────────────────────────────┘
```

---

## Datalagring

### PostgreSQL (metadata)

```sql
-- Befintlig tabell, ta bort html-kolumnen
pages (
    id UUID PRIMARY KEY,
    project_id UUID,
    name VARCHAR(100),           -- "Home", "About"
    file_path VARCHAR(500),      -- "public/index.html"
    current_version INT,         -- 3
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)

-- Befintlig tabell, ta bort html-kolumnen
page_versions (
    id UUID PRIMARY KEY,
    page_id UUID,
    version INT,                 -- 1, 2, 3
    instruction TEXT,            -- "Made button red"
    created_at TIMESTAMP
    -- INGEN html här längre!
)
```

### Filesystem (innehåll)

```
/data/projects/{project_id}/
├── .git/                        # Git repo för GitHub sync
├── .gitignore                   # Ignorerar .apex/
├── public/                      # Deploybar mapp
│   ├── index.html               # Live version
│   ├── about.html
│   └── assets/
│       └── styles.css
├── .apex/                       # Intern data (gitignored)
│   └── versions/
│       └── {page_id}/
│           ├── v1.html
│           ├── v2.html
│           └── v3.html
└── src/                         # Eventuell backend-kod
    └── app.py
```

---

## Flöden

### 1. Skapa nytt projekt

```
1. POST /projects { brief: "Hemsida för café" }
2. Skapa mapp: /data/projects/{id}/
3. git init
4. Skapa .gitignore (ignorera .apex/)
5. Generera moodboard → spara i PostgreSQL
6. Generera layouts → spara HTML i /public/
```

### 2. Redigera sida

```
1. POST /pages/{id}/edit { instruction: "Röd knapp" }
2. Läs /public/index.html
3. Opus redigerar
4. Spara till /public/index.html
5. Kopiera till .apex/versions/{page_id}/v{n+1}.html
6. UPDATE pages SET current_version = n+1
7. INSERT page_versions (version, instruction)
8. git add . && git commit -m "Röd knapp"
```

### 3. Byt version

```
1. POST /pages/{id}/restore { version: 2 }
2. Läs .apex/versions/{page_id}/v2.html
3. Kopiera till /public/index.html
4. UPDATE pages SET current_version = 2
```

### 4. Klona från GitHub

```
1. POST /projects/clone { github_url: "https://github.com/..." }
2. git clone {url} /data/projects/{id}/
3. Skanna filer → skapa pages i PostgreSQL
4. Opus kan nu redigera befintlig kod!
```

### 5. Deploy

```
1. POST /projects/{id}/deploy { provider: "vercel" }
2. cd /data/projects/{id}
3. vercel deploy public/
   ELLER
   git push origin main (om kopplat till Vercel/Netlify)
```

---

## Implementation TODO

### Steg 1: Förbered
- [ ] Ta bort MongoDB-kod (files.py, imports)
- [ ] Ta bort MongoDB från Railway

### Steg 2: Filesystem Service
- [ ] Skapa `FileSystemService` klass
  - `init_project(project_id)` - skapa mappar, git init
  - `read_file(project_id, path)` - läs fil
  - `write_file(project_id, path, content)` - skriv fil
  - `save_version(project_id, page_id, version, html)` - spara version
  - `get_version(project_id, page_id, version)` - hämta version
  - `list_versions(project_id, page_id)` - lista versioner
  - `clone_repo(project_id, github_url)` - klona repo

### Steg 3: Uppdatera Generator
- [ ] Ändra `generate_layouts()` att skriva till filesystem
- [ ] Ändra `agentic_edit()` att läsa/skriva filesystem
- [ ] Lägg till git commit efter edits

### Steg 4: Uppdatera Routes
- [ ] `get_page()` - läs HTML från filesystem
- [ ] `edit_page()` - spara version till filesystem
- [ ] `restore_version()` - kopiera från .apex/versions/
- [ ] Ny endpoint: `clone_from_github()`

### Steg 5: Uppdatera Models
- [ ] Ta bort `html` från `Page` model
- [ ] Ta bort `html` från `PageVersion` model
- [ ] Lägg till `file_path` i `Page` model

### Steg 6: Deploy & Test
- [ ] Railway deploy
- [ ] Testa skapa projekt
- [ ] Testa redigera
- [ ] Testa versionshistorik
- [ ] Testa GitHub clone

---

## Konfiguration

```python
# config.py
DATA_DIR = Path("/data")  # Railway Volume

def get_project_dir(project_id: str) -> Path:
    return DATA_DIR / "projects" / project_id
```

---

## Anteckningar

- Railway Volume är persistent mellan deploys
- `.apex/` mappen är gitignored - syns inte på GitHub
- Git commits ger extra historik utöver page versions
- Kan senare lägga till: branches, pull requests, collaboration
