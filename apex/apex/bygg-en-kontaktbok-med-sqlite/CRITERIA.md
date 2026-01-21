# Kontaktbok - Sprint Backlog

## Sprint 1: Core Setup + View Contacts
| Feature | Done when... |
|---------|--------------|
| Project structure | main.py, database.py, models.py exist |
| SQLite database | contacts table with name, phone, email, notes |
| View all contacts | GET /contacts returns list, index.html shows table |
| Add contact form | POST /contacts creates contact, form visible on page |

## Sprint 2: Search + Edit
| Feature | Done when... |
|---------|--------------|
| Search contacts | GET /contacts?q=term filters by name/phone/email |
| Search UI | Search input field, results update on search |
| Edit contact | GET /contacts/{id} returns contact, PUT updates it |
| Edit UI | Click contact to edit, form pre-fills, save updates |

## Sprint 3: Delete + Polish
| Feature | Done when... |
|---------|--------------|
| Delete contact | DELETE /contacts/{id} removes contact |
| Delete UI | Delete button on each contact, confirmation dialog |
| Empty state | Shows "No contacts yet" when list empty |
| Validation | Required fields validated, error messages shown |

## Data Model
```
Contact:
- id: integer (primary key, auto)
- name: string (required)
- phone: string (optional)
- email: string (optional)
- notes: text (optional)
- created_at: datetime
- updated_at: datetime
```

## Out of Scope
- User authentication
- Import/export contacts
- Contact groups/categories
- Profile pictures
