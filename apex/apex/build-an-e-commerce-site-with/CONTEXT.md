# PROJECT CONTEXT

## Vision
Building a modern e-commerce site with dark theme. Users can browse products, search/filter, add to cart, and checkout with mock payment. Session-based cart management, inventory tracking, and responsive design.

## Sprint Goals
- Sprint 1: Core setup + product catalog display
- Sprint 2: Search and filter functionality
- Sprint 3: Shopping cart with session management
- Sprint 4: Checkout flow + inventory management

## NEEDS (blockers)
| From | Need | From who | Status |
|------|------|----------|--------|

## Environment (DevOps)
- python: 3.14.2
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- sqlalchemy: 2.0.23
- httpx: 0.27.0
- deploy: Railway (Dockerfile, railway.toml, Procfile ready)
- database: SQLite (simple, no external service needed)
- status: ✅ OK

## Tech Stack (Architect)
- framework: fastapi
- db: sqlite (per DevOps environment)
- orm: sqlalchemy
- templates: jinja2
- session: cookie-based UUID
- See PLAN.md for full architecture

## Design System (AD)
- primary: #6366f1 (Indigo 500)
- accent: #38bdf8 (Sky 400)
- background: #0f172a (Slate 900)
- surface: #1e293b (Slate 800)
- text: #f8fafc (Slate 50)
- font: 'Inter', sans-serif
- spacing: 4px base
- **Sprint 2:** Added Search/Filter component specs
- See DESIGN.md for full details

## API Endpoints (Backend)
- GET /products?search=&category=&sort= → List products with filtering (JSON). Returns {products: [], total: int, filters: {}}
- GET /categories → List distinct categories (JSON). Returns {categories: []}
- GET /products/{id} → Get single product details (JSON)
- GET / → Homepage (serves templates/index.html)
- GET /product/{id} → Product detail page (serves templates/product.html)
- See main.py for full API

## Frontend (Frontend)
- pages: templates/index.html, templates/product.html, templates/base.html
- scripts: static/js/app.js
- styles: static/css/style.css
- features: Sprint 1 UI (Home, Product Detail, Dark Theme)

