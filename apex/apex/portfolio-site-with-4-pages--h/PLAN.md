# Project Plan

## Config
- **DATABASE**: none
- **FRAMEWORK**: fastapi

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app with routes for all 4 pages |
| templates/base.html | Base template with nav, dark theme, footer |
| templates/index.html | Home page - hero section, intro |
| templates/about.html | About page - bio, skills |
| templates/projects.html | Projects page - portfolio grid |
| templates/contact.html | Contact page - contact form |
| static/css/style.css | Dark theme styles, responsive design |
| static/js/main.js | Mobile nav toggle, form interactions |

## Features
1. FastAPI serving Jinja2 templates
2. Static file serving for CSS/JS
3. 4 pages with consistent dark theme
4. Responsive mobile-first design
5. Contact form (visual only, no backend processing)

## Routes

### GET /
Home page with hero section and introduction.

Response: HTML (templates/index.html)

### GET /about
About page with bio and skills.

Response: HTML (templates/about.html)

### GET /projects
Projects page with portfolio grid.

Response: HTML (templates/projects.html)

### GET /contact
Contact page with contact form.

Response: HTML (templates/contact.html)

## Environment Variables
- PORT (set by Railway automatically)

## Technical Notes
- Use `Jinja2Templates` from fastapi.templating
- Use `StaticFiles` from fastapi.staticfiles to serve static/
- All pages extend base.html for consistent nav/footer
- Contact form is frontend-only (no email sending per CRITERIA.md)
