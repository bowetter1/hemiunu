# Kontaktbok med SQLite

En modern kontaktbok-applikation byggd med FastAPI och SQLite.

## Live Demo

**https://kontaktbok-sqlite-production.up.railway.app**

## Funktioner

- **Lägg till kontakter** - Namn, telefon, email och anteckningar
- **Visa alla kontakter** - Snygg lista med alla dina kontakter
- **Sök kontakter** - Sök på namn, telefon eller email
- **Redigera kontakter** - Uppdatera kontaktinformation
- **Ta bort kontakter** - Med bekräftelse-dialog

## Tech Stack

- **Backend:** FastAPI, SQLAlchemy, SQLite
- **Frontend:** Jinja2 Templates, Vanilla JS, CSS
- **Deploy:** Railway

## Kör lokalt

```bash
# Installera dependencies
pip install -r requirements.txt

# Starta servern
uvicorn main:app --reload

# Öppna http://localhost:8000
```

## API Endpoints

| Metod | Endpoint | Beskrivning |
|-------|----------|-------------|
| GET | / | Serverar frontend |
| GET | /contacts | Lista alla kontakter |
| GET | /contacts?q=sök | Sök kontakter |
| POST | /contacts | Skapa ny kontakt |
| GET | /contacts/{id} | Hämta en kontakt |
| PUT | /contacts/{id} | Uppdatera kontakt |
| DELETE | /contacts/{id} | Ta bort kontakt |

## Tester

```bash
pytest tests/ -v
```

11 tester för alla API endpoints.

## Projektstruktur

```
├── main.py           # FastAPI app och endpoints
├── database.py       # SQLite anslutning
├── models.py         # SQLAlchemy modeller
├── templates/
│   └── index.html    # Frontend HTML
├── static/
│   ├── css/style.css # Styling
│   └── js/main.js    # JavaScript
├── tests/
│   ├── conftest.py   # Test fixtures
│   └── test_api.py   # API tester
└── requirements.txt  # Dependencies
```
