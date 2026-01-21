# Project Plan - Expense Tracker

## Config
- **DATABASE**: postgres
- **FRAMEWORK**: fastapi

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app with endpoints |
| database.py | SQLAlchemy engine and session setup |
| models.py | Expense SQLAlchemy model |
| templates/index.html | Main frontend page |
| static/css/style.css | Stylesheet |
| static/js/main.js | Frontend JavaScript |

## Sprint 1: Core Setup

### Features
1. Project structure with main.py, database.py, models.py
2. PostgreSQL connection using SQLAlchemy with DATABASE_URL
3. Base HTML template with basic styling
4. Health endpoint returning 200 OK

### Database Schema

**Expense Model:**
| Column | Type | Constraints |
|--------|------|-------------|
| id | Integer | Primary Key, Auto-increment |
| amount | Numeric(10,2) | Not Null |
| description | String(255) | Not Null |
| category | String(50) | Not Null |
| date | Date | Not Null |
| created_at | DateTime | Default: now() |

### API Contract

#### GET /health
Health check endpoint.

Response 200:
```json
{
  "status": "healthy",
  "database": "connected"
}
```

#### GET /
Renders the main index.html template.

Response 200: HTML page

---

## Environment Variables
- `DATABASE_URL` - PostgreSQL connection string (set automatically by Railway)

## Database Connection Pattern

```python
# database.py pattern
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./test.db")

# Railway provides postgres:// but SQLAlchemy needs postgresql://
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()
```

## Categories
Predefined expense categories:
- Food
- Transport
- Entertainment
- Bills
- Shopping
- Other

---

## Sprint 2: Add Expense

### Features
1. Add expense form with amount, description, category, date fields
2. POST /expenses endpoint to create expenses
3. Category dropdown with predefined options
4. Form validation (amount required, positive number)

### API Contract

#### POST /expenses
Creates a new expense in the database.

**Request Body:**
```json
{
  "amount": 125.50,
  "description": "Lunch at restaurant",
  "category": "Food",
  "date": "2026-01-21"
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| amount | number | Yes | Must be positive (> 0) |
| description | string | Yes | Max 255 characters |
| category | string | Yes | Must be one of: Food, Transport, Entertainment, Bills, Shopping, Other |
| date | string (ISO date) | Yes | Format: YYYY-MM-DD |

**Response 201 (Created):**
```json
{
  "id": 1,
  "amount": "125.50",
  "description": "Lunch at restaurant",
  "category": "Food",
  "date": "2026-01-21",
  "created_at": "2026-01-21T14:30:00Z"
}
```

| Field | Type | Notes |
|-------|------|-------|
| id | number | Auto-generated primary key |
| amount | string | Decimal converted to string for JSON precision |
| description | string | As submitted |
| category | string | As submitted |
| date | string | ISO date format (YYYY-MM-DD) |
| created_at | string | ISO datetime with timezone |

**Response 422 (Validation Error):**
```json
{
  "detail": [
    {
      "loc": ["body", "amount"],
      "msg": "Amount must be positive",
      "type": "value_error"
    }
  ]
}
```

### Pydantic Schema (Backend)

```python
from pydantic import BaseModel, Field, field_validator
from datetime import date
from typing import Literal

CATEGORIES = Literal["Food", "Transport", "Entertainment", "Bills", "Shopping", "Other"]

class ExpenseCreate(BaseModel):
    amount: float = Field(..., gt=0, description="Must be positive")
    description: str = Field(..., max_length=255)
    category: CATEGORIES
    date: date

class ExpenseResponse(BaseModel):
    id: int
    amount: str  # Decimal → string for precision
    description: str
    category: str
    date: str    # date → ISO string
    created_at: str  # datetime → ISO string
```

### Form Validation Rules (Frontend)

| Field | Rule | Error Message |
|-------|------|---------------|
| amount | Required | "Amount is required" |
| amount | Must be > 0 | "Amount must be positive" |
| amount | Must be number | "Amount must be a valid number" |
| description | Required | "Description is required" |
| category | Required | "Category is required" |
| date | Required | "Date is required" |

### Frontend Implementation Notes

1. **Form element IDs:**
   - `#expense-form` - the form
   - `#amount` - amount input (type="number", step="0.01", min="0.01")
   - `#description` - description input (type="text")
   - `#category` - category select dropdown
   - `#date` - date input (type="date", default to today)

2. **Submit behavior:**
   - Validate before submit
   - POST to `/expenses` with JSON body
   - On 201: clear form, show success message
   - On 422: display validation errors

