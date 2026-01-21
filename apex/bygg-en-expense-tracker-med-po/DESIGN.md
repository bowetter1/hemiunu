# Design System - Expense Tracker

## Design Philosophy
Clean, professional, and trustworthy. The teal/green palette conveys financial stability and growth, while maintaining excellent readability for data-heavy interfaces.

---

## Color Palette

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| primary | #0D9488 | 13, 148, 136 | Buttons, links, active states |
| primary-dark | #0F766E | 15, 118, 110 | Hover states, emphasis |
| primary-light | #5EEAD4 | 94, 234, 212 | Highlights, badges |
| background | #0F172A | 15, 23, 42 | Page background |
| surface | #1E293B | 30, 41, 59 | Cards, modals, containers |
| surface-light | #334155 | 51, 65, 85 | Hover backgrounds, borders |
| text | #F1F5F9 | 241, 245, 249 | Primary text |
| text-muted | #94A3B8 | 148, 163, 184 | Secondary text, labels |
| success | #22C55E | 34, 197, 94 | Income, positive values |
| danger | #EF4444 | 239, 68, 68 | Expenses, delete, errors |
| warning | #F59E0B | 245, 158, 11 | Alerts, pending |
| white | #FFFFFF | 255, 255, 255 | Button text on primary |

### Category Colors
| Category | Background | Text |
|----------|------------|------|
| Food | #FEF3C7 | #92400E |
| Transport | #DBEAFE | #1E40AF |
| Entertainment | #F3E8FF | #6B21A8 |
| Bills | #FEE2E2 | #991B1B |
| Shopping | #D1FAE5 | #065F46 |
| Other | #E2E8F0 | #475569 |

---

## Typography

**Font Stack:** Inter, system-ui, -apple-system, sans-serif
- Load from Google Fonts: `https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap`

**Monospace (numbers):** JetBrains Mono, monospace
- Load: `https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500&display=swap`

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| h1 | 2rem (32px) | 700 | 1.2 |
| h2 | 1.5rem (24px) | 600 | 1.3 |
| h3 | 1.25rem (20px) | 600 | 1.4 |
| body | 1rem (16px) | 400 | 1.5 |
| small | 0.875rem (14px) | 400 | 1.4 |
| caption | 0.75rem (12px) | 500 | 1.3 |

**Money/Numbers:** Use JetBrains Mono at weight 500 for all currency values.

---

## Spacing

Base unit: **4px**

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Inline spacing, icon gaps |
| sm | 8px | Button padding-x, input padding |
| md | 16px | Card padding, section gaps |
| lg | 24px | Component gaps |
| xl | 32px | Section spacing |
| 2xl | 48px | Page margins |

---

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| sm | 4px | Badges, small elements |
| md | 8px | Buttons, inputs |
| lg | 12px | Cards, modals |
| xl | 16px | Large containers |
| full | 9999px | Pills, avatars |

---

## Shadows

```css
--shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
--shadow-md: 0 4px 6px rgba(0, 0, 0, 0.4);
--shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.5);
```

---

## Components

### Buttons

**Primary Button**
```css
.btn-primary {
  background: #0D9488;
  color: #FFFFFF;
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 600;
  font-size: 1rem;
  border: none;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-primary:hover {
  background: #0F766E;
}
```

**Secondary Button**
```css
.btn-secondary {
  background: transparent;
  color: #F1F5F9;
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 500;
  border: 1px solid #334155;
}
.btn-secondary:hover {
  background: #334155;
}
```

**Danger Button**
```css
.btn-danger {
  background: #EF4444;
  color: #FFFFFF;
  padding: 8px 16px;
  border-radius: 8px;
  font-weight: 500;
}
.btn-danger:hover {
  background: #DC2626;
}
```

### Cards

```css
.card {
  background: #1E293B;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.4);
}
```

### Inputs

```css
.input {
  background: #0F172A;
  border: 1px solid #334155;
  border-radius: 8px;
  padding: 12px 16px;
  color: #F1F5F9;
  font-size: 1rem;
  width: 100%;
}
.input:focus {
  outline: none;
  border-color: #0D9488;
  box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.3);
}
.input::placeholder {
  color: #64748B;
}
```

### Select/Dropdown

