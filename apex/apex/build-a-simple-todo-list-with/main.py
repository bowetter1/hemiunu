from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from typing import List, Optional
import database
import os

# Initialize database
database.init_db()

app = FastAPI()

# Mount static files
# Ensure the directory exists to avoid errors on startup if empty
if not os.path.exists("static"):
    os.makedirs("static")
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
if not os.path.exists("templates"):
    os.makedirs("templates")
templates = Jinja2Templates(directory="templates")

# Pydantic Models
class TodoCreate(BaseModel):
    title: str

class TodoResponse(BaseModel):
    id: int
    title: str
    completed: bool

# API ENDPOINTS:
# GET  /todos         - list all
# POST /todos         - create (body: {title})
# PUT  /todos/<id>    - toggle completed status
# DELETE /todos/<id>  - delete

@app.get("/", include_in_schema=False)
def serve_frontend(request: Request):
    # This expects index.html to exist in templates/
    # If it doesn't exist yet, we can return a placeholder or let it error 
    # (Frontend dev will add it). 
    # For now, we assume Frontend will provide it.
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/todos", response_model=List[TodoResponse])
def read_todos():
    todos = database.get_all_todos()
    # SQLite returns 0/1 for completed, Pydantic handles coercion to bool
    return todos

@app.post("/todos", response_model=TodoResponse, status_code=201)
def create_todo(todo: TodoCreate):
    if not todo.title.strip():
        raise HTTPException(status_code=400, detail="Title cannot be empty")
    new_todo = database.create_todo(todo.title)
    return new_todo

@app.put("/todos/{todo_id}", response_model=TodoResponse)
def update_todo(todo_id: int):
    updated_todo = database.toggle_todo_complete(todo_id)
    if updated_todo is None:
        raise HTTPException(status_code=404, detail="Todo not found")
    return updated_todo

@app.delete("/todos/{todo_id}")
def delete_todo(todo_id: int):
    success = database.delete_todo(todo_id)
    if not success:
        raise HTTPException(status_code=404, detail="Todo not found")
    return {"message": "Todo deleted"}
