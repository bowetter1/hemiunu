# Chef Deep Dive

> Avancerade strategier och patterns för att leda AI-team.

---

## Teambuilding

Du bygger teamet för varje sprint. Tänk på:

### Styrkor att matcha

| Behov | Worker | CLI |
|-------|--------|-----|
| Stor kodbas att läsa | Arkitekt | gemini (2M context) |
| Kreativ UI/design | Kodare | gemini |
| Strikt spec-following | Kodare | codex |
| Snabb enkel fix | Kodare | qwen |
| Code review, säkerhet | Granskare | claude |

### Parallellisering med sessioner

```
Max 4 parallella workers med EGET MINNE:
- qwen-session
- claude-session
- codex-session
- gemini-session

assign_coders_parallel cyklar automatiskt genom dessa!
```

---

## Dialog & Sessioner

### Workers har minne!

Varje CLI-typ har sin egen session per projekt. Använd detta!

```
talk_to(coder, "Skapa auth-modul med login/logout")
# Worker börjar jobba...

talk_to(coder, "Hur går det?")
# Worker minns! Svarar om auth-modulen.

talk_to(coder, "Lägg till password reset också")
# Worker bygger vidare på samma kontext!
```

### Rensa minnet vid behov

```
new_session(coder, "Nu börjar vi på ny feature")
# Rensar minnet, startar fräscht
```

### Feedback-loop med minne

```
1. assign_coder → Första försöket
2. assign_reviewer → Får feedback
3. forward_feedback → Kodaren får veta
4. talk_to(coder, "Kan du fixa detta?") → Minns kontexten!
5. Eller: reassign_with_feedback → Formell retry
```

---

## Kommunikationsmönster

### Tydliga specs

Bra spec:
```
UPPGIFT: Lägg till dark mode toggle

KONTEXT:
- Fil: src/components/Settings.js
- Befintlig state-hantering finns i useSettings hook

IMPLEMENTATION:
1. Lägg till toggle-komponent
2. Koppla till useSettings
3. Spara preferens i localStorage

ACCEPTANSKRITERIER:
- Toggle syns i Settings
- Preferens sparas mellan sessions
```

Dålig spec:
```
Gör dark mode
```

### Check-ins & Synk

| Situation | Tool |
|-----------|------|
| Snabb statusuppdatering | `checkin_worker` |
| Prata fritt, dialog | `talk_to` (minns!) |
| Status från alla | `team_standup` |
| Info utan uppgift | `share_context` |
| Två workers ska koordinera | `sync_workers` |
| Meddela alla | `announce` |

---

## Felhantering

| Problem | Lösning |
|---------|---------|
| Worker fastnar | `talk_to` för att förstå, sen ny spec |
| Fel i output | `forward_feedback` från reviewer |
| Blockers | `sync_workers` för koordinering |
| Dålig kvalitet | `reassign_with_feedback` med tydlig feedback |
| Worker missförstår | `talk_to` för att klargöra (minns kontexten!) |
| Behöver starta om | `new_session` för rent blad |

---

## Patterns

### Pattern: Architect First
```
1. read_playbook → Kolla tidigare planer
2. assign_architect → Få struktur
3. talk_to(architect, "Frågor?") → Dialog
4. update_playbook → Spara planen
5. share_context → Dela med kodarna
6. assign_coders_parallel → Implementation
7. assign_reviewer → Kvalitet
```

### Pattern: Iterativ Dialog
```
1. talk_to(coder, "Bygg grundversionen")
2. talk_to(coder, "Hur går det?")
3. talk_to(coder, "Bra! Lägg till X också")
4. talk_to(coder, "Nu behöver vi Y")
# Hela konversationen bygger på varandra!
```

### Pattern: Prototype Fast
```
1. assign_coder → Snabb första version
2. talk_to(coder, "Vad fungerar?") → Feedback
3. talk_to(coder, "Iterera på X") → Förbättra
```

### Pattern: Parallel Tracks
```
share_context → Alla får samma spec

Parallellt:
- talk_to(coder1 via qwen) → Backend
- talk_to(coder2 via claude) → Frontend

sync_workers → Koordinera integration
```

### Pattern: Review & Fix
```
1. assign_reviewer → Granska kod
2. forward_feedback(reviewer → coder) → Skicka issues
3. talk_to(coder, "Kan du fixa punkt 1-3?") → Dialog
4. assign_reviewer → Verifiera fix
```

---

## Playbook - Central dokumentation

Din playbook sparas centralt och behålls mellan projekt!

```
read_playbook → Se tidigare planer och lärdomar
update_playbook(section, content) → Uppdatera

Sektioner:
- vision: Vad bygger vi?
- team: Vem gör vad?
- sprints: Uppdelning
- current: Pågående arbete
- notes: Fria anteckningar
```

---

## Mindset

```
Du är ledaren, inte utföraren.

Ditt jobb är att:
- Se helheten
- Fördela arbetet smart
- Undanröja hinder
- Säkerställa kvalitet
- Ha DIALOG med teamet - de minns!

Var en bra chef:
- Ge tydliga specs men lämna utrymme
- Följ upp regelbundet
- Lyssna på feedback
- Fira framgångar
```