3. **Category dropdown options:**
   ```html
   <select id="category" required>
     <option value="">Select category...</option>
     <option value="Food">Food</option>
     <option value="Transport">Transport</option>
     <option value="Entertainment">Entertainment</option>
     <option value="Bills">Bills</option>
     <option value="Shopping">Shopping</option>
     <option value="Other">Other</option>
   </select>
   ```

---

## Sprint 3: View Expenses

### Features
1. GET /expenses endpoint returning all expenses as JSON
2. Expenses sorted by date descending (most recent first)
3. Expense list displayed in a table on the frontend
4. Category badges with colors for each category

### API Contract

#### GET /expenses
Returns all expenses from the database, sorted by date descending (most recent first).

**Request:**
- Method: GET
- Path: /expenses
- No request body required

**Response 200 (OK):**
```json
{
  "expenses": [
    {
      "id": 2,
      "amount": "45.00",
      "description": "Grocery shopping",
      "category": "Food",
      "date": "2026-01-21",
      "created_at": "2026-01-21T10:30:00Z"
    },
    {
      "id": 1,
      "amount": "125.50",
      "description": "Lunch at restaurant",
      "category": "Food",
      "date": "2026-01-20",
      "created_at": "2026-01-20T14:30:00Z"
    }
  ]
}
```

**Response Schema:**

| Field | Type | Notes |
|-------|------|-------|
| expenses | array | Array of expense objects |
| expenses[].id | number | Primary key |
| expenses[].amount | string | Decimal as string for precision |
| expenses[].description | string | Expense description |
| expenses[].category | string | One of predefined categories |
| expenses[].date | string | ISO date (YYYY-MM-DD) |
| expenses[].created_at | string | ISO datetime with timezone |

**Sorting:** Results are sorted by `date` descending, then by `created_at` descending (for same-date expenses).

### Pydantic Schema (Backend)

```python
from pydantic import BaseModel
from typing import List

class ExpenseResponse(BaseModel):
    id: int
    amount: str
    description: str
    category: str
    date: str
    created_at: str

class ExpenseListResponse(BaseModel):
    expenses: List[ExpenseResponse]
```

### Frontend Implementation Notes

1. **Load expenses on page load:**
   - Fetch GET /expenses when DOM is ready
   - Populate the expense table with returned data

2. **Table structure:**
   ```html
   <table id="expense-table">
     <thead>
       <tr>
         <th>Date</th>
         <th>Description</th>
         <th>Category</th>
         <th>Amount</th>
       </tr>
     </thead>
     <tbody id="expense-list">
       <!-- Rows inserted by JavaScript -->
     </tbody>
   </table>
   ```

3. **Table row format:**
   ```html
   <tr data-id="1">
     <td>2026-01-21</td>
     <td>Grocery shopping</td>
     <td><span class="category-badge category-food">🍔 Food</span></td>
     <td class="amount">45.00 kr</td>
   </tr>
   ```

4. **Category badge CSS classes:**
   - `.category-food` - Food
   - `.category-transport` - Transport
   - `.category-entertainment` - Entertainment
   - `.category-bills` - Bills
   - `.category-shopping` - Shopping
   - `.category-other` - Other

5. **Category colors (from DESIGN.md):**
   | Category | Color | Icon |
   |----------|-------|------|
   | Food | #F59E0B (amber) | 🍔 |
   | Transport | #3B82F6 (blue) | 🚗 |
   | Entertainment | #8B5CF6 (purple) | 🎬 |
   | Bills | #EF4444 (red) | 📄 |
   | Shopping | #10B981 (green) | 🛒 |
   | Other | #6B7280 (gray) | 📦 |

6. **Empty state:**
   - If no expenses, show message: "No expenses yet. Add your first expense above!"

7. **Refresh after add:**
   - After successfully adding an expense (POST /expenses returns 201), refresh the expense list by calling GET /expenses again

---

## Sprint 4: Delete Expense

### Features
1. DELETE /expenses/{id} endpoint to remove expenses
2. Delete button on each expense row in the table
3. Browser confirm() dialog before deleting
4. UI removes the expense row immediately after successful delete

### API Contract

#### DELETE /expenses/{id}
Deletes an expense from the database by its ID.

**Request:**
- Method: DELETE
- Path: /expenses/{id}
- Path Parameter: `id` (integer) - The expense ID to delete
- No request body required

**Response 204 (No Content):**
- Empty body
- Expense was successfully deleted

**Response 404 (Not Found):**
```json
{
  "detail": "Expense not found"
}
```

**Response 422 (Validation Error):**
```json
{
  "detail": [
    {
      "loc": ["path", "id"],
      "msg": "value is not a valid integer",
      "type": "type_error.integer"
    }
  ]
}
```

### Backend Implementation Notes

