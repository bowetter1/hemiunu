# Design System - Enhetsomvandlare (Unit Converter)

## Design Philosophy
Modern, minimal dark-mode UI inspired by calculator apps. Card-based layout with clear visual hierarchy. Each converter type in its own card for easy scanning.

## Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| background | #0f0f0f | Page background |
| surface | #1a1a1a | Card backgrounds |
| surface-hover | #252525 | Card/input hover state |
| primary | #00d4aa | Buttons, active states, accents |
| primary-hover | #00b894 | Button hover |
| secondary | #2d3748 | Borders, dividers |
| text | #e2e8f0 | Primary text |
| text-muted | #94a3b8 | Labels, secondary text |
| text-dim | #64748b | Placeholders |
| success | #10b981 | Success states |
| error | #ef4444 | Error messages, invalid input |
| warning | #f59e0b | Warnings |

## Typography
- **Headings:** Inter, 600-700 weight
- **Body:** Inter, 400-500 weight
- **Numbers/Results:** JetBrains Mono, 500 weight (monospace for alignment)

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| h1 (page title) | 2rem (32px) | 700 | text |
| h2 (card title) | 1.25rem (20px) | 600 | text |
| h3 (section) | 1rem (16px) | 600 | text |
| body | 1rem (16px) | 400 | text |
| label | 0.875rem (14px) | 500 | text-muted |
| small | 0.75rem (12px) | 400 | text-muted |
| result-value | 2rem (32px) | 500 | primary |

### Font Import
```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap" rel="stylesheet">
```

## Spacing
Base unit: 4px

| Name | Value | Usage |
|------|-------|-------|
| xs | 4px | Tight gaps |
| sm | 8px | Input padding, small gaps |
| md | 16px | Card padding, component gaps |
| lg | 24px | Section gaps |
| xl | 32px | Card gaps |
| 2xl | 48px | Page margins |

## Border Radius
| Name | Value | Usage |
|------|-------|-------|
| sm | 6px | Inputs, small buttons |
| md | 10px | Buttons, toggles |
| lg | 16px | Cards |
| full | 9999px | Pills, badges |

## Shadows
```css
--shadow-card: 0 4px 6px -1px rgba(0, 0, 0, 0.3), 0 2px 4px -1px rgba(0, 0, 0, 0.2);
--shadow-hover: 0 10px 15px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -2px rgba(0, 0, 0, 0.2);
```

## Layout

### Page Structure
```
┌─────────────────────────────────────────────┐
│              ENHETSOMVANDLARE               │  ← Page title
│           (Unit Converter)                  │
├─────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐     │
│  │  LENGTH │  │  WEIGHT │  │  TEMP   │     │  ← Converter cards
│  │  ──────  │  │  ──────  │  │  ──────  │     │     (3 columns on desktop)
│  │  [input]│  │  [input]│  │  [input]│     │
│  │  ↕️      │  │  ↕️      │  │  ↕️      │     │  ← Direction toggle
│  │  result │  │  result │  │  result │     │
│  └─────────┘  └─────────┘  └─────────┘     │
└─────────────────────────────────────────────┘
```

### Responsive Breakpoints
| Breakpoint | Width | Layout |
|------------|-------|--------|
| mobile | < 640px | 1 column, stacked cards |
| tablet | 640-1024px | 2 columns |
| desktop | > 1024px | 3 columns |

## Components

### Converter Card
```css
.card {
  background: #1a1a1a;
  border-radius: 16px;
  padding: 24px;
  box-shadow: var(--shadow-card);
  border: 1px solid #2d3748;
  transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-hover);
}

.card-title {
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}
```

### Card Icons
- 📏 Length converter
- ⚖️ Weight converter
- 🌡️ Temperature converter

### Input Field
```css
.input {
  width: 100%;
  background: #0f0f0f;
  border: 2px solid #2d3748;
  border-radius: 6px;
  padding: 12px 16px;
  font-size: 1.125rem;
  font-family: 'JetBrains Mono', monospace;
  color: #e2e8f0;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.input:focus {
  outline: none;
  border-color: #00d4aa;
  box-shadow: 0 0 0 3px rgba(0, 212, 170, 0.2);
}

.input::placeholder {
  color: #64748b;
}

.input.error {
  border-color: #ef4444;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.2);
}
```

### Direction Toggle
A toggle button to swap conversion direction (e.g., m→ft or ft→m)

```css
.toggle-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin: 16px 0;
}

.toggle-label {
  font-size: 0.875rem;
  color: #94a3b8;
  min-width: 80px;
  text-align: center;
}

.toggle-btn {
  background: #2d3748;
  border: none;
  border-radius: 9999px;
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: background 0.2s, transform 0.2s;
}

.toggle-btn:hover {
  background: #00d4aa;
  transform: rotate(180deg);
}

.toggle-btn svg {
  width: 24px;
  height: 24px;
  color: #e2e8f0;
}
```

### Result Display
```css
.result {
  background: linear-gradient(135deg, rgba(0, 212, 170, 0.1), rgba(0, 212, 170, 0.05));
  border: 1px solid rgba(0, 212, 170, 0.3);
  border-radius: 10px;
  padding: 16px;
  margin-top: 16px;
  text-align: center;
}

.result-value {
  font-family: 'JetBrains Mono', monospace;
  font-size: 2rem;
  font-weight: 500;
  color: #00d4aa;
}

.result-unit {
  font-size: 0.875rem;
  color: #94a3b8;
  margin-top: 4px;
}
```

### Error Message
```css
.error-message {
  color: #ef4444;
  font-size: 0.875rem;
  margin-top: 8px;
  display: flex;
  align-items: center;
  gap: 4px;
}
```

## Interactions

### Hover States
- Cards: subtle lift (translateY -2px)
- Inputs: border color change to primary
- Toggle: background change + 180° rotation
- All interactive: cursor: pointer

### Focus States
- Inputs: primary border + glow ring
- Buttons: same as hover + focus ring

### Transitions
- All transitions: 0.2s ease
- Properties: transform, background, border-color, box-shadow

## UX Guidelines

### Accessibility
- Minimum contrast ratio: 4.5:1 (WCAG AA)
- All interactive elements: 44x44px minimum touch target
- Focus visible on all interactive elements
- Labels associated with inputs

### Feedback
- Instant calculation on input (no submit button needed)
- Error state for invalid input (non-numeric)
- Clear visual hierarchy: input → toggle → result

### Responsive Behavior
- Cards stack vertically on mobile
- Full-width inputs on all sizes
- Touch-friendly toggle buttons (48x48px)

## CSS Custom Properties
```css
:root {
  /* Colors */
  --bg: #0f0f0f;
  --surface: #1a1a1a;
  --surface-hover: #252525;
  --primary: #00d4aa;
  --primary-hover: #00b894;
  --secondary: #2d3748;
  --text: #e2e8f0;
  --text-muted: #94a3b8;
  --text-dim: #64748b;
  --error: #ef4444;

  /* Typography */
  --font-sans: 'Inter', -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;
  --space-2xl: 48px;

  /* Radius */
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 16px;
  --radius-full: 9999px;
}
```
