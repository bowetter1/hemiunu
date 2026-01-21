# Project Plan: Enhetsomvandlare (Unit Converter)

## Config
- **DATABASE**: none
- **FRAMEWORK**: fastapi

## File Structure
| File | Description |
|------|-------------|
| main.py | FastAPI app with API endpoints and template serving |
| templates/index.html | Single page with all three converters |
| static/js/app.js | JavaScript for fetch calls, no page reload |
| static/css/style.css | Styling (follows DESIGN.md) |

## Features (Sprint 1)
1. Length converter (meters ↔ feet)
2. Weight converter (kg ↔ lbs)
3. Temperature converter (Celsius ↔ Fahrenheit)
4. Unified UI - all converters on one page
5. Real-time results via JavaScript fetch

## Conversion Formulas (EXACT)
- **Length**: 1 meter = 3.28084 feet
- **Weight**: 1 kg = 2.20462 lbs
- **Temperature**:
  - C → F: (C × 9/5) + 32
  - F → C: (F - 32) × 5/9

---

## API Contract

### GET /
Serves the main HTML page with all converters.

Response: HTML page (templates/index.html)

---

### POST /convert/{type}
Performs unit conversion.

**Path Parameter:**
- `type`: string - one of: `length`, `weight`, `temperature`

**Request Body (JSON):**
```json
{
  "value": number,
  "direction": string
}
```

**Direction values by type:**
| Type | Direction options |
|------|-------------------|
| length | `m_to_ft` or `ft_to_m` |
| weight | `kg_to_lbs` or `lbs_to_kg` |
| temperature | `c_to_f` or `f_to_c` |

**Response 200 (JSON):**
```json
{
  "result": number,
  "from_unit": string,
  "to_unit": string,
  "original_value": number
}
```

**Example:**
```
POST /convert/length
Body: {"value": 10, "direction": "m_to_ft"}
Response: {"result": 32.8084, "from_unit": "m", "to_unit": "ft", "original_value": 10}
```

**Response 422 (Validation Error):**
- Invalid type in path
- Non-numeric value
- Invalid direction

---

## Frontend Requirements

1. **Layout**: Three converter sections on one page
2. **Each section has**:
   - Input field for value
   - Dropdown/radio for direction
   - Result display area
3. **Behavior**:
   - On input change or button click → fetch POST /convert/{type}
   - Display result without page reload
   - Show error message for invalid input

## Environment Variables
- None required (no database)
- PORT set automatically by Railway
