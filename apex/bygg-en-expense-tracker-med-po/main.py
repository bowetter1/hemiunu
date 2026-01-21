from fastapi import FastAPI, Request, HTTPException
from fastapi.templating import Jinja2Templates
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from database import engine, SessionLocal, create_tables
from sqlalchemy import text, func
from models import Expense
from pydantic import BaseModel, Field, field_validator
from typing import Literal, Dict
from datetime import date
import os

# Initialize FastAPI app
app = FastAPI()

# Mount static files directory
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Define the allowed categories
CATEGORIES = Literal["Food", "Transport", "Entertainment", "Bills", "Shopping", "Other"]

# Pydantic models for request/response validation
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

class ExpenseListResponse(BaseModel):
    expenses: list[ExpenseResponse]

class ExpenseSummaryResponse(BaseModel):
    total: str  # Decimal → string for precision
    by_category: Dict[str, str]  # Category name → total as string
    count: int  # Total number of expenses

# API ENDPOINTS:
# GET /health - health check
# GET / - serves index.html template
# POST /expenses - creates expense (body: amount, description, category, date) → returns 201 with created expense
# GET /expenses - returns all expenses sorted by date desc, then created_at desc
# DELETE /expenses/{id} - deletes expense by ID → returns 204 on success, 404 if not found
# GET /expenses/summary - returns expense totals and breakdown by category


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))

        return JSONResponse(
            status_code=200,
            content={"status": "healthy", "database": "connected"}
        )
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={"status": "unhealthy", "error": str(e)}
        )


@app.get("/")
def serve_frontend(request: Request):
    """Serve the main frontend page"""
    return templates.TemplateResponse("index.html", {"request": request})


@app.post("/expenses", status_code=201, response_model=ExpenseResponse)
def create_expense(expense_data: ExpenseCreate):
    """Create a new expense in the database"""
    db = SessionLocal()
    try:
        # Create new expense object
        new_expense = Expense(
            amount=expense_data.amount,
            description=expense_data.description,
            category=expense_data.category,
            date=expense_data.date
        )

        # Add to database and commit
        db.add(new_expense)
        db.commit()
        db.refresh(new_expense)

        # Convert to response format
        response_data = ExpenseResponse(
            id=new_expense.id,
            amount=str(new_expense.amount),
            description=new_expense.description,
            category=new_expense.category,
            date=new_expense.date.isoformat(),
            created_at=new_expense.created_at.isoformat()
        )

        return response_data
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating expense: {str(e)}")
    finally:
        db.close()


@app.get("/expenses", response_model=ExpenseListResponse)
def get_expenses():
    """Get all expenses, sorted by date descending, then by created_at descending"""
    db = SessionLocal()
    try:
        # Query expenses sorted by date descending, then by created_at descending
        expenses = db.query(Expense).order_by(
            Expense.date.desc(),
            Expense.created_at.desc()
        ).all()

        # Convert to response format
        expense_responses = []
        for expense in expenses:
            expense_response = ExpenseResponse(
                id=expense.id,
                amount=str(expense.amount),
                description=expense.description,
                category=expense.category,
                date=expense.date.isoformat(),
                created_at=expense.created_at.isoformat()
            )
            expense_responses.append(expense_response)

        return ExpenseListResponse(expenses=expense_responses)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving expenses: {str(e)}")
    finally:
        db.close()


@app.get("/expenses/summary", response_model=ExpenseSummaryResponse)
def get_expense_summary():
    """Get expense summary: total amount, breakdown by category, and count"""
    db = SessionLocal()
    try:
        # Get total amount of all expenses
        total_result = db.query(func.coalesce(func.sum(Expense.amount), 0)).scalar()

        # Get count of all expenses
        count = db.query(func.count(Expense.id)).scalar()

        # Get sum of amounts grouped by category
        category_totals = db.query(
            Expense.category,
            func.sum(Expense.amount)
        ).group_by(Expense.category).all()

        # Convert category totals to dictionary with string values
        by_category = {cat: str(amount) for cat, amount in category_totals}

        # Return the summary data
        return ExpenseSummaryResponse(
            total=str(total_result),
            by_category=by_category,
            count=count
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving expense summary: {str(e)}")
    finally:
        db.close()


@app.delete("/expenses/{expense_id}", status_code=204)
def delete_expense(expense_id: int):
    """Delete an expense by its ID"""
    db = SessionLocal()
    try:
        # Find the expense by ID
        expense = db.query(Expense).filter(Expense.id == expense_id).first()

        # If expense doesn't exist, raise 404 error
        if not expense:
            raise HTTPException(status_code=404, detail="Expense not found")

        # Delete the expense from the database
        db.delete(expense)
        db.commit()

        # Return 204 No Content on successful deletion
        return
    except HTTPException:
        # Re-raise HTTP exceptions (like 404) to be handled properly
        raise
    except Exception as e:
        # Handle any other exceptions
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error deleting expense: {str(e)}")
    finally:
        db.close()


@app.on_event("startup")
def startup_event():
    """Create database tables on startup"""
    try:
        create_tables()
        print("Database tables created successfully")
    except Exception as e:
        print(f"Error creating database tables: {e}")


# For Railway deployment, we should handle the PORT environment variable properly
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)