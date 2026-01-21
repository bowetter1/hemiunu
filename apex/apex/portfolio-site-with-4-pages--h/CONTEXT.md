# PROJECT CONTEXT

## Vision
Build a modern portfolio website with 4 pages (Home, About, Projects, Contact) featuring a sleek dark theme. No database needed - this is a static-content site served by FastAPI.

## Sprint Goals
- Create responsive, modern dark-themed portfolio site
- 4 pages: Home, About, Projects, Contact
- Clean navigation between pages
- Professional design suitable for showcasing work

## NEEDS (blockers)
| From | Need | From who | Status |
|------|------|----------|--------|

## Environment (DevOps)
- python: 3.14.2
- pytest: 8.0.0
- fastapi: 0.109.0
- uvicorn: 0.27.0
- jinja2: 3.1.2
- deploy: Railway (Dockerfile, railway.toml, Procfile ready)
- status: ✅ OK

## Tech Stack (Architect)
- framework: fastapi
- db: none
- templating: jinja2
## Design System (AD)
- primary: #64FFDA (Neon Mint)
- background: #0A192F (Deep Navy)
- surface: #112240 (Lighter Navy)
- text: #8892B0 (Slate Blue-Grey)
- font: 'Inter', sans-serif
- spacing: 4px base
- See DESIGN.md for full details

## API Endpoints (Backend)
- GET / → Home page (index.html)
- GET /about → About page (about.html)
- GET /projects → Projects page (projects.html)
- GET /contact → Contact page (contact.html)
- See main.py for full API

## Frontend
- pages: templates/base.html, templates/index.html, templates/about.html, templates/projects.html, templates/contact.html
- scripts: static/js/main.js
- styles: static/css/style.css
- features:
    - Modern dark theme with Neon Mint accents
    - Responsive mobile-first design with Lucide icons
    - Glassmorphism sticky navbar
    - Animated project cards
    - Functional contact form (visual/alert only)
    - Google Fonts integration (Inter & Fira Code)

## Security
- audit: VULNERABILITIES_FOUND (Medium)
- findings: Missing security headers, outdated Jinja2 (3.1.2)
- status: See SECURITY_AUDIT.md for details
