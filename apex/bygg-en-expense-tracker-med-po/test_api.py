import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from unittest.mock import patch
from datetime import date

from database import Base
from main import app

import httpx

# Monkeypatch httpx.Client.__init__ to fix incompatibility between starlette 0.35.1 and httpx 0.28+
# starlette passes 'app' but httpx 0.28+ removed it.
_original_client_init = httpx.Client.__init__

def _patched_client_init(self, *args, **kwargs):
    if "app" in kwargs:
        kwargs.pop("app")
    return _original_client_init(self, *args, **kwargs)

httpx.Client.__init__ = _patched_client_init

# Setup in-memory SQLite database
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Fixture to override the DB session
@pytest.fixture(scope="function")
def db_session():
    # Create tables
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def client(db_session):
    # Patch the SessionLocal in main.py to use our test session
    # main.SessionLocal is called to get a session instance.
    with patch("main.SessionLocal") as mock_session_local:
        mock_session_local.return_value = db_session
        with TestClient(app) as c:
            yield c

# Test 1: GET /health
def test_health_check(client):
    # Note: The health check in main.py uses engine.connect() directly, 
    # not SessionLocal. So it might still try to connect to the real DB 
    # if we don't patch engine or the health check logic.
    # However, for this test, we can mock the engine.connect used in health_check
    # or just let it pass if the env var fallback works. 
    # But main.py imports engine from database.py.
    
    # To be safe and isolated, we should patch 'main.engine' too if possible, 
    # or just accept that it might check the "real" (or default sqlite) db 
    # if we don't patch it. 
    # Given the requirements, let's try to patch it to ensure isolation.
    
    with patch("main.engine") as mock_engine:
        # We need mock_engine.connect().__enter__() to not fail
        mock_connection = mock_engine.connect.return_value.__enter__.return_value
        mock_connection.execute.return_value = None # Just needs to not raise
        
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy", "database": "connected"}

# Test 2: POST /expenses (valid)
def test_create_expense_valid(client):
    payload = {
        "amount": 100.50,
        "description": "Test Expense",
        "category": "Food",
        "date": "2026-01-21"
    }
    response = client.post("/expenses", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert float(data["amount"]) == 100.50
    assert data["description"] == "Test Expense"
    assert data["category"] == "Food"
    assert "id" in data
    assert data["date"] == "2026-01-21"

# Test 2b: POST /expenses (invalid - negative amount)
def test_create_expense_invalid_amount(client):
    payload = {
        "amount": -50,
        "description": "Negative Expense",
        "category": "Food",
        "date": "2026-01-21"
    }
    response = client.post("/expenses", json=payload)
    assert response.status_code == 422

# Test 2c: POST /expenses (invalid - missing fields)
def test_create_expense_missing_fields(client):
    payload = {
        "amount": 100
        # Missing description, category, date
    }
    response = client.post("/expenses", json=payload)
    assert response.status_code == 422

# Test 3: GET /expenses
def test_get_expenses(client):
    # Create two expenses
    # Using the API to create ensures they are in the DB and we test the full flow
    client.post("/expenses", json={
        "amount": 50.00,
        "description": "Expense 1",
        "category": "Food",
        "date": "2026-01-20"
    })
    client.post("/expenses", json={
        "amount": 20.00,
        "description": "Expense 2",
        "category": "Transport",
        "date": "2026-01-21"
    })
    
    response = client.get("/expenses")
    assert response.status_code == 200
    data = response.json()
    assert "expenses" in data
    assert len(data["expenses"]) == 2
    # Check sorting: Date descending (Expense 2 should be first as it is newer)
    assert data["expenses"][0]["description"] == "Expense 2"
    assert data["expenses"][1]["description"] == "Expense 1"

# Test 4: DELETE /expenses/{id}
def test_delete_expense(client):
    # Create an expense
    create_res = client.post("/expenses", json={
        "amount": 30.00,
        "description": "To Delete",
        "category": "Other",
        "date": "2026-01-21"
    })
    expense_id = create_res.json()["id"]
    
    # Delete it
    del_res = client.delete(f"/expenses/{expense_id}")
    assert del_res.status_code == 204
    
    # Verify it's gone
    get_res = client.get("/expenses")
    expenses = get_res.json()["expenses"]
    assert not any(e["id"] == expense_id for e in expenses)

# Test 4b: DELETE /expenses/{id} (not found)
def test_delete_expense_not_found(client):
    response = client.delete("/expenses/99999")
    assert response.status_code == 404

# Test 5: GET /expenses/summary
def test_get_summary(client):
    # Create expenses
    client.post("/expenses", json={"amount": 100.00, "description": "A", "category": "Food", "date": "2026-01-21"})
    client.post("/expenses", json={"amount": 50.00, "description": "B", "category": "Food", "date": "2026-01-21"})
    client.post("/expenses", json={"amount": 200.00, "description": "C", "category": "Transport", "date": "2026-01-21"})
    
    response = client.get("/expenses/summary")
    assert response.status_code == 200
    data = response.json()
    
    # Total should be 350.00
    assert float(data["total"]) == 350.00
    assert data["count"] == 3
    assert float(data["by_category"]["Food"]) == 150.00
    assert float(data["by_category"]["Transport"]) == 200.00
    # Ensure Categories with no expenses are not in by_category (based on PLAN.md)
    # "Only categories with expenses are included in by_category"
    assert "Entertainment" not in data["by_category"]

def test_get_summary_empty(client):
    response = client.get("/expenses/summary")
    assert response.status_code == 200
    data = response.json()
    assert float(data["total"]) == 0.00
    assert data["count"] == 0
    assert data["by_category"] == {}
