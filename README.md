# FactGrid

AI-driven news platform that separates facts, opinions, and quotes into a
traceable grid with version history.

## Vision
FactGrid reduces clickbait and bias by breaking complex stories into atomic,
verifiable data points. AI acts as an objective judge, and every change is
traceable (who, why, and which source).

## Core Principles
- Strict separation: facts, opinions, and quotes never mix.
- Transparency (git-like): each update is traceable with commit-like history.
- Agent-based verification: when disputed, agents can search primary sources.

## Architecture
- **The Scout**: NewsAPI ingest into raw JSON.
- **The Judge**: OpenAI GPT-4o-mini returns strict JSON grid + confidence.
- **Git-Lite**: MongoDB versioning with history array.
- **The Agent**: RAG-based verification loop (planned).

## Tech Stack
- Python 3.11+
- FastAPI
- MongoDB
- OpenAI GPT-4o-mini
- Railway (deployment)

## API Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/ingest` | Fetch news from NewsAPI |
| POST | `/judge` | Fetch + judge + store |
| POST | `/pipeline` | Full pipeline |
| GET | `/articles` | List all articles |
| GET | `/articles/{id}` | Get specific article |
| GET | `/articles/{id}/history` | Get version history |

## Data Model (MongoDB)
Each article is identified by a hash of URL/title/source and stored with a
current state plus history entries:
```json
{
  "_id": "...",
  "article_metadata": {
    "original_url": "https://...",
    "title": "...",
    "source": "...",
    "topic": "business",
    "initial_timestamp": "2026-01-07T12:00:00Z"
  },
  "current_state": {
    "version": 2,
    "last_updated": "2026-01-07T15:30:00Z",
    "grid": [ ... ]
  },
  "history": [
    {
      "version": 1,
      "commit_msg": "Initial AI analysis",
      "diff": "Added initial 5 rows",
      "logic": "Judged from NewsAPI payload.",
      "timestamp": "2026-01-07T12:00:00Z"
    }
  ]
}
```

## Local Setup
1) Create `.env` from `.env.example`:
```bash
cp .env.example .env
```

2) Add your API keys:
```
NEWSAPI_KEY=your_key_here
OPENAI_API_KEY=your_key_here
```

3) Create virtual environment and install dependencies:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

4) Ensure MongoDB is running (default `mongodb://localhost:27017`).

5) Run the API:
```bash
uvicorn factgrid.api:app --reload
```

## CLI Commands
Fetch top headlines:
```bash
python -m factgrid.ingest_newsapi --pretty
```

Judge raw payload into grid JSON:
```bash
python -m factgrid.judge --input data/raw/newsapi_YYYYmmdd_HHMMSS.json --pretty
```

Store judged payload in MongoDB:
```bash
python -m factgrid.store_judged_mongo --input data/raw/judged_newsapi.json
```

## Railway Deployment
```bash
railway login
railway init --name factgrid
# Add environment variables in Railway dashboard
railway up
```

## Environment Variables
See `.env.example` for all configuration options.
