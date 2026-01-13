# Styrdokument: FactGrid

**Version:** 1.1
**Status:** PoC-fas
**Koncept:** AI-driven nyhetsplattform for objektiv faktaseparation via versionshanterad grid-struktur.

## 1. Vision & Syfte
FactGrid ska losa problemet med "klickbeten" och politisk vinkling i media genom att bryta ner komplexa nyhetshändelser till atomära, verifierbara datapunkter. Genom att använda AI som en objektiv "domare" separeras fakta från åsikter i en tabellstruktur som är fullt spårbar och transparent.

**Kärnprinciper:**
- Strikt Separation: Fakta, åsikter och citat får aldrig blandas.
- Transparens (Git-logik): Varje ändring i informationen ska kunna spåras bakåt (Vem ändrade? Varför? Vilken källa användes?).
- Agent-baserad Verifiering: Vid osäkerhet eller felanmälan aktiveras AI-agenter för att söka i primärkällor.

## 2. Systemarkitektur & Komponenter
### A. Data Ingest (The Scout)
Hämtar rådata från nyhets-API:er.
- Primära källor: NewsAPI, The Guardian, Reuters API.
- Lagring: Rå JSON lagras i MongoDB för framtida spårbarhet.

### B. AI-Domaren (The Judge)
OpenAI GPT-4o-mini med en specifik "objektivitets-konstitution".
- Uppgift: Extrahera påståenden, kategorisera dem och tilldela ett "konfidensvärde".

### C. Ledger & Versionshantering (Git-Lite)
Implementeras i MongoDB för att hantera dokumentets livscykel.
- Schema-modell: Varje artikel är ett dokument med en history-array innehållande commits.

### D. Verifierings-loop (The Agent)
En RAG-baserad (Retrieval-Augmented Generation) loop.
- Verktyg: Tavily AI eller Serper för att nå statliga databaser och lagtexter.

## 3. Teknisk Stack
| Lager | Teknik | Motivering |
|---|---|---|
| Programspråk | Python 3.11+ | Standard för AI och databehandling. |
| Backend | FastAPI | Modern, snabb REST API. |
| Databas | MongoDB | Flexibel JSON-hantering och enkel versionsloggning. |
| AI-Modell | OpenAI GPT-4o-mini | Kostnadseffektiv med bra prestanda. |
| Sök-API | Tavily AI | Optimerat för att ge fakta till AI-modeller. |
| Deployment | Railway | Enkel deployment med automatisk skalning. |

## 4. Datamodell (MongoDB-struktur)
```json
{
  "article_metadata": {
    "original_url": "https://...",
    "topic": "business",
    "initial_timestamp": "2026-01-07T12:00:00Z"
  },
  "current_state": {
    "version": 4,
    "last_updated": "2026-01-07T15:30:00Z",
    "grid": [
      {
        "id": "row_1",
        "type": "FACT",
        "content": "Blockbidraget är 3,9 miljarder DKK",
        "source": "Danska Finansministeriet",
        "status": "VERIFIED"
      }
    ]
  },
  "history": [
    {
      "version": 1,
      "commit_msg": "Initial AI-analys",
      "diff": "Added initial 5 rows",
      "logic": "Extraherat från Bloomberg-artikel."
    }
  ]
}
```

## 5. Roadmap: Från PoC till MVP
### Fas 1: "The Core"
- [x] Sätta upp MongoDB-anslutning.
- [x] Skapa "Domar-prompten" som returnerar strikt JSON.
- [x] Bygga Ingest-script för topp 10 nyheter.
- [x] Implementera OpenAI judge-provider.
- [x] Skapa FastAPI backend.
- [x] Railway deployment-konfiguration.

### Fas 2: "The Git Logic"
- [x] Implementera historik-loggning i Mongo.
- [ ] Skapa en "Diff-funktion" (Visa vad som ändrats mellan v1 och v2).
- [ ] Bygga frontend för tabellen.

### Fas 3: "The Agent"
- [ ] Integrera Tavily för automatisk faktakontroll.
- [ ] Skapa "Anmäl fel"-knapp som triggar en ny commit.

## 6. Riskanalys & Kritikhantering
- Risk: AI-hallucinationer.
  - Lösning: Kräva källhänvisning för varje cell i "Fakta"-kolumnen. Om källa saknas flyttas raden till "Obekräftat".
- Risk: Juridiska krav från mediehus.
  - Lösning: Publicera aldrig artiklar i sin helhet. Visa endast atomära fakta och korta citat med tydlig länkning till originalet (Transformativt bruk).

## 7. API Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Hälsokontroll |
| POST | `/ingest` | Hämta nyheter från NewsAPI |
| POST | `/judge` | Hämta + bedöm + lagra |
| POST | `/pipeline` | Full pipeline |
| GET | `/articles` | Lista artiklar |
| GET | `/articles/{id}` | Hämta specifik artikel |
| GET | `/articles/{id}/history` | Visa versionshistorik |