1. **Endpoint definition:**
   ```python
   @app.delete("/expenses/{expense_id}", status_code=204)
   def delete_expense(expense_id: int, db: Session = Depends(get_db)):
       expense = db.query(Expense).filter(Expense.id == expense_id).first()
       if not expense:
           raise HTTPException(status_code=404, detail="Expense not found")
       db.delete(expense)
       db.commit()
       return Response(status_code=204)
   ```

2. **Import required:**
   - `from fastapi import Response`
   - `from fastapi import HTTPException` (likely already imported)

### Frontend Implementation Notes

1. **Add delete button to each row:**
   - Update table row structure to include a 5th column for actions
   - Delete button with trash icon or "Delete" text

2. **Updated table row format:**
   ```html
   <tr data-id="1">
     <td>2026-01-21</td>
     <td>Grocery shopping</td>
     <td><span class="category-badge category-food">🍔 Food</span></td>
     <td class="amount">45.00 kr</td>
     <td><button class="delete-btn" data-id="1">🗑️</button></td>
   </tr>
   ```

3. **Updated table header:**
   ```html
   <thead>
     <tr>
       <th>Date</th>
       <th>Description</th>
       <th>Category</th>
       <th>Amount</th>
       <th></th>  <!-- Empty header for actions column -->
     </tr>
   </thead>
   ```

4. **Column widths update:**
   - Date: 15%
   - Description: 35%
   - Category: 20%
   - Amount: 20%
   - Actions: 10%

5. **Delete button click handler:**
   ```javascript
   async function deleteExpense(id) {
     if (!confirm('Are you sure you want to delete this expense?')) {
       return;
     }

     const response = await fetch(`/expenses/${id}`, {
       method: 'DELETE'
     });

     if (response.status === 204) {
       // Remove row from table
       const row = document.querySelector(`tr[data-id="${id}"]`);
       if (row) {
         row.remove();
       }
       // Check if table is now empty, show empty state if needed
       checkEmptyState();
     } else if (response.status === 404) {
       alert('Expense not found. It may have been already deleted.');
       // Refresh the list to sync with server
       loadExpenses();
     }
   }
   ```

6. **Event delegation for delete buttons:**
   ```javascript
   document.getElementById('expense-list').addEventListener('click', (e) => {
     if (e.target.classList.contains('delete-btn')) {
       const id = e.target.dataset.id;
       deleteExpense(id);
     }
   });
   ```

