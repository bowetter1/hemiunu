import pytest
from httpx import AsyncClient, ASGITransport
from main import app

@pytest.mark.asyncio
async def test_convert_length_m_to_ft():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1 m = 3.28084 ft
        response = await client.post("/convert/length", json={"value": 1, "direction": "m_to_ft"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 3.28084
        assert data["from_unit"] == "m"
        assert data["to_unit"] == "ft"
        assert data["original_value"] == 1.0

@pytest.mark.asyncio
async def test_convert_length_ft_to_m():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 3.28084 ft = 1 m
        response = await client.post("/convert/length", json={"value": 3.28084, "direction": "ft_to_m"})
        assert response.status_code == 200
        data = response.json()
        assert abs(data["result"] - 1.0) < 0.000001
        assert data["from_unit"] == "ft"
        assert data["to_unit"] == "m"

@pytest.mark.asyncio
async def test_convert_weight_kg_to_lbs():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1 kg = 2.20462 lbs
        response = await client.post("/convert/weight", json={"value": 1, "direction": "kg_to_lbs"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 2.20462
        assert data["from_unit"] == "kg"
        assert data["to_unit"] == "lbs"

@pytest.mark.asyncio
async def test_convert_weight_lbs_to_kg():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 2.20462 lbs = 1 kg
        response = await client.post("/convert/weight", json={"value": 2.20462, "direction": "lbs_to_kg"})
        assert response.status_code == 200
        data = response.json()
        assert abs(data["result"] - 1.0) < 0.000001
        assert data["from_unit"] == "lbs"
        assert data["to_unit"] == "kg"

@pytest.mark.asyncio
async def test_convert_temperature_c_to_f():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 0C = 32F
        response = await client.post("/convert/temperature", json={"value": 0, "direction": "c_to_f"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 32.0
        assert data["from_unit"] == "°C"
        assert data["to_unit"] == "°F"

@pytest.mark.asyncio
async def test_convert_temperature_f_to_c():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 32F = 0C
        response = await client.post("/convert/temperature", json={"value": 32, "direction": "f_to_c"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 0.0
        assert data["from_unit"] == "°F"
        assert data["to_unit"] == "°C"

@pytest.mark.asyncio
async def test_convert_temperature_f_to_c_boiling():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 212F = 100C
        response = await client.post("/convert/temperature", json={"value": 212, "direction": "f_to_c"})
        assert response.status_code == 200
        data = response.json()
        assert data["result"] == 100.0

@pytest.mark.asyncio
async def test_invalid_type():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/currency", json={"value": 10, "direction": "usd_to_eur"})
        assert response.status_code == 422

@pytest.mark.asyncio
async def test_invalid_direction_length():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/length", json={"value": 10, "direction": "up_to_down"})
        assert response.status_code == 422

@pytest.mark.asyncio
async def test_invalid_value_type():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/convert/length", json={"value": "not_a_number", "direction": "m_to_ft"})
        assert response.status_code == 422