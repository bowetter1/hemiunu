import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from main import app, get_db
import models

# Setup in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite://"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

models.Base.metadata.create_all(bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.mark.asyncio
async def test_create_contact():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.post(
            "/contacts",
            json={"name": "Test User", "email": "test@example.com", "phone": "123456789", "notes": "Test notes"},
        )
        assert response.status_code == 201
        data = response.json()
        assert data["name"] == "Test User"
        assert "id" in data

@pytest.mark.asyncio
async def test_read_contact():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # First create a contact
        response = await client.post(
            "/contacts",
            json={"name": "Read Me", "email": "read@example.com"},
        )
        assert response.status_code == 201
        contact_id = response.json()["id"]

        # Then read it
        response = await client.get(f"/contacts/{contact_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Read Me"
        assert data["id"] == contact_id

@pytest.mark.asyncio
async def test_read_contact_not_found():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.get("/contacts/99999")
        assert response.status_code == 404

@pytest.mark.asyncio
async def test_update_contact():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # First create
        response = await client.post(
            "/contacts",
            json={"name": "Update Me", "email": "update@example.com"},
        )
        contact_id = response.json()["id"]

        # Update
        response = await client.put(
            f"/contacts/{contact_id}",
            json={"name": "Updated Name", "email": "updated@example.com", "phone": "111", "notes": "new notes"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["email"] == "updated@example.com"

        # Verify update with GET
        response = await client.get(f"/contacts/{contact_id}")
        assert response.json()["name"] == "Updated Name"

@pytest.mark.asyncio
async def test_update_contact_not_found():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        response = await client.put(
            "/contacts/99999",
            json={"name": "Ghost", "email": "ghost@example.com"},
        )
        assert response.status_code == 404