```css
.select {
  background: #0F172A;
  border: 1px solid #334155;
  border-radius: 8px;
  padding: 12px 16px;
  color: #F1F5F9;
  font-size: 1rem;
  cursor: pointer;
}
```

### Category Badges

```css
.badge {
  display: inline-block;
  padding: 4px 12px;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}
.badge-food { background: #FEF3C7; color: #92400E; }
.badge-transport { background: #DBEAFE; color: #1E40AF; }
.badge-entertainment { background: #F3E8FF; color: #6B21A8; }
.badge-bills { background: #FEE2E2; color: #991B1B; }
.badge-shopping { background: #D1FAE5; color: #065F46; }
.badge-other { background: #E2E8F0; color: #475569; }
```

### Table

```css
.table {
  width: 100%;
  border-collapse: collapse;
}
.table th {
  text-align: left;
  padding: 12px 16px;
  color: #94A3B8;
  font-weight: 500;
  font-size: 0.875rem;
  border-bottom: 1px solid #334155;
}
.table td {
  padding: 16px;
  border-bottom: 1px solid #334155;
  color: #F1F5F9;
}
.table tr:hover {
  background: #334155;
}
```

### Amount Display

```css
.amount {
  font-family: 'JetBrains Mono', monospace;
  font-weight: 500;
}
.amount-expense {
  color: #EF4444;
}
.amount-expense::before {
  content: '-';
}
```

---

## Layout

### Container
- Max width: 1200px
- Padding: 24px (desktop), 16px (mobile)
- Centered with `margin: 0 auto`

### Grid
- Use CSS Grid or Flexbox
- Gap: 24px between major sections
- Gap: 16px between form elements

### Responsive Breakpoints
| Name | Width | Usage |
|------|-------|-------|
| sm | 640px | Mobile landscape |
| md | 768px | Tablet |
| lg | 1024px | Desktop |
| xl | 1280px | Large desktop |

---

## Add Expense Form (Sprint 2)

### Form Layout
The form lives inside a card component, with a clear header and stacked form fields.

```
┌─────────────────────────────────────────┐
│  📝 Add Expense                         │  ← Form header (h2)
├─────────────────────────────────────────┤
│  Amount *                               │
│  ┌─────────────────────────────────────┐│
│  │ kr 0.00                             ││  ← Number input
│  └─────────────────────────────────────┘│
│                                         │
│  Description                            │
│  ┌─────────────────────────────────────┐│
│  │ What did you spend on?              ││  ← Text input
│  └─────────────────────────────────────┘│
│                                         │
│  Category *                             │
│  ┌─────────────────────────────────┬──┐│
│  │ Select category                 │▼ ││  ← Dropdown
│  └─────────────────────────────────┴──┘│
│                                         │
│  Date                                   │
│  ┌─────────────────────────────────────┐│
│  │ 2026-01-21                          ││  ← Date picker
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │         Add Expense                 ││  ← Primary button
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

### Form Card Container
```css
.expense-form {
  background: var(--surface);
  border-radius: var(--radius-lg);
  padding: var(--space-lg);
  box-shadow: var(--shadow-md);
  max-width: 480px;
  width: 100%;
}

.expense-form h2 {
  color: var(--text);
  font-size: 1.5rem;
  font-weight: 600;
  margin-bottom: var(--space-lg);
  display: flex;
  align-items: center;
  gap: var(--space-sm);
}
```

### Form Group (Label + Input)
```css
.form-group {
  margin-bottom: var(--space-md);
}

.form-label {
  display: block;
  color: var(--text-muted);
  font-size: 0.875rem;
  font-weight: 500;
  margin-bottom: var(--space-xs);
}

.form-label.required::after {
  content: ' *';
  color: var(--danger);
}
```

### Amount Input (Special Styling)
```css
.input-amount {
  background: var(--bg);
  border: 1px solid var(--surface-light);
  border-radius: var(--radius-md);
  padding: 12px 16px;
  color: var(--text);
  font-family: var(--font-mono);
  font-size: 1.25rem;
  font-weight: 500;
  width: 100%;
  text-align: right;
}

.input-amount:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.3);
}

