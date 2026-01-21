import pytest
from httpx import AsyncClient, ASGITransport
from main import app

# Use AsyncClient to avoid sync transport issues with recent httpx/ASGITransport versions

@pytest.mark.asyncio
async def test_read_main():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/")
        assert response.status_code == 200
        assert "<title>Enhetsomvandlare</title>" in response.text

@pytest.mark.asyncio
async def test_convert_length_m_to_ft():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/length", json={"value": 10, "direction": "m_to_ft"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 32.8084
        assert data["from_unit"] == "m"
        assert data["to_unit"] == "ft"

@pytest.mark.asyncio
async def test_convert_length_ft_to_m():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/length", json={"value": 32.8084, "direction": "ft_to_m"})
        assert response.status_code == 200
        data = response.json()
        assert abs(data["result"] - 10.0) < 0.0001 

@pytest.mark.asyncio
async def test_convert_weight_kg_to_lbs():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/weight", json={"value": 10, "direction": "kg_to_lbs"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 22.0462

@pytest.mark.asyncio
async def test_convert_temperature_c_to_f():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/temperature", json={"value": 0, "direction": "c_to_f"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 32.0

@pytest.mark.asyncio
async def test_convert_temperature_f_to_c():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/temperature", json={"value": 32, "direction": "f_to_c"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 0.0

@pytest.mark.asyncio
async def test_invalid_type():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/time", json={"value": 10, "direction": "m_to_ft"})
        assert response.status_code == 422

@pytest.mark.asyncio
async def test_invalid_direction():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/length", json={"value": 10, "direction": "unknown"})
        assert response.status_code == 422