7. **Delete button styling:**
   - Background: transparent or subtle
   - Hover: red background (#EF4444) with white icon
   - Cursor: pointer
   - Border: none or subtle
   - Padding: small (8px)

8. **CSS classes:**
   ```css
   .delete-btn {
     background: transparent;
     border: none;
     cursor: pointer;
     padding: 8px;
     border-radius: 4px;
     transition: background-color 0.2s;
   }

   .delete-btn:hover {
     background-color: #EF4444;
     color: white;
   }
   ```

---

## Sprint 5: Expense Summary

### Features
1. GET /expenses/summary endpoint returning totals by category
2. Total display showing sum of all expenses
3. Category breakdown with spending per category
4. Visual chart (bar or pie) showing category distribution

### API Contract

#### GET /expenses/summary
Returns the total of all expenses and a breakdown by category.

**Request:**
- Method: GET
- Path: /expenses/summary
- No request body required

**Response 200 (OK):**
```json
{
  "total": "1250.50",
  "by_category": {
    "Food": "450.00",
    "Transport": "200.50",
    "Entertainment": "150.00",
    "Bills": "300.00",
    "Shopping": "100.00",
    "Other": "50.00"
  },
  "count": 15
}
```

**Response Schema:**

| Field | Type | Notes |
|-------|------|-------|
| total | string | Sum of all expense amounts (Decimal as string) |
| by_category | object | Object with category names as keys, totals as string values |
| count | number | Total number of expenses |

**Notes:**
- `by_category` only includes categories that have at least one expense
- Categories with zero expenses are omitted from the response
- All monetary values are strings for decimal precision
- If no expenses exist: `{ "total": "0.00", "by_category": {}, "count": 0 }`

### Pydantic Schema (Backend)

```python
from pydantic import BaseModel
from typing import Dict

class ExpenseSummaryResponse(BaseModel):
    total: str  # Decimal → string for precision
    by_category: Dict[str, str]  # Category name → total as string
    count: int  # Total number of expenses
```

### Backend Implementation Notes

1. **SQL Query approach:**
   ```python
   from sqlalchemy import func

   @app.get("/expenses/summary")
   def get_expense_summary(db: Session = Depends(get_db)):
       # Get total
       total_result = db.query(func.coalesce(func.sum(Expense.amount), 0)).scalar()

       # Get count
       count = db.query(func.count(Expense.id)).scalar()

       # Get by category
       category_totals = db.query(
           Expense.category,
           func.sum(Expense.amount)
       ).group_by(Expense.category).all()

       by_category = {cat: str(amount) for cat, amount in category_totals}

       return {
           "total": str(total_result),
           "by_category": by_category,
           "count": count
       }
   ```

2. **Important:** Use `func.coalesce` to handle empty table (returns 0 instead of None)

### Frontend Implementation Notes

1. **Summary section placement:**
   - Place above the expense table
   - Card-style container with summary data

2. **HTML structure:**
   ```html
   <section id="summary-section" class="summary-card">
     <div class="summary-total">
       <h2>Total Spent</h2>
       <span id="total-amount" class="total-value">0.00 kr</span>
       <span id="expense-count" class="expense-count">0 expenses</span>
     </div>
     <div class="category-breakdown">
       <h3>By Category</h3>
       <div id="category-chart" class="chart-container">
         <!-- Chart rendered here -->
       </div>
       <ul id="category-list" class="category-list">
         <!-- Category items inserted by JS -->
       </ul>
     </div>
   </section>
   ```

3. **Category list item format:**
   ```html
   <li class="category-item">
     <span class="category-badge category-food">🍔 Food</span>
     <span class="category-amount">450.00 kr</span>
     <span class="category-percent">36%</span>
   </li>
   ```

4. **Chart implementation options:**
   - Option A: Simple CSS bar chart (recommended for simplicity)
   - Option B: Canvas-based pie chart
   - Option C: SVG-based chart

5. **CSS bar chart approach (recommended):**
   ```html
   <div class="bar-chart">
     <div class="bar" style="--width: 36%; --color: #F59E0B;">
       <span class="bar-label">🍔 Food</span>
       <span class="bar-value">450 kr (36%)</span>
     </div>
     <!-- More bars... -->
   </div>
   ```

   ```css
   .bar {
     width: var(--width);
     background-color: var(--color);
     height: 32px;
     border-radius: 4px;
     display: flex;
     align-items: center;
     justify-content: space-between;
     padding: 0 12px;
     min-width: 120px;
     margin-bottom: 8px;
   }
   ```

6. **JavaScript to load summary:**
   ```javascript
   async function loadSummary() {
     const response = await fetch('/expenses/summary');
     const data = await response.json();

     // Update total
     document.getElementById('total-amount').textContent =
       `${data.total} kr`;
     document.getElementById('expense-count').textContent =
       `${data.count} expense${data.count !== 1 ? 's' : ''}`;

     // Render category breakdown
     renderCategoryChart(data.by_category, data.total);
   }
   ```

7. **Calculate percentages:**
   ```javascript
   function renderCategoryChart(byCategory, total) {
     const totalNum = parseFloat(total) || 1; // Avoid division by zero
     const chartContainer = document.getElementById('category-chart');
     chartContainer.innerHTML = '';

     // Category colors
     const colors = {
       'Food': '#F59E0B',
       'Transport': '#3B82F6',
       'Entertainment': '#8B5CF6',
       'Bills': '#EF4444',
       'Shopping': '#10B981',
       'Other': '#6B7280'
     };

     // Category icons
     const icons = {
       'Food': '🍔',
       'Transport': '🚗',
       'Entertainment': '🎬',
       'Bills': '📄',
       'Shopping': '🛒',
       'Other': '📦'
     };

     for (const [category, amount] of Object.entries(byCategory)) {
       const amountNum = parseFloat(amount);
       const percent = ((amountNum / totalNum) * 100).toFixed(0);

       const bar = document.createElement('div');
       bar.className = 'bar';
       bar.style.setProperty('--width', `${Math.max(percent, 10)}%`);
       bar.style.setProperty('--color', colors[category] || '#6B7280');
       bar.innerHTML = `
         <span class="bar-label">${icons[category] || '📦'} ${category}</span>
         <span class="bar-value">${amount} kr (${percent}%)</span>
       `;
       chartContainer.appendChild(bar);
     }
   }
   ```

8. **Refresh summary on changes:**
   - Call `loadSummary()` on page load
   - Call `loadSummary()` after adding an expense
   - Call `loadSummary()` after deleting an expense

9. **Empty state:**
   - If `count === 0`, show: "No expenses yet. Add your first expense to see your spending summary!"

10. **Styling guidelines (from DESIGN.md):**
    - Summary card: `background: #1E293B`, `border-radius: 12px`
    - Total amount: Large font, `color: #EF4444` (red), JetBrains Mono
    - Category badges: Use same styling as expense table
    - Bar chart: Rounded corners, smooth hover transitions
