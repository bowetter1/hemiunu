# Project Plan

## Config
- **DATABASE**: sqlite
- **FRAMEWORK**: fastapi

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app, all API endpoints |
| database.py | SQLite connection and table setup |
| templates/index.html | Single-page UI |
| static/js/main.js | JavaScript for CRUD operations |
| static/css/style.css | Basic styling |

## Features (Sprint 1)
1. SQLite database with todos table
2. Add todo (POST /todos)
3. List all todos (GET /todos)
4. Toggle complete status (PUT /todos/{id})
5. Delete todo (DELETE /todos/{id})
6. Single-page UI with form and todo list

## Database Schema

### Table: todos
| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY AUTOINCREMENT |
| title | TEXT | NOT NULL |
| completed | INTEGER | DEFAULT 0 (0=false, 1=true) |

## API Contract

### GET /todos
Returns all todos.

Response 200:
```json
[
  {
    "id": 1,
    "title": "Buy groceries",
    "completed": false
  }
]
```

### POST /todos
Creates a new todo.

Request:
```json
{
  "title": "Buy groceries"
}
```
- title: string (required, non-empty)

Response 201:
```json
{
  "id": 1,
  "title": "Buy groceries",
  "completed": false
}
```

### PUT /todos/{id}
Toggles the completed status of a todo.

Path parameters:
- id: integer (required)

Response 200:
```json
{
  "id": 1,
  "title": "Buy groceries",
  "completed": true
}
```

Response 404:
```json
{
  "detail": "Todo not found"
}
```

### DELETE /todos/{id}
Deletes a todo.

Path parameters:
- id: integer (required)

Response 200:
```json
{
  "message": "Todo deleted"
}
```

Response 404:
```json
{
  "detail": "Todo not found"
}
```

## Environment Variables
- PORT (set by Railway, default 8000 for local dev)

## Tech Notes
- SQLite file stored as `todos.db` in project root
- FastAPI serves static files from `/static` and templates from `/templates`
- Use Jinja2Templates for index.html
- CORS not needed (same origin)
- SQLite uses INTEGER 0/1 for boolean, convert to Python bool in response
