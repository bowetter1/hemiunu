# Expense Tracker - Sprint Backlog

## Project Vision
A web-based expense tracker with PostgreSQL backend, designed for Railway deployment. Users can track expenses by category, view summaries, and manage their spending.

---

## Sprint 1: Core Setup
| Feature | Done when... |
|---------|--------------|
| Project structure | main.py, database.py, models.py exist |
| Database connection | PostgreSQL connection with SQLAlchemy works |
| Base template | index.html renders with basic styling |
| Health endpoint | GET /health returns 200 OK |

---

## Sprint 2: Add Expense
| Feature | Done when... |
|---------|--------------|
| Add expense form | Form with amount, description, category, date fields |
| POST /expenses | Creates expense in database, returns 201 |
| Category dropdown | Predefined categories: Food, Transport, Entertainment, Bills, Shopping, Other |
| Form validation | Amount required, positive number only |

---

## Sprint 3: View Expenses
| Feature | Done when... |
|---------|--------------|
| Expense list | All expenses displayed in a table |
| GET /expenses | Returns all expenses as JSON |
| Sorting | Most recent expenses shown first |
| Category badge | Each expense shows its category with color |

---

## Sprint 4: Delete Expense
| Feature | Done when... |
|---------|--------------|
| Delete button | Each expense row has delete button |
| DELETE /expenses/{id} | Removes expense from database |
| Confirmation | Browser confirm() before delete |
| UI update | Expense disappears from list after delete |

---

## Sprint 5: Expense Summary
| Feature | Done when... |
|---------|--------------|
| Total display | Shows total of all expenses |
| Category breakdown | Shows spending per category |
| GET /expenses/summary | Returns totals by category |
| Visual chart | Simple bar or pie chart showing category distribution |

---

## Out of Scope
- User authentication/accounts
- Multiple currencies
- Receipt image upload
- Export to CSV/PDF
- Budget limits/alerts
- Date range filtering (future enhancement)

---

## Technical Requirements
- **Backend**: FastAPI + SQLAlchemy
- **Database**: PostgreSQL (Railway provisioned)
- **Frontend**: Jinja2 templates + vanilla JS
- **Styling**: CSS (clean, modern look)
- **Deploy**: Railway with PostgreSQL addon
