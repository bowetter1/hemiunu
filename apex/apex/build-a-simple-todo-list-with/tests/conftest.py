# conftest.py - pytest fixtures for todo API tests
import sys
from pathlib import Path

# Add project root to path so imports work
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
import pytest_asyncio
import httpx

# Override database before importing main
import database

@pytest.fixture(autouse=True)
def test_db(tmp_path):
    """Use a temporary database for each test."""
    test_db_path = str(tmp_path / "test_todos.db")
    original_db_name = database.DB_NAME
    database.DB_NAME = test_db_path
    database.init_db()
    yield test_db_path
    database.DB_NAME = original_db_name

@pytest_asyncio.fixture
async def client():
    """Create an async test client for the FastAPI app."""
    from main import app
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client
