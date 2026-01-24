# Apex macOS - Interaktiv AI Design App

## Vision

Ett nytt sätt att jobba med AI - inte chat, utan **interaktiva objekt**. Som att gå till en reklambyrå, fast AI:n är byrån.

---

## Flöde

```
Brief → Moodboard → Tre layouts → Välj → Iterera/Exportera/Deploy
```

---

## Steg 1: Brief

Användaren beskriver sin idé i fritext.

```
┌─────────────────────────────────────────────────┐
│  Beskriv din idé                                │
│  ┌─────────────────────────────────────────┐   │
│  │ "En app för att boka padel med vänner,  │   │
│  │  ska kännas premium men lekfull"        │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  [Skapa moodboard →]                           │
└─────────────────────────────────────────────────┘
```

---

## Steg 2: Moodboard

Opus svarar med **visuell data**, inte text. Appen renderar det interaktivt.

```
┌─────────────────────────────────────────────────────────┐
│  MOODBOARD                                              │
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐               │
│  │ 🎨       │ │ Aa       │ │ ✨       │               │
│  │ Palette  │ │ Typsnitt │ │ Mood     │               │
│  ├──────────┤ ├──────────┤ ├──────────┤               │
│  │ ■ #1A1A2E│ │ SF Pro   │ │ Energisk │               │
│  │ ■ #16213E│ │ Display  │ │ Modern   │               │
│  │ ■ #0F3460│ │          │ │ Social   │               │
│  │ ■ #E94560│ │ Inter    │ │          │               │
│  └──────────┘ └──────────┘ └──────────┘               │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ "Tänker mörkt tema med en accent som poppar.    │   │
│  │  Premium genom typografi, lekfullt genom        │   │
│  │  micro-animationer och färgkontrast."           │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [ 👍 Kör på ]  [ 🔄 Annat förslag ]  [ ✏️ Justera ]  │
└─────────────────────────────────────────────────────────┘
```

### Interaktioner
- Klicka på färg → visa alternativ
- Dra bort typsnitt → Opus föreslår nytt
- Skriv "mer retro" → uppdaterar moodboard

### Datamodell

```swift
struct Moodboard {
    let palette: [Color]
    let fonts: [FontSuggestion]
    let keywords: [String]
    let rationale: String
}
```

---

## Steg 3: Tre Layouts

Opus genererar **tre olika HTML-layouts** med samma moodboard. Live-renderade i WebViews.

```
┌─────────────────────────────────────────────────────────┐
│  TRE ALTERNATIV                                        │
│                                                         │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│  │ ┌─────────┐ │ │ ┌──┐ ┌────┐│ │   PADEL+    │       │
│  │ │  HERO   │ │ │ │  │ │    ││ │ ┌─────────┐ │       │
│  │ │ center  │ │ │ │  │ │hero││ │ │  grid   │ │       │
│  │ └─────────┘ │ │ │  │ └────┘│ │ │  cards  │ │       │
│  │ ┌──┐┌──┐┌──┐│ │ │  │ ┌────┐│ │ └─────────┘ │       │
│  │ └──┘└──┘└──┘│ │ └──┘ └────┘│ │             │       │
│  │   A: Stack  │ │  B: Sidebar │ │  C: Cards   │       │
│  └─────────────┘ └─────────────┘ └─────────────┘       │
│                                                         │
│  [ Välj A ]    [ Välj B ]    [ Välj C ]    [ Mixa ]   │
└─────────────────────────────────────────────────────────┘
```

### Datamodell

```swift
struct LayoutAlternative {
    let id: String
    let name: String           // "Stack", "Sidebar", "Cards"
    let description: String
    let html: String           // Fullständig HTML/CSS
}
```

---

## Steg 4: Interaktiv Editor

Här blir det en **riktig editor**, inte chat. Direkt manipulation.

