# Portfolio Site

Modern dark-themed portfolio website with 4 pages.

## Live Demo

https://portfolio-site-with-4-pages-h-production.up.railway.app

## Features

- **Home** - Hero section with introduction
- **About** - Bio, skills, and profile information
- **Projects** - Portfolio grid showcasing work
- **Contact** - Contact form (frontend only)
- **Dark Theme** - Modern deep navy + neon mint color scheme
- **Responsive** - Works on mobile and desktop

## Tech Stack

- FastAPI (Python)
- Jinja2 Templates
- Vanilla CSS (no frameworks)
- Vanilla JavaScript (mobile nav)

## Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Start server
uvicorn main:app --reload

# Open http://localhost:8000
```

## Deploy to Railway

```bash
railway up
```

## Project Structure

```
.
├── main.py              # FastAPI routes
├── templates/
│   ├── base.html        # Base template with nav/footer
│   ├── index.html       # Home page
│   ├── about.html       # About page
│   ├── projects.html    # Projects page
│   └── contact.html     # Contact page
├── static/
│   ├── css/
│   │   └── styles.css   # Dark theme styles
│   └── js/
│       └── main.js      # Mobile nav toggle
├── tests/
│   └── test_main.py     # 22 passing tests
├── requirements.txt
├── Dockerfile
├── railway.toml
└── Procfile
```
