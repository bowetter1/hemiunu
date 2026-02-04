# AI Team Collaboration

Apex använder flera AI-modeller som ett team. Varje modell har olika styrkor — genom att kombinera dem får vi output som överträffar en enskild modell.

> "Målet är att bygga något bättre än din träningsdata — minne och team kan ge ett mervärde."

## Boss Mode — Lokalt på Mac

Boss Mode körs helt lokalt via CLI:er. Opus är piloten som aldrig lämnar cockpit — den planerar, delegerar och granskar men bygger aldrig själv.

### Teamet

| Agent | CLI-kommando | Roll |
|-------|-------------|------|
| **Opus (Boss)** | Kör i appen via `BossAgentService` | Pilot — PRE-FLIGHT, PLANNING, ASSEMBLY, POST-BUILD |
| **Claude (Sonnet)** | `claude --print "..." --model sonnet` | Bygger sida 1 |
| **Gemini** | `gemini "..." --sandbox false --yolo` | Research + bygger sida 2 |
| **Codex** | `codex exec "..." --full-auto` | Bygger sida 3 |

### Filstruktur i workspace

```
~/Apex/projects/boss-{timestamp}/
├── RESEARCH.md          ← Gemini skriver (steg 2)
├── CONTEXT.md           ← Boss skriver (steg 3) — design system, nav, footer
├── briefs/
│   ├── page-1.md        ← Uppdrag till Claude
│   ├── page-2.md        ← Uppdrag till Gemini
│   └── page-3.md        ← Uppdrag till Codex
├── pages/
│   ├── page-1.html      ← Claude levererar
│   ├── page-2.html      ← Gemini levererar
│   └── page-3.html      ← Codex levererar
└── index.html            ← Boss syr ihop (steg 5)
```

### Pilot Checklist (6 steg)

#### 1. PRE-FLIGHT (Opus ↔ user)
Opus frågar en fråga åt gången, väntar på svar:
1. **Brief understood** — Sammanfatta, fråga "Stämmer det?"
2. **Type** — Ensida eller flersida?
3. **Audience** — Vem är det för?
4. **Style direction** — Tre stilval
5. **Scope locked** — Sammanfatta allt, fråga "Redo?"

Hoppar över steg 2–4 om briefen redan svarar på dem.

#### 2. RESEARCH (Gemini)
```bash
gemini "Research for a website project. Company/topic: {BRIEF}. Find out:
1) What the company/topic is about
2) Target audience
3) Competitors and what their sites look like
4) Industry color conventions
5) Key content/copy that should be on the site.
Write a complete research report." --sandbox false --yolo > RESEARCH.md
```
Opus läser `RESEARCH.md`, visar 3-rads sammanfattning till user.

#### 3. PLANNING (Opus)
Opus läser `RESEARCH.md` och skapar:

**CONTEXT.md** — singel källa för design:
- Färgpalett (CSS-variabler)
- Typografi (Google Fonts)
- Spacing-system
- Delad CSS (:root block, reset, base styles)
- Navigation (samma på alla sidor)
- Footer (samma på alla sidor)
- Bildriktlinjer (Pexels-URLar, aldrig Unsplash)
- Sidlista med tilldelningar

**briefs/page-X.md** — ett per agent:
- Vilka sektioner att bygga
- Innehåll och copy
- Bildförslag
- Instruktion: "Läs CONTEXT.md för design system"
- Output: `pages/page-X.html`

Opus visar plan till user, frågar "Redo att bygga?"

#### 4. BUILD (3 agenter parallellt)
```bash
claude --print "$(cat briefs/page-1.md)" --output-format text \
  --dangerously-skip-permissions --model sonnet > pages/page-1.html &
gemini "$(cat briefs/page-2.md)" --sandbox false --yolo > pages/page-2.html &
codex exec "$(cat briefs/page-3.md)" --full-auto > pages/page-3.html &
wait
```
Alla tre läser `CONTEXT.md` + sin brief, bygger en komplett HTML-sida var.

#### 5. ASSEMBLY (Opus)
- Läser alla sidor i `pages/`
- Skapar `index.html` (landing page eller redirect)
- Fixar navigation mellan sidor
- Verifierar att alla sidor följer `CONTEXT.md`
- Fixar inkonsekvenser

#### 6. POST-BUILD (Opus)
- Self-review av all kod
- Rapport till user: filer, vem byggde vad, hur man previewar

### Kommunikation mellan agenter

Agenterna kör som one-shot-processer (ingen realtids-chat). Kommunikation sker via filer:

| Fil | Skribent | Läsare | Syfte |
|-----|---------|--------|-------|
| `RESEARCH.md` | Gemini | Opus | Research-underlag |
| `CONTEXT.md` | Opus | Claude, Gemini, Codex | Design system, regler |
| `briefs/page-X.md` | Opus | Respektive agent | Specifikt uppdrag |
| `pages/page-X.html` | Respektive agent | Opus | Leverans |

---

## Server Mode — API-baserat

Server-flödet kör via `POST /api/v1/projects` och använder Anthropic API direkt (inte CLI). Se `ARCHITECTURE.md` för detaljer.

---

## Testresultat: Landing Page (2025-01-30)

### Runda 1 — Initial design

**Gemini föreslog:** "Dark Mode Industrialism"
- Mörk bakgrund, neon-accenter, terminal-animation
- Pipeline-visualisering med steg

**Codex föreslog:** "Industrial Sci-fi + Developer Trust"
- Artifact-kort, stats-sektion, social proof
- Skarp CTA med teknisk trovärdighet

**Opus syntetiserade:**
- Tog Geminis mörka tema + terminal-animation
- Tog Codex CTA-copy + trovärdighetsignaler
- Byggde V1

### Runda 2 — Review

**Gemini föreslog 5 förbättringar:**
1. Aurora ambient lights (bakgrundseffekt)
2. Glassmorphism-paneler
3. Animerad pipeline-beam
4. Tech marquee-banner
5. Gradient-heading

**Codex föreslog 5 förbättringar:**
1. Floating artifact cards
2. Stats strip (3 nyckeltal)
3. Skarpare CTA-copy
4. Case study-sektion
5. Micro-interactions (hover, scroll)

**Opus integrerade alla 10** → V2

### Resultat
V2 var markant bättre än V1:
- Geminis visuella effekter (aurora, glassmorphism, beam) gav "wow-faktor"
- Codex UX-patterns (stats strip, case study, social proof) gav trovärdighet
- Kombinationen producerade en sida ingen enskild modell hade genererat

---

## Lärdomar

1. **Parallell delegering** — Fråga alla modeller samtidigt, spara tid
2. **Tydlig rollfördelning** — Gemini = visuellt, Codex = UX, Opus = syntes
3. **CONTEXT.md som kontrakt** — Alla agenter läser samma design-system → konsekvent output
4. **Iterativ review** — V2 >> V1 tack vare kritik från flera perspektiv
5. **Dokumenterade beslut** — Vet exakt varifrån varje designval kommer

## Förbättringsmöjligheter

1. **Röstning** — Låt modellerna rösta på varandras förslag
2. **Specialisering** — Fler modeller för specifika uppgifter (tillgänglighet, prestanda, SEO)
3. **Minne mellan sessioner** — Spara team-preferenser och mönster som fungerat
4. **Feedback-loop** — Agenter kan skriva till en `ISSUES.md` som Opus läser i ASSEMBLY