```
┌─────────────────────────────────────────────────────────────────┐
│  ┌─────┐                                                        │
│  │ 🏠  │ ← Aktiv sida                                          │
│  ├─────┤                                                        │
│  │ 📄  │ Om oss                                                 │
│  ├─────┤                                                        │
│  │ 📄  │ Kontakt                                                │
│  ├─────┤                                                        │
│  │ ＋  │ ← Klick → ny sida direkt                              │
│  └─────┘                                                        │
│         ┌───────────────────────────────────────────────────┐  │
│         │                                                   │  │
│         │              LIVE PREVIEW                         │  │
│         │                                                   │  │
│         │   ┌─────────────────────────────────────────┐    │  │
│         │   │ ● Klickbar                              │    │  │
│         │   │   Välj element → edit panel öppnas     │    │  │
│         │   └─────────────────────────────────────────┘    │  │
│         │                                                   │  │
│         └───────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌────────────────────────────────────────────────────────────┐│
│  │ "Lägg till en hero med bild"                    [↵ Enter] ││
│  └────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                       │
│  │ 📦 Export│ │ 🚀 Deploy│ │ 💾 Spara │                       │
│  └──────────┘ └──────────┘ └──────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

### Interaktioner

| Handling | Resultat |
|----------|----------|
| Klick på `+` | Opus skapar ny sida i samma stil |
| Klick på element | Markeras, edit-panel visas |
| Dra element | Flytta position |
| Skriv i command bar | Opus ändrar/lägger till |
| Högerklick | "Ta bort", "Duplicera", "Edit HTML" |
| `⌘S` | Sparar projekt |
| `⌘E` | Exportera |

### Ny sida dialog

```
┌─────────────────────────────┐
│  Ny sida                    │
│                             │
│  Namn: [Priser         ]   │
│                             │
│  Typ:                       │
│  ○ Blank (tom)             │
│  ● Generera (Opus skapar)  │
│                             │
│  [Skapa]                    │
└─────────────────────────────┘
```

### Element edit-panel

```
┌─────────────────────────────┐
│  Button                     │
│  ─────────────────────────  │
│  Text:  [Boka nu      ]    │
│  Färg:  ■ #E94560  [🎨]    │
│  Radius: ●───────○  12px   │
│  ─────────────────────────  │
│  [Visa HTML] [Ta bort]     │
└─────────────────────────────┘
```

### Funktioner

**4A: Tweaka**
- Klicka på element → redigera
- "Gör knappen rund"
- Dra färger, justera spacing
- Opus uppdaterar HTML i realtid

**4B: Fler sidor**
- Klicka `+` → ny sida
- "Skapa en Om oss-sida i samma stil"
- Opus genererar, samma moodboard

**4C: Exportera**
- Ladda ner HTML/CSS/JS
- Alternativ: React-komponenter, Next.js-projekt

**4D: Deploy**
- Ett klick → live på nätet
- Vercel / Netlify / egen lösning

---

## Varför Native macOS?

| Feature | Webb-chat | macOS-app |
|---------|-----------|-----------|
| Färger | Text `#E94560` | ■ Klickbar ruta |
| Layouts | Beskriv i ord | Renderad WebView |
| Redigera | "Ändra till 20px" | Slider/drag |
| Jämföra | Scrolla upp/ner | Sida vid sida |
| Interaktion | Copy/paste | Drag & drop |
| Animationer | ❌ | ✅ Native |
| Systemintegration | ❌ | Finder, menyer, shortcuts |

**AI-svar blir interaktiva objekt istället för text att läsa.**

---

## Tekniskt

### API-access

Användare måste använda egen Anthropic API-nyckel. OAuth med Pro/Max-konton är blockerat av Anthropic för tredjepartsappar.

```swift
enum APIMode {
    case ownKey(String)
    case apexServer
}
```

### När använda screenshots vs struktur?

| Situation | Metod |
|-----------|-------|
| "Ser det bra ut?" | Screenshot → Vision |
| Användaren ritar/skissar | Screenshot → Vision |
| "Gör knappen större" | JSON/struktur |
| Färgändringar, text, positioner | JSON/struktur |

### Datamodeller

```swift
struct Project {
    let id: String
    let name: String
    let moodboard: Moodboard
    var pages: [Page]
}

struct Page {
    let id: String
    var name: String
    var html: String
}

enum ProjectPhase {
    case brief
    case moodboard
    case layouts
    case editing
}
```

---

## Sammanfattning

1. **Brief** - Användaren beskriver idé
2. **Moodboard** - Opus svarar visuellt (färger, typsnitt, mood)
3. **Tre layouts** - Live HTML att välja mellan
4. **Editor** - Interaktiv redigering, fler sidor, export, deploy

**Känslan:** Figma möter AI. Du pekar och beskriver - Opus bygger.
