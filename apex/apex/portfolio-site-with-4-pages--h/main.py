from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

app = FastAPI()

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

# API ENDPOINTS:
# GET /          - Home page
# GET /about     - About page
# GET /projects  - Projects page
# GET /contact   - Contact page

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    """
    Serve the Home page.
    """
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/about", response_class=HTMLResponse)
async def read_about(request: Request):
    """
    Serve the About page.
    """
    return templates.TemplateResponse("about.html", {"request": request})

@app.get("/projects", response_class=HTMLResponse)
async def read_projects(request: Request):
    """
    Serve the Projects page.
    """
    return templates.TemplateResponse("projects.html", {"request": request})

@app.get("/contact", response_class=HTMLResponse)
async def read_contact(request: Request):
    """
    Serve the Contact page.
    """
    return templates.TemplateResponse("contact.html", {"request": request})
