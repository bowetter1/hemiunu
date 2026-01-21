# PROJECT CONTEXT

## Environment (DevOps)
- python: 3.14.2 (use `python3` command)
- pytest: 9.0.2
- fastapi: 0.109.0
- uvicorn: 0.27.0
- httpx: 0.27.0
- sqlalchemy: 2.0.23
- psycopg2-binary: 2.9.11
- railway-cli: 4.23.0
- status: OK

## Tech Stack (Architect)
- framework: fastapi
- db: postgres
- orm: sqlalchemy
- templates: jinja2
- See PLAN.md for details

## Design System (AD)
- primary: #0D9488 (teal)
- background: #0F172A (dark slate)
- surface: #1E293B (card backgrounds)
- text: #F1F5F9 (light gray)
- danger: #EF4444 (red for expenses)
- font: Inter (body), JetBrains Mono (numbers)
- spacing-base: 4px
- radius: 8px buttons, 12px cards
- See DESIGN.md for full details

### Sprint 2: Add Expense Form
- Form in card container (max-width: 480px)
- Fields: Amount (mono font, right-aligned), Description, Category dropdown, Date
- Category icons: 🍔 Food, 🚗 Transport, 🎬 Entertainment, 📄 Bills, 🛒 Shopping, 📦 Other
- Validation: red border + error message below field
- Success: green toast notification (bottom-right)
- Submit button: full-width, loading spinner when submitting

### Sprint 3: Expense List Table
- Table columns: Date | Description | Category | Amount
- Column widths: 15% | 40% | 20% | 25%
- Date format: "Jan 21, 2026" (localized short month)
- Amount format: "-kr 1,234.00" (red, JetBrains Mono font)
- Category badges: pill-shaped with icon + text (same colors as Sprint 2)
- Header: "💰 Your Expenses" + total in red
- Row hover: semi-transparent highlight (#334155 at 50%)
- Empty state: 📭 icon + "No expenses yet" + help text
- Mobile (<768px): transform table rows into stacked cards

### Sprint 4: Delete Expense
- New column: Actions (15% width, centered)
- Adjusted columns: Date 12%, Description 35%, Category 18%, Amount 20%
- Delete button: 36x36px icon-only, transparent bg, border #334155
- Delete hover: red background (#EF4444 at 15%), red border, red icon
- Icon: SVG trash (18x18px), stroke-based
- Confirmation: browser confirm() with expense description
- Delete animation: fade + slide right (0.3s), class `.expense-row-deleting`
- Success toast: red bg with 🗑 icon, "Expense deleted"
- Mobile: full-width red delete button with text label

### Sprint 5: Summary Dashboard
- Position: Above expense list table
- Total card: Gradient teal border, centered hero number (3rem, red, JetBrains Mono)
- Total format: "kr 12,345.00" + "▼ X expenses" count below
- Category breakdown: Horizontal bars sorted by amount (highest first)
- Bar colors: Match existing badge colors (Food=#FEF3C7, Transport=#DBEAFE, etc.)
- Layout: Grid with icon+name | progress bar | amount | percent
- Animation: Bars grow from 0 with staggered 0.1s delays
- Empty state: 📊 icon + "No expenses to summarize"
- Mobile: Bars stack below name, amount+percent on same line
- See DESIGN.md for full CSS specifications

## API Endpoints (Backend)
- GET /health → Health check returning status and database connection info
- GET / → Serves the main index.html template
- POST /expenses {amount, description, category, date} → Creates expense in database, returns 201 with created expense
  - amount: positive number (> 0)
  - description: required string (max 255 chars)
  - category: one of [Food, Transport, Entertainment, Bills, Shopping, Other]
  - date: ISO date format (YYYY-MM-DD)
- GET /expenses → Returns all expenses as JSON, sorted by date descending, then created_at descending
  - Response: { expenses: [{id, amount, description, category, date, created_at}, ...] }
  - amount returned as string for decimal precision
- DELETE /expenses/{id} → Deletes expense by ID
  - Response 204: Success (no content)
  - Response 404: Expense not found
- GET /expenses/summary → Returns expense totals and breakdown by category
  - Response: { total: string, by_category: { category: string }, count: number }
  - total and by_category values are strings for decimal precision
  - Only categories with expenses are included in by_category

## Frontend (Frontend)
- pages: templates/index.html
- styles: static/css/style.css
- scripts: static/js/app.js
