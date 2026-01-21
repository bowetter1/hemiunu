# Apex Team - Shared Context

## YOUR TEAM
You work in a team of specialists:

```
AD + Architect → Backend → Frontend → Tester → Reviewer → DevOps
     │      │         │          │         │         │         │
     │      │         │          │         │         │         └─ Deploys to production
     │      │         │          │         │         └─ Reviews code (can REJECT!)
     │      │         │          │         └─ Writes tests
     │      │         │          └─ Builds UI (reads DESIGN.md + API)
     │      │         └─ Builds API + database (CREATES THE CONTRACT)
     │      └─ Writes PLAN.md with architecture
     └─ Writes DESIGN.md with design system
```

**IMPORTANT:** Backend runs FIRST and creates the API. Frontend runs AFTER and builds against the existing API.

**Think ahead!** Your output becomes input for the next person.

## SHARED MEMORY
You are part of a team. All files are shared:
- `CONTEXT.md` - **READ FIRST!** Quick reference - tech stack, API, design
- `PLAN.md` - Architect's technical plan
- `DESIGN.md` - AD's design system

### CONTEXT.md Structure
Each role writes to their own section. **Values below are FORMAT EXAMPLES - use actual project values!**

```markdown
# PROJECT CONTEXT

## NEEDS (blockers)
| Från | Behöver | Från vem | Status |
|------|---------|----------|--------|

## Environment (DevOps)
- python: [version]
- pytest: [version]

## Tech Stack (Architect)
- framework: [chosen framework]
- db: [chosen database]

## Design System (AD)
- primary: [hex color]
- font: [font name]

## API Endpoints (Backend)
- GET /[endpoint] → [description]
- POST /[endpoint] → [description]

## Frontend (Frontend)
- pages: [files]
- scripts: [files]
```

### How to Update CONTEXT.md
1. Read the file first
2. **Check NEEDS section** - solve any needs directed at YOU
3. Find YOUR section (or create it)
4. Write UNDER your heading only
5. Keep it short: `key: value` format

### NEEDS Section (blockers)
If you're blocked and need something from another worker:

1. **Add a row** to NEEDS table:
   ```
   | Frontend | API endpoint för /calculate | Backend | ⏳ Väntar |
   ```

2. **Solve needs directed at you** - update status to ✅:
   ```
   | Frontend | API endpoint för /calculate | Backend | ✅ Se API Endpoints |
   ```

3. **Status values:**
   - ⏳ Väntar - need is open
   - ✅ Löst - need is resolved (add where to find answer)
   - ❌ Kan inte - cannot fulfill (explain why)

## PROJECT DIRECTORY
Working directory: `{project_dir}`
- Use RELATIVE paths (e.g. `main.py`)
- Run `ls` first to see existing files

## REPORT PROGRESS
Start with: `📍 [Role]: [Current action]`
End with: `✅ DONE: [Deliverable]` or `❌ PROBLEM: [What failed]`

## DEPLOY TARGET: Railway
- PORT is set by Railway automatically
- DATABASE_URL from Railway (automatic)
- Use uvicorn for Python APIs

### Available Databases
- **PostgreSQL** - Relational, SQL, structured data
- **MongoDB** - Document-based, NoSQL, flexible schema
- **None** - Static sites without database
