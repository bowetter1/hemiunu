# Sprint Backlog - Simple Todo List with SQLite

## Sprint 1: Core Setup + CRUD
| Feature | Done when... |
|---------|--------------|
| Project structure | main.py, database.py exist, server starts |
| SQLite database | todos table created with id, title, completed fields |
| Add todo | POST /todos creates a new todo, returns 201 |
| List todos | GET /todos returns all todos as JSON |
| Complete todo | PUT /todos/{id} toggles completed status |
| Delete todo | DELETE /todos/{id} removes the todo |
| UI | Single page with form to add, list of todos, complete/delete buttons |

## Out of Scope
- User authentication
- Due dates
- Categories/tags
- Priorities
- Search/filter
- Multiple lists
