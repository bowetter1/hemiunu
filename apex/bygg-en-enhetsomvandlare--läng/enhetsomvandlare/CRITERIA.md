# Sprint Backlog: Enhetsomvandlare (Unit Converter)

## Sprint 1: Complete Unit Converter
| Feature | Done when... |
|---------|--------------|
| Length converter | Can convert meters ↔ feet, shows result instantly |
| Weight converter | Can convert kg ↔ lbs, shows result instantly |
| Temperature converter | Can convert Celsius ↔ Fahrenheit, shows result instantly |
| Unified UI | All converters on one page, clean and intuitive design |
| API endpoints | GET / serves page, POST /convert/{type} returns result |

## Acceptance Criteria
- [ ] User can enter a value and select conversion direction
- [ ] Result updates without page reload (JavaScript fetch)
- [ ] Conversion formulas are accurate:
  - 1 meter = 3.28084 feet
  - 1 kg = 2.20462 lbs
  - Celsius to Fahrenheit: (C × 9/5) + 32
  - Fahrenheit to Celsius: (F - 32) × 5/9
- [ ] Clean, responsive design works on mobile
- [ ] Error handling for invalid input (non-numeric values)

## Out of Scope
- Database storage of conversions
- User accounts / history
- Additional unit types (volume, speed, etc.)
- Batch conversions