.input-amount::placeholder {
  color: #64748B;
  text-align: left;
}
```

### Category Dropdown
```css
.select-category {
  background: var(--bg);
  border: 1px solid var(--surface-light);
  border-radius: var(--radius-md);
  padding: 12px 16px;
  color: var(--text);
  font-size: 1rem;
  width: 100%;
  cursor: pointer;
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='%2394A3B8' stroke-width='2'%3E%3Cpolyline points='6,9 12,15 18,9'%3E%3C/polyline%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 12px center;
  background-size: 20px;
  padding-right: 44px;
}

.select-category:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.3);
}

.select-category option {
  background: var(--surface);
  color: var(--text);
  padding: 8px;
}
```

### Category Options (with icons)
| Category | Icon | Option Text |
|----------|------|-------------|
| Food | 🍔 | Food & Dining |
| Transport | 🚗 | Transport |
| Entertainment | 🎬 | Entertainment |
| Bills | 📄 | Bills & Utilities |
| Shopping | 🛒 | Shopping |
| Other | 📦 | Other |

### Date Input
```css
.input-date {
  background: var(--bg);
  border: 1px solid var(--surface-light);
  border-radius: var(--radius-md);
  padding: 12px 16px;
  color: var(--text);
  font-size: 1rem;
  width: 100%;
}

.input-date:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(13, 148, 136, 0.3);
}

/* Style the date picker icon */
.input-date::-webkit-calendar-picker-indicator {
  filter: invert(0.7);
  cursor: pointer;
}
```

### Submit Button
```css
.btn-submit {
  background: var(--primary);
  color: #FFFFFF;
  padding: 14px 24px;
  border-radius: var(--radius-md);
  font-weight: 600;
  font-size: 1rem;
  border: none;
  cursor: pointer;
  width: 100%;
  margin-top: var(--space-md);
  transition: background 0.2s, transform 0.1s;
}

.btn-submit:hover {
  background: var(--primary-dark);
}

.btn-submit:active {
  transform: scale(0.98);
}

.btn-submit:disabled {
  background: var(--surface-light);
  color: var(--text-muted);
  cursor: not-allowed;
}
```

---

## Form Validation & Feedback

### Error States
```css
/* Input in error state */
.input-error {
  border-color: var(--danger) !important;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3) !important;
}

/* Error message below input */
.error-message {
  color: var(--danger);
  font-size: 0.75rem;
  margin-top: var(--space-xs);
  display: flex;
  align-items: center;
  gap: 4px;
}

.error-message::before {
  content: '⚠';
}
```

### Validation Rules
| Field | Rule | Error Message |
|-------|------|---------------|
| Amount | Required, > 0 | "Please enter an amount greater than 0" |
| Amount | Number only | "Please enter a valid number" |
| Category | Required | "Please select a category" |
| Description | Optional | — |
| Date | Defaults to today | — |

### Success Feedback
```css
/* Success notification (toast) */
.toast-success {
  position: fixed;
  bottom: 24px;
  right: 24px;
  background: var(--success);
  color: #FFFFFF;
  padding: 16px 24px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  animation: slideIn 0.3s ease-out;
  z-index: 1000;
}

.toast-success::before {
  content: '✓';
  font-weight: bold;
}

