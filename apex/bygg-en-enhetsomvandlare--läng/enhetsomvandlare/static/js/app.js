// Unit Converter - Frontend Application
// API Contract: POST /convert/{type} with { value: number, direction: string }

const converters = {
    length: {
        directions: ['m_to_ft', 'ft_to_m'],
        units: {
            m_to_ft: { from: 'Meter', to: 'Fot', resultUnit: 'fot' },
            ft_to_m: { from: 'Fot', to: 'Meter', resultUnit: 'm' }
        },
        currentDirection: 'm_to_ft'
    },
    weight: {
        directions: ['kg_to_lbs', 'lbs_to_kg'],
        units: {
            kg_to_lbs: { from: 'Kilogram', to: 'Pund', resultUnit: 'lbs' },
            lbs_to_kg: { from: 'Pund', to: 'Kilogram', resultUnit: 'kg' }
        },
        currentDirection: 'kg_to_lbs'
    },
    temperature: {
        directions: ['c_to_f', 'f_to_c'],
        units: {
            c_to_f: { from: 'Celsius', to: 'Fahrenheit', resultUnit: '°F' },
            f_to_c: { from: 'Fahrenheit', to: 'Celsius', resultUnit: '°C' }
        },
        currentDirection: 'c_to_f'
    }
};

function initConverters() {
    Object.keys(converters).forEach(type => {
        const input = document.getElementById(`${type}-input`);
        const toggle = document.getElementById(`${type}-toggle`);

        if (input) {
            input.addEventListener('input', () => convert(type));
        }

        if (toggle) {
            toggle.addEventListener('click', () => toggleDirection(type));
        }
    });
}

function toggleDirection(type) {
    const converter = converters[type];
    const currentIndex = converter.directions.indexOf(converter.currentDirection);
    const newIndex = (currentIndex + 1) % converter.directions.length;
    converter.currentDirection = converter.directions[newIndex];

    updateLabels(type);
    convert(type);
}

function updateLabels(type) {
    const converter = converters[type];
    const direction = converter.currentDirection;
    const units = converter.units[direction];

    const fromLabel = document.getElementById(`${type}-from`);
    const toLabel = document.getElementById(`${type}-to`);
    const resultUnit = document.getElementById(`${type}-result-unit`);

    if (fromLabel) fromLabel.textContent = units.from;
    if (toLabel) toLabel.textContent = units.to;
    if (resultUnit) resultUnit.textContent = units.resultUnit;
}

async function convert(type) {
    const input = document.getElementById(`${type}-input`);
    const resultValue = document.querySelector(`#${type}-result .result-value`);
    const errorEl = document.getElementById(`${type}-error`);
    const converter = converters[type];

    const value = input.value.trim();

    // Clear error state
    input.classList.remove('error');
    errorEl.textContent = '';

    // If empty, reset result
    if (value === '') {
        resultValue.textContent = '-';
        return;
    }

    // Validate numeric
    const numValue = parseFloat(value);
    if (isNaN(numValue)) {
        input.classList.add('error');
        errorEl.textContent = 'Ange ett giltigt nummer';
        resultValue.textContent = '-';
        return;
    }

    try {
        const response = await fetch(`/convert/${type}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                value: numValue,
                direction: converter.currentDirection
            })
        });

        if (!response.ok) {
            throw new Error('Konverteringsfel');
        }

        const data = await response.json();

        // Format result: max 6 decimals, strip trailing zeros
        const formatted = parseFloat(data.result.toFixed(6)).toString();
        resultValue.textContent = formatted;

    } catch (error) {
        input.classList.add('error');
        errorEl.textContent = 'Kunde inte utföra konvertering';
        resultValue.textContent = '-';
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', initConverters);
