from fastapi import FastAPI, Request, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from typing import Literal

app = FastAPI()

# API ENDPOINTS:
# GET  /                  - Serve index.html
# POST /convert/{type}    - Perform conversion (length, weight, temperature)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Request Model
class ConversionRequest(BaseModel):
    value: float
    direction: str

# Serve frontend
@app.get("/")
def serve_frontend(request: Request):
    return templates.TemplateResponse(request, "index.html")

@app.post("/convert/{type}")
def convert(type: str, request: ConversionRequest):
    result = 0.0
    from_unit = ""
    to_unit = ""
    
    # 1. Length converter (meters ↔ feet)
    if type == "length":
        if request.direction == "m_to_ft":
            # 1 meter = 3.28084 feet
            result = request.value * 3.28084
            from_unit = "m"
            to_unit = "ft"
        elif request.direction == "ft_to_m":
            result = request.value / 3.28084
            from_unit = "ft"
            to_unit = "m"
        else:
            raise HTTPException(status_code=422, detail="Invalid direction for length. Use 'm_to_ft' or 'ft_to_m'")

    # 2. Weight converter (kg ↔ lbs)
    elif type == "weight":
        if request.direction == "kg_to_lbs":
            # 1 kg = 2.20462 lbs
            result = request.value * 2.20462
            from_unit = "kg"
            to_unit = "lbs"
        elif request.direction == "lbs_to_kg":
            result = request.value / 2.20462
            from_unit = "lbs"
            to_unit = "kg"
        else:
            raise HTTPException(status_code=422, detail="Invalid direction for weight. Use 'kg_to_lbs' or 'lbs_to_kg'")

    # 3. Temperature converter (Celsius ↔ Fahrenheit)
    elif type == "temperature":
        if request.direction == "c_to_f":
            # C → F: (C × 9/5) + 32
            result = (request.value * 9/5) + 32
            from_unit = "°C"
            to_unit = "°F"
        elif request.direction == "f_to_c":
            # F → C: (F - 32) × 5/9
            result = (request.value - 32) * 5/9
            from_unit = "°F"
            to_unit = "°C"
        else:
            raise HTTPException(status_code=422, detail="Invalid direction for temperature. Use 'c_to_f' or 'f_to_c'")

    else:
        raise HTTPException(status_code=422, detail="Invalid conversion type. Use 'length', 'weight', or 'temperature'")

    return {
        "result": result,
        "from_unit": from_unit,
        "to_unit": to_unit,
        "original_value": request.value
    }