@keyframes slideIn {
  from {
    transform: translateX(100%);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}
```

### Loading State
```css
.btn-submit.loading {
  pointer-events: none;
  position: relative;
  color: transparent;
}

.btn-submit.loading::after {
  content: '';
  position: absolute;
  width: 20px;
  height: 20px;
  top: 50%;
  left: 50%;
  margin: -10px 0 0 -10px;
  border: 2px solid #FFFFFF;
  border-top-color: transparent;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
```

---

## Expense List Table (Sprint 3)

### Table Layout Overview
```
┌─────────────────────────────────────────────────────────────────────────────┐
│  💰 Your Expenses                                            Total: -kr 1,234│
├─────────────────────────────────────────────────────────────────────────────┤
│  DATE          DESCRIPTION         CATEGORY            AMOUNT               │
├─────────────────────────────────────────────────────────────────────────────┤
│  Jan 21, 2026  Lunch at restaurant  [🍔 Food]          -kr 149.00           │
│  Jan 20, 2026  Bus ticket           [🚗 Transport]      -kr 42.00           │
│  Jan 19, 2026  Netflix subscription [🎬 Entertainment]  -kr 129.00          │
│  Jan 18, 2026  Electric bill        [📄 Bills]         -kr 890.00           │
│  Jan 17, 2026  Groceries            [🛒 Shopping]      -kr 324.00           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Table Container
```css
.expense-list {
  background: var(--surface);
  border-radius: var(--radius-lg);
  padding: var(--space-lg);
  box-shadow: var(--shadow-md);
  overflow: hidden;
}

.expense-list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--space-lg);
}

.expense-list-header h2 {
  color: var(--text);
  font-size: 1.5rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: var(--space-sm);
}

.expense-total {
  color: var(--text-muted);
  font-size: 0.875rem;
}

.expense-total .total-amount {
  font-family: var(--font-mono);
  font-weight: 500;
  color: var(--danger);
  font-size: 1.25rem;
  margin-left: var(--space-xs);
}
```

### Table Structure
```css
.expense-table {
  width: 100%;
  border-collapse: collapse;
}

/* Column widths */
.expense-table th:nth-child(1),
.expense-table td:nth-child(1) { width: 15%; } /* Date */
.expense-table th:nth-child(2),
.expense-table td:nth-child(2) { width: 40%; } /* Description */
.expense-table th:nth-child(3),
.expense-table td:nth-child(3) { width: 20%; } /* Category */
.expense-table th:nth-child(4),
.expense-table td:nth-child(4) { width: 25%; text-align: right; } /* Amount */
```

### Table Headers
```css
.expense-table thead {
  background: var(--bg);
}

.expense-table th {
  text-align: left;
  padding: var(--space-sm) var(--space-md);
  color: var(--text-muted);
  font-weight: 500;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 2px solid var(--surface-light);
}

.expense-table th:last-child {
  text-align: right;
}
```

### Table Rows
```css
.expense-table tbody tr {
  transition: background 0.15s ease;
}

.expense-table tbody tr:hover {
  background: rgba(51, 65, 85, 0.5);
}

.expense-table td {
  padding: var(--space-md);
  color: var(--text);
  font-size: 0.9375rem;
  border-bottom: 1px solid var(--surface-light);
  vertical-align: middle;
}

.expense-table tbody tr:last-child td {
  border-bottom: none;
}
```

### Column Styling

#### Date Column
```css
.expense-date {
  color: var(--text-muted);
  font-size: 0.875rem;
  white-space: nowrap;
}
```
**Format:** "Jan 21, 2026" (use toLocaleDateString with options)

#### Description Column
```css
.expense-description {
  color: var(--text);
  font-weight: 400;
  max-width: 300px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.expense-description:empty::before {
  content: '—';
  color: var(--text-muted);
}
```

#### Category Badge Column
```css
.category-badge {
  display: inline-flex;
  align-items: center;
  gap: var(--space-xs);
  padding: 4px 12px;
  border-radius: var(--radius-full);
  font-size: 0.75rem;
  font-weight: 500;
  white-space: nowrap;
}

/* Category badge colors (same as Sprint 2) */
.category-badge.food { background: #FEF3C7; color: #92400E; }
.category-badge.transport { background: #DBEAFE; color: #1E40AF; }
.category-badge.entertainment { background: #F3E8FF; color: #6B21A8; }
.category-badge.bills { background: #FEE2E2; color: #991B1B; }
.category-badge.shopping { background: #D1FAE5; color: #065F46; }
.category-badge.other { background: #E2E8F0; color: #475569; }
```

| Category | Icon | Badge Class |
|----------|------|-------------|
| Food | 🍔 | `.category-badge.food` |
| Transport | 🚗 | `.category-badge.transport` |
| Entertainment | 🎬 | `.category-badge.entertainment` |
| Bills | 📄 | `.category-badge.bills` |
| Shopping | 🛒 | `.category-badge.shopping` |
| Other | 📦 | `.category-badge.other` |

#### Amount Column (Always Red for Expenses)
```css
.expense-amount {
  font-family: var(--font-mono);
  font-weight: 500;
  font-size: 1rem;
  color: var(--danger);
  text-align: right;
  white-space: nowrap;
}

/* Negative sign prefix */
.expense-amount::before {
  content: '-';
}
```
**Format:** "-kr 1,234.00" (negative sign, currency, thousands separator, 2 decimals)

### Empty State
When no expenses exist yet:
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                              📭                                             │
│                                                                             │
│                     No expenses yet                                         │
│           Add your first expense using the form above                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

```css
.expense-empty {
  text-align: center;
  padding: var(--space-2xl) var(--space-lg);
}

.expense-empty-icon {
  font-size: 3rem;
  margin-bottom: var(--space-md);
  opacity: 0.5;
}

.expense-empty h3 {
  color: var(--text);
  font-size: 1.25rem;
  font-weight: 600;
  margin-bottom: var(--space-sm);
}

.expense-empty p {
  color: var(--text-muted);
  font-size: 0.9375rem;
}
```

### Responsive Design (Mobile)
On screens < 768px, stack the table as cards:

```css
@media (max-width: 768px) {
  .expense-table thead {
    display: none;
  }

  .expense-table tbody tr {
    display: block;
    background: var(--bg);
    border-radius: var(--radius-md);
    padding: var(--space-md);
    margin-bottom: var(--space-sm);
  }

  .expense-table td {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--space-xs) 0;
    border-bottom: none;
  }

  .expense-table td::before {
    content: attr(data-label);
    color: var(--text-muted);
    font-size: 0.75rem;
    text-transform: uppercase;
    font-weight: 500;
  }

  .expense-table td:last-child {
    text-align: right;
    margin-top: var(--space-sm);
    padding-top: var(--space-sm);
    border-top: 1px solid var(--surface-light);
  }
}
```

### Loading State
```css
.expense-table.loading tbody {
  opacity: 0.5;
  pointer-events: none;
}

.expense-loading {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: var(--space-2xl);
  color: var(--text-muted);
}

.expense-loading::before {
  content: '';
  width: 24px;
  height: 24px;
  border: 2px solid var(--surface-light);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-right: var(--space-sm);
}
```

---

## Delete Expense (Sprint 4)

### Updated Table Layout with Delete Button
```
┌───────────────────────────────────────────────────────────────────────────────────────┐
│  💰 Your Expenses                                                    Total: -kr 1,234│
├───────────────────────────────────────────────────────────────────────────────────────┤
│  DATE          DESCRIPTION         CATEGORY            AMOUNT           ACTION       │
├───────────────────────────────────────────────────────────────────────────────────────┤
│  Jan 21, 2026  Lunch at restaurant  [🍔 Food]          -kr 149.00       [🗑]          │
│  Jan 20, 2026  Bus ticket           [🚗 Transport]      -kr 42.00       [🗑]          │
│  Jan 19, 2026  Netflix subscription [🎬 Entertainment]  -kr 129.00      [🗑]          │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

### Updated Column Widths
With the new delete column, adjust widths:
```css
.expense-table th:nth-child(1),
.expense-table td:nth-child(1) { width: 12%; } /* Date */
.expense-table th:nth-child(2),
.expense-table td:nth-child(2) { width: 35%; } /* Description */
.expense-table th:nth-child(3),
.expense-table td:nth-child(3) { width: 18%; } /* Category */
.expense-table th:nth-child(4),
.expense-table td:nth-child(4) { width: 20%; text-align: right; } /* Amount */
.expense-table th:nth-child(5),
.expense-table td:nth-child(5) { width: 15%; text-align: center; } /* Actions */
```

### Delete Button Design
The delete button is a compact, icon-only button with danger styling:

```css
.btn-delete {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  padding: 0;
  background: transparent;
  border: 1px solid var(--surface-light);
  border-radius: var(--radius-md);
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-delete:hover {
  background: rgba(239, 68, 68, 0.15);
  border-color: var(--danger);
  color: var(--danger);
}

.btn-delete:active {
  transform: scale(0.95);
}

.btn-delete:focus {
  outline: none;
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
}
```

### Delete Button Icon (Trash)
Use SVG for crisp rendering at all sizes:
```html
<button class="btn-delete" aria-label="Delete expense" title="Delete">
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <polyline points="3 6 5 6 21 6"></polyline>
    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
    <line x1="10" y1="11" x2="10" y2="17"></line>
    <line x1="14" y1="11" x2="14" y2="17"></line>
  </svg>
</button>
```

### Confirmation Dialog
Use the browser's native `confirm()` dialog for simplicity:

**JavaScript Pattern:**
```javascript
function deleteExpense(id, description) {
  const message = description
    ? `Delete "${description}"?`
    : 'Delete this expense?';

  if (confirm(message)) {
    // Proceed with DELETE request
  }
}
```

**Dialog Text:**
- Title: "Delete expense?"
- Message: `Delete "${expense.description}"?` (or "Delete this expense?" if no description)
- Buttons: "OK" / "Cancel"

### Row Deletion Animation
When an expense is deleted, animate the row fading out and collapsing:

```css
/* Add this class via JS before removing the row */
.expense-row-deleting {
  animation: rowDelete 0.3s ease-out forwards;
}

@keyframes rowDelete {
  0% {
    opacity: 1;
    transform: translateX(0);
  }
  50% {
    opacity: 0.5;
    transform: translateX(10px);
  }
  100% {
    opacity: 0;
    transform: translateX(20px);
    height: 0;
    padding: 0;
    margin: 0;
    overflow: hidden;
  }
}
```

### Delete Loading State
Show feedback while the delete request is in progress:

```css
.btn-delete.loading {
  pointer-events: none;
  opacity: 0.5;
}

.btn-delete.loading svg {
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
```

### Success Toast for Deletion
Reuse the existing toast pattern with danger color:

```css
.toast-delete {
  position: fixed;
  bottom: 24px;
  right: 24px;
  background: var(--danger);
  color: #FFFFFF;
  padding: 16px 24px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  animation: slideIn 0.3s ease-out;
  z-index: 1000;
}

.toast-delete::before {
  content: '🗑';
}
```

**Toast Messages:**
- Success: "Expense deleted"
- Error: "Failed to delete expense. Please try again."

### Error Handling
If delete fails, show error toast and keep the row:

```css
.toast-error {
  position: fixed;
  bottom: 24px;
  right: 24px;
  background: var(--danger);
  color: #FFFFFF;
  padding: 16px 24px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  animation: slideIn 0.3s ease-out;
  z-index: 1000;
}

.toast-error::before {
  content: '⚠';
  margin-right: var(--space-sm);
}
```

### Mobile Delete Button (< 768px)
On mobile card layout, show delete button at bottom of card:

```css
@media (max-width: 768px) {
  .expense-table td[data-label="Actions"] {
    justify-content: flex-end;
    padding-top: var(--space-sm);
    border-top: 1px solid var(--surface-light);
    margin-top: var(--space-sm);
  }

  .expense-table td[data-label="Actions"]::before {
    display: none; /* Hide the "Actions" label */
  }

  .btn-delete {
    width: 100%;
    height: 40px;
    background: rgba(239, 68, 68, 0.1);
    border-color: var(--danger);
    color: var(--danger);
  }

  .btn-delete::after {
    content: ' Delete';
    margin-left: var(--space-xs);
    font-weight: 500;
  }
}
```

### Accessibility
- `aria-label="Delete expense"` on button
- `title="Delete"` for tooltip on hover
- Focus visible ring for keyboard navigation
- Confirm dialog is keyboard-accessible by default

---

## Summary Dashboard (Sprint 5)

### Dashboard Layout Overview
The summary dashboard provides a clear visual overview of spending. Place it ABOVE the expense list table.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          📊 Expense Summary                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                                                                       │  │
│  │                         TOTAL EXPENSES                                │  │
│  │                                                                       │  │
│  │                       kr 12,345.00                                    │  │
│  │                                                                       │  │
│  │                      ▼ 6 expenses                                     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  CATEGORY BREAKDOWN                                                     ││
│  │                                                                         ││
│  │  🍔 Food           ████████████████████░░░░░░░░  kr 3,450  (28%)       ││
│  │  📄 Bills          ██████████████░░░░░░░░░░░░░░  kr 2,890  (23%)       ││
│  │  🛒 Shopping       █████████████░░░░░░░░░░░░░░░  kr 2,540  (21%)       ││
│  │  🚗 Transport      ████████░░░░░░░░░░░░░░░░░░░░  kr 1,820  (15%)       ││
│  │  🎬 Entertainment  █████░░░░░░░░░░░░░░░░░░░░░░░  kr 1,200  (10%)       ││
│  │  📦 Other          ███░░░░░░░░░░░░░░░░░░░░░░░░░  kr 445    (4%)        ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### Summary Card Container
```css
.summary-dashboard {
  background: var(--surface);
  border-radius: var(--radius-lg);
  padding: var(--space-lg);
  box-shadow: var(--shadow-md);
  margin-bottom: var(--space-lg);
}

.summary-header {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  margin-bottom: var(--space-lg);
}

.summary-header h2 {
  color: var(--text);
  font-size: 1.5rem;
  font-weight: 600;
}
```

### Total Expenses Display (Hero Number)
The total is the most prominent element - large, centered, and eye-catching:

```css
.total-card {
  background: linear-gradient(135deg, rgba(13, 148, 136, 0.15) 0%, rgba(13, 148, 136, 0.05) 100%);
  border: 1px solid rgba(13, 148, 136, 0.3);
  border-radius: var(--radius-lg);
  padding: var(--space-xl);
  text-align: center;
  margin-bottom: var(--space-lg);
}

.total-label {
  color: var(--text-muted);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: var(--space-sm);
}

.total-amount {
  font-family: var(--font-mono);
  font-size: 3rem;
  font-weight: 700;
  color: var(--danger);
  line-height: 1.1;
  margin-bottom: var(--space-sm);
}

/* Responsive: smaller on mobile */
@media (max-width: 640px) {
  .total-amount {
    font-size: 2.25rem;
  }
}

.total-count {
  color: var(--text-muted);
  font-size: 0.875rem;
}

.total-count::before {
  content: '▼ ';
  font-size: 0.625rem;
  opacity: 0.7;
}
```

**Format:** "kr 12,345.00" (currency symbol, thousands separator, 2 decimals)

### Category Breakdown Section

#### Section Header
```css
.breakdown-section {
  margin-top: var(--space-lg);
}

.breakdown-header {
  color: var(--text-muted);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: var(--space-md);
}
```

#### Category Bar Item
Each category shows: icon, name, progress bar, amount, percentage

```css
.category-row {
  display: grid;
  grid-template-columns: 140px 1fr 100px 60px;
  align-items: center;
  gap: var(--space-md);
  padding: var(--space-sm) 0;
}

/* Mobile: stack vertically */
@media (max-width: 640px) {
  .category-row {
    grid-template-columns: 1fr auto;
    grid-template-rows: auto auto;
    gap: var(--space-xs) var(--space-md);
  }

  .category-bar-container {
    grid-column: 1 / -1;
  }
}

.category-name {
  display: flex;
  align-items: center;
  gap: var(--space-sm);
  color: var(--text);
  font-size: 0.9375rem;
  font-weight: 500;
}

.category-icon {
  font-size: 1rem;
}

.category-bar-container {
  height: 8px;
  background: var(--bg);
  border-radius: var(--radius-full);
  overflow: hidden;
}

.category-bar {
  height: 100%;
  border-radius: var(--radius-full);
  transition: width 0.5s ease-out;
}

/* Category bar colors - match existing badge colors */
.category-bar.food { background: #FEF3C7; }
.category-bar.transport { background: #DBEAFE; }
.category-bar.entertainment { background: #F3E8FF; }
.category-bar.bills { background: #FEE2E2; }
.category-bar.shopping { background: #D1FAE5; }
.category-bar.other { background: #E2E8F0; }

.category-amount {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text);
  text-align: right;
}

.category-percent {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--text-muted);
  text-align: right;
}
```

### Category Order
Sort categories by amount (highest first):

| Rank | Category | Icon |
|------|----------|------|
| 1 | (highest) | Dynamic |
| 2 | ... | ... |
| ... | ... | ... |
| n | (lowest) | Dynamic |

Only show categories that have expenses (hide zero-value categories).

### Empty State (No Expenses)
When there are no expenses yet:

```css
.summary-empty {
  text-align: center;
  padding: var(--space-xl);
  color: var(--text-muted);
}

.summary-empty-icon {
  font-size: 2.5rem;
  margin-bottom: var(--space-md);
  opacity: 0.5;
}

.summary-empty h3 {
  color: var(--text);
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: var(--space-xs);
}

.summary-empty p {
  font-size: 0.875rem;
}
```

```
┌─────────────────────────────────────────┐
│                                         │
│                 📊                       │
│                                         │
│       No expenses to summarize          │
│     Add your first expense below        │
│                                         │
└─────────────────────────────────────────┘
```

### Loading State
```css
.summary-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--space-2xl);
  color: var(--text-muted);
}

.summary-loading::before {
  content: '';
  width: 32px;
  height: 32px;
  border: 3px solid var(--surface-light);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-bottom: var(--space-md);
}
```

### Animation for Bar Chart on Load
Bars animate from 0 to their target width when the page loads:

```css
.category-bar {
  width: 0;
  animation: barGrow 0.8s ease-out forwards;
}

/* Apply staggered delay via JS: style="animation-delay: 0.1s" etc */
@keyframes barGrow {
  from { width: 0; }
  to { width: var(--bar-width); } /* Set via inline style */
}
```

**JavaScript pattern:**
```javascript
// Set the bar width via CSS custom property
categoryBars.forEach((bar, index) => {
  const percent = (categoryAmount / totalAmount) * 100;
  bar.style.setProperty('--bar-width', `${percent}%`);
  bar.style.animationDelay = `${index * 0.1}s`;
});
```

### Responsive Layout

#### Desktop (> 768px)
- Full horizontal bars with all columns visible
- Total amount at 3rem

#### Tablet (640px - 768px)
- Same layout, slightly compressed
- Total amount at 2.5rem

#### Mobile (< 640px)
- Category rows become 2-line: name + amount on top, bar below
- Total amount at 2.25rem
- Percentages shown inline with amount

```css
@media (max-width: 640px) {
  .summary-dashboard {
    padding: var(--space-md);
  }

  .total-card {
    padding: var(--space-lg);
  }

  .category-row {
    grid-template-columns: 1fr auto;
    padding: var(--space-sm) 0;
  }

  .category-bar-container {
    grid-column: 1 / -1;
    margin-top: var(--space-xs);
  }

  .category-percent {
    display: inline;
    margin-left: var(--space-xs);
    opacity: 0.7;
  }
}
```

### Accessibility
- Use `role="img"` and `aria-label` for the bar chart: `aria-label="Food: 28% of total"`
- Ensure sufficient color contrast on progress bars
- Provide text alternatives for all visual data

### HTML Structure Example
```html
<section class="summary-dashboard" aria-labelledby="summary-title">
  <div class="summary-header">
    <h2 id="summary-title">📊 Expense Summary</h2>
  </div>

  <div class="total-card">
    <div class="total-label">Total Expenses</div>
    <div class="total-amount">kr 12,345.00</div>
    <div class="total-count">6 expenses</div>
  </div>

  <div class="breakdown-section">
    <h3 class="breakdown-header">Category Breakdown</h3>

    <div class="category-row">
      <div class="category-name">
        <span class="category-icon">🍔</span>
        <span>Food</span>
      </div>
      <div class="category-bar-container">
        <div class="category-bar food" style="--bar-width: 28%" role="img" aria-label="Food: 28% of total"></div>
      </div>
      <div class="category-amount">kr 3,450</div>
      <div class="category-percent">(28%)</div>
    </div>

    <!-- Repeat for other categories... -->
  </div>
</section>
```

---

## UX Guidelines

1. **Contrast:** All text meets WCAG AA (4.5:1 minimum)
2. **Touch targets:** Minimum 44x44px for all interactive elements
3. **Feedback:**
   - Buttons have hover/active states
   - Inputs have focus rings
   - Loading states for async actions
4. **Currency format:** Always show 2 decimal places, use locale formatting
5. **Dates:** Display as "Jan 21, 2026" format for readability
6. **Empty states:** Show helpful message when no expenses exist

---

## CSS Variables (copy to your stylesheet)

```css
:root {
  /* Colors */
  --primary: #0D9488;
  --primary-dark: #0F766E;
  --primary-light: #5EEAD4;
  --bg: #0F172A;
  --surface: #1E293B;
  --surface-light: #334155;
  --text: #F1F5F9;
  --text-muted: #94A3B8;
  --success: #22C55E;
  --danger: #EF4444;
  --warning: #F59E0B;

  /* Typography */
  --font-sans: 'Inter', system-ui, -apple-system, sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;
  --space-2xl: 48px;

  /* Border Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.3);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.4);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.5);
}
```
