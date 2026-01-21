# Enhetsomvandlare (Unit Converter)

A simple, fast unit converter for length, weight, and temperature.

**Live Demo:** https://enhetsomvandlare-production.up.railway.app

## Features

- **Length**: Convert between meters and feet
- **Weight**: Convert between kilograms and pounds
- **Temperature**: Convert between Celsius and Fahrenheit
- Instant results (no page reload)
- Mobile-responsive dark theme design

## Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Start server
uvicorn main:app --reload

# Open http://localhost:8000
```

## API

```bash
# Length conversion
curl -X POST http://localhost:8000/convert/length \
  -H "Content-Type: application/json" \
  -d '{"value": 10, "direction": "m_to_ft"}'

# Weight conversion
curl -X POST http://localhost:8000/convert/weight \
  -H "Content-Type: application/json" \
  -d '{"value": 5, "direction": "kg_to_lbs"}'

# Temperature conversion
curl -X POST http://localhost:8000/convert/temperature \
  -H "Content-Type: application/json" \
  -d '{"value": 100, "direction": "c_to_f"}'
```

## Tech Stack

- FastAPI (Python)
- Vanilla JavaScript
- Jinja2 templates
- Railway (hosting)

## Tests

```bash
pytest
```
