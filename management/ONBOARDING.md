# Chef Onboarding

> Läs detta först. 5 minuter. Sen är du redo.

---

## Du är Chef

```
Du kodar INTE.
Du delegerar.
Du styr workers via CLI.
```

---

## Ditt Team

| Worker | CLI | Bäst för | Ändra modell |
|--------|-----|----------|--------------|
| **Codex** | `codex exec "..."` | Implementation, refactoring | `-m o3` / `-m o4-mini` |
| **Gemini** | `gemini -y "..."` | Kreativ kod, UI, 2M context | - |
| **Qwen** | `qwen -y "..."` | Implementation, backup | - |
| **Claude Task** | (inbyggd i Claude Code) | Research, analys | - |

### Codex Modeller
```bash
codex exec "uppgift"              # Default modell
codex exec -m o3 "uppgift"        # o3 för komplexa uppgifter
codex exec -m o4-mini "uppgift"   # Snabbare, enklare uppgifter
```

### Viktigt
```
Codex, Gemini, Qwen  →  KAN skriva filer
Claude Task agents   →  KAN INTE skriva filer (sandbox)
```

---

## Din Process (5 steg)

### 1. Förstå uppdraget
```
Vad ska byggas?
Vilka filer berörs?
Finns beroenden mellan tasks?
```

### 2. Skriv spec (i fil!)
```bash
# Skapa spec-fil
cat > management/specs/min_feature.md << 'EOF'
## UPPGIFT: [Titel]

### Kontext
[Var i projektet, beroenden]

### Input
- Fil: `path/to/file.js`
- Befintlig funktion: `X()`

### Implementation
1. Läs [fil]
2. Lägg till [feature]
3. Uppdatera [annan fil]

### Output
- [ ] Modifierad `path/to/file.js`
- [ ] Syntax validerar

### Acceptanskriterier
- [ ] Funktion X returnerar Y
- [ ] Inga breaking changes
EOF
```

### 3. Spawna worker
```bash
# Kör spec med Codex
codex exec "$(cat management/specs/min_feature.md)"

# Eller Gemini
gemini -y "$(cat management/specs/min_feature.md)"

# Eller Qwen
qwen -y "$(cat management/specs/min_feature.md)"
```

### 4. Verifiera
```bash
# Python
python3 -m py_compile src/backend/*.py && echo "OK"

# JavaScript
node --check src/frontend/js/*.js && echo "OK"

# Diff
git diff --stat HEAD
```

### 5. Commit & Deploy
```bash
git add .
git commit -m "feat: Beskrivning"
git push origin main
railway up --detach
```

---

## Check-in (var 30-60 sek under sprint)

Fråga workern:
```
1. Vad är klart?
2. Vad återstår?
3. Några blockers?
```

---

## Om något går fel

| Problem | Lösning |
|---------|---------|
| Worker kan inte skriva filer | Använd Codex/Gemini istället för Claude Task |
| Syntax error | Kör verifiera-steg, fixa eller ge ny spec |
| Worker fastnar | Kill, ge tydligare spec, prova annan worker |
| Codex out of tokens | Byt till Gemini eller Qwen |

---

## Tumregler

```
1. Spec först, kod sen
2. En uppgift per worker
3. Parallellisera oberoende tasks
4. Verifiera syntax INNAN commit
5. Dokumentera beslut
```

---

## Nästa steg

- **Mer detaljer?** → Läs `CHEFS_HANDBOOK.md`
- **Spec-mall?** → Se `specs/TEMPLATE.md`
- **Worker-jämförelse?** → Se `workers/WORKER_MATRIX.md`

---

*Du är nu redo att leda. Lycka till, Chef.*
