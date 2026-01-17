# Spec Template

> Kopiera denna fil och fyll i för varje feature/uppgift.
> Spara som: `specs/[feature_namn].md`

---

## UPPGIFT: [Kort titel]

### Roll
[Backend Developer / Frontend Developer / Full-stack / etc.]

### Kontext
[1-2 meningar: Vilket projekt? Var passar denna uppgift in?]

---

### Input

**Filer att läsa:**
- `path/to/file1.js`
- `path/to/file2.py`

**Befintlig kod att förstå:**
- Funktion: `existingFunction()`
- Klass: `ExistingClass`

**Beroenden:**
- [Lista externa paket eller interna moduler]

---

### Implementation

**Steg-för-steg:**
1. Läs `[fil]` och förstå [X]
2. Skapa/modifiera `[funktion/klass]`
3. Implementera [feature]
4. Uppdatera `[annan fil]` om nödvändigt

**Tekniska detaljer:**
```
[Exakta fältnamn, message-format, API-struktur etc.]

Exempel:
Message format: {'type': 'event_name', 'data': {'field': value}}
Endpoint: GET /api/resource?param=value
```

---

### Output

**Förväntade ändringar:**
- [ ] Modifierad `path/to/file.js`
- [ ] Ny funktion `newFunction()`
- [ ] Uppdaterad `path/to/other.py`

**Inget av detta:**
- Ändra inte [fil som inte ska röras]
- Lägg inte till [onödig feature]

---

### Acceptanskriterier

- [ ] Syntax validerar utan fel
- [ ] Funktion X returnerar Y vid input Z
- [ ] Inga breaking changes mot befintlig kod
- [ ] Följer befintliga mönster i kodbasen

---

### Regler

```
- Läs befintlig kod FÖRST
- Följ existerande mönster
- Minimal ändring - gör ENDAST det som specs säger
- Koda INTE utanför scope
- Om oklart: fråga / rapportera blocker
```

---

## Användning

```bash
# Kör med Codex
codex exec "$(cat management/specs/denna_fil.md)"

# Kör med Gemini
gemini -y "$(cat management/specs/denna_fil.md)"

# Kör med Qwen
qwen -y "$(cat management/specs/denna_fil.md)"
```

---

## Exempel: Fylld spec

```markdown
## UPPGIFT: Lägg till rate limiting på mine_stone

### Roll
Backend Developer

### Kontext
Hemiunu är ett multiplayer pyramid-byggarspel. mine_stone kan spammas.

### Input
- `src/backend/main.py` - handle_mine_stone funktion

### Implementation
1. Läs handle_mine_stone
2. Lägg till last_mine_time dict
3. Kolla om user minat inom 1 sekund
4. Returnera error om för snabbt

Message format: {'type': 'rate_limited', 'data': {'message': 'Too fast'}}

### Output
- [ ] Modifierad `src/backend/main.py`

### Acceptanskriterier
- [ ] Mine blockeras om < 1 sek sedan förra
- [ ] Befintlig funktionalitet oförändrad
```
