# Sprint Backlog - Kontaktbok App

## Sprint 1: Core Setup
| Feature | Done when... |
|---------|--------------|
| Project structure | main.py, database.py, models.py exist |
| PostgreSQL connection | Can connect to database with psycopg2 |
| Database schema | contacts table with id, name, email, phone, created_at |
| Base template | index.html renders with header "Kontaktbok" |

## Sprint 2: Add Contact
| Feature | Done when... |
|---------|--------------|
| Add form | Form with name, email, phone fields + button |
| POST /contacts | Creates contact, returns 201 |
| Validation | Name is required, email format validated |
| Success feedback | User sees confirmation after adding |

## Sprint 3: View/List Contacts
| Feature | Done when... |
|---------|--------------|
| GET /contacts | Returns list of all contacts |
| Contact list UI | Shows all contacts in a clean list/table |
| Contact details | Each contact shows name, email, phone |
| Empty state | Friendly message when no contacts exist |

## Sprint 4: Search Contacts
| Feature | Done when... |
|---------|--------------|
| Search input | Search field visible at top |
| GET /contacts?q=query | Filters contacts by name, email, or phone |
| Live results | Results update as user types (or on submit) |
| No results state | "No contacts found" message |

## Sprint 5: Delete Contact
| Feature | Done when... |
|---------|--------------|
| Delete button | Each contact has delete button/icon |
| DELETE /contacts/{id} | Removes contact from database |
| Confirmation | "Are you sure?" prompt before delete |
| UI update | Contact removed from list after delete |

## Out of Scope
- User authentication
- Edit/update contact
- Contact categories/groups
- Import/export contacts
- Profile pictures
