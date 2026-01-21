import pytest

@pytest.mark.asyncio
async def test_get_contacts_empty(client):
    response = await client.get("/contacts")
    assert response.status_code == 200
    assert response.json() == []

@pytest.mark.asyncio
async def test_create_contact(client):
    payload = {
        "name": "Test User",
        "email": "test@example.com",
        "phone": "123456789",
        "notes": "Test notes"
    }
    response = await client.post("/contacts", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == payload["name"]
    assert data["email"] == payload["email"]
    assert "id" in data
    assert "created_at" in data

@pytest.mark.asyncio
async def test_create_contact_validation_error(client):
    # Missing required 'name' field
    payload = {
        "email": "test@example.com"
    }
    response = await client.post("/contacts", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_get_contacts_with_data(client):
    # Create a contact first
    await client.post("/contacts", json={"name": "Alice"})
    await client.post("/contacts", json={"name": "Bob"})
    
    response = await client.get("/contacts")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    # Order isn't guaranteed by default unless sorted, but typically insertion order in sqlite
    names = [c["name"] for c in data]
    assert "Alice" in names
    assert "Bob" in names

@pytest.mark.asyncio
async def test_get_contact_by_id(client):
    # Create
    create_res = await client.post("/contacts", json={"name": "Charlie"})
    contact_id = create_res.json()["id"]
    
    # Get
    response = await client.get(f"/contacts/{contact_id}")
    assert response.status_code == 200
    assert response.json()["name"] == "Charlie"
    assert response.json()["id"] == contact_id

@pytest.mark.asyncio
async def test_get_contact_not_found(client):
    response = await client.get("/contacts/999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Contact not found"

@pytest.mark.asyncio
async def test_update_contact(client):
    # Create
    create_res = await client.post("/contacts", json={"name": "Dave", "email": "dave@old.com"})
    contact_id = create_res.json()["id"]
    
    # Update
    payload = {
        "name": "Dave Updated",
        "email": "dave@new.com",
        "phone": "987654321",
        "notes": "Updated notes"
    }
    response = await client.put(f"/contacts/{contact_id}", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == payload["name"]
    assert data["email"] == payload["email"]
    
    # Verify persistence
    get_res = await client.get(f"/contacts/{contact_id}")
    assert get_res.json()["name"] == "Dave Updated"

@pytest.mark.asyncio
async def test_update_contact_not_found(client):
    payload = {"name": "Ghost"}
    response = await client.put("/contacts/999", json=payload)
    assert response.status_code == 404

@pytest.mark.asyncio
async def test_update_contact_validation_error(client):
    # Create
    create_res = await client.post("/contacts", json={"name": "Eve"})
    contact_id = create_res.json()["id"]
    
    # Update with invalid data (missing name)
    payload = {"email": "eve@new.com"} 
    response = await client.put(f"/contacts/{contact_id}", json=payload)
    assert response.status_code == 422

@pytest.mark.asyncio
async def test_delete_contact(client):
    # Create
    create_res = await client.post("/contacts", json={"name": "Frank"})
    contact_id = create_res.json()["id"]
    
    # Delete
    response = await client.delete(f"/contacts/{contact_id}")
    assert response.status_code == 200
    assert response.json() == {"message": "Contact deleted"}
    
    # Verify deletion
    get_res = await client.get(f"/contacts/{contact_id}")
    assert get_res.status_code == 404

@pytest.mark.asyncio
async def test_delete_contact_not_found(client):
    response = await client.delete("/contacts/999")
    assert response.status_code == 404