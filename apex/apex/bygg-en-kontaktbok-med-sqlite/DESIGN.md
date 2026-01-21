# Design System - Contact Book

A clean, modern, minimal design for a contact management app. Inspired by 2025 UI trends: generous whitespace, subtle shadows, and a calming teal accent.

## Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| primary | #0D9488 | Buttons, links, active states |
| primary-hover | #0F766E | Button hover, link hover |
| primary-light | #CCFBF1 | Selected rows, badges |
| background | #F8FAFC | Page background |
| surface | #FFFFFF | Cards, modals, inputs |
| border | #E2E8F0 | Borders, dividers |
| text | #1E293B | Body text, headings |
| text-muted | #64748B | Secondary text, placeholders |
| danger | #EF4444 | Delete buttons, errors |
| danger-hover | #DC2626 | Delete hover |
| success | #10B981 | Success messages |

## Typography

- **Font Family:** Inter (Google Fonts)
- **Fallback:** -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| h1 | 28px | 700 | 1.2 |
| h2 | 22px | 600 | 1.3 |
| h3 | 18px | 600 | 1.4 |
| body | 15px | 400 | 1.5 |
| small | 13px | 400 | 1.4 |
| label | 14px | 500 | 1.4 |

## Spacing Scale

Base unit: 4px

| Name | Value | Usage |
|------|-------|-------|
| xs | 4px | Icon gaps |
| sm | 8px | Tight spacing |
| md | 16px | Default padding |
| lg | 24px | Section spacing |
| xl | 32px | Card padding |
| 2xl | 48px | Page margins |

## Border Radius

| Name | Value | Usage |
|------|-------|-------|
| sm | 4px | Small buttons, badges |
| md | 8px | Inputs, buttons |
| lg | 12px | Cards, modals |
| full | 9999px | Avatar circles |

## Shadows

```css
/* Card shadow */
shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);

/* Elevated elements */
shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1),
           0 2px 4px -2px rgba(0, 0, 0, 0.1);

/* Modals, dropdowns */
shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1),
           0 4px 6px -4px rgba(0, 0, 0, 0.1);
```

## Components

### Buttons

**Primary Button**
```css
background: #0D9488;
color: white;
padding: 10px 20px;
border-radius: 8px;
font-weight: 500;
transition: background 0.15s;
/* Hover: background #0F766E */
```

**Secondary Button**
```css
background: #FFFFFF;
color: #1E293B;
border: 1px solid #E2E8F0;
padding: 10px 20px;
border-radius: 8px;
/* Hover: background #F8FAFC */
```

**Danger Button**
```css
background: #EF4444;
color: white;
padding: 10px 20px;
border-radius: 8px;
/* Hover: background #DC2626 */
```

**Icon Button (small)**
```css
padding: 8px;
border-radius: 8px;
/* For edit/delete icons */
```

### Inputs

```css
background: #FFFFFF;
border: 1px solid #E2E8F0;
border-radius: 8px;
padding: 10px 14px;
font-size: 15px;
color: #1E293B;
/* Focus: border-color #0D9488, box-shadow 0 0 0 3px rgba(13,148,136,0.15) */
/* Placeholder: color #64748B */
```

### Cards

```css
background: #FFFFFF;
border-radius: 12px;
padding: 24px;
box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
border: 1px solid #E2E8F0;
```

### Contact List Item

```css
padding: 16px;
border-bottom: 1px solid #E2E8F0;
display: flex;
align-items: center;
gap: 16px;
/* Hover: background #F8FAFC */
```

**Avatar Circle**
```css
width: 44px;
height: 44px;
border-radius: 9999px;
background: #CCFBF1;
color: #0D9488;
display: flex;
align-items: center;
justify-content: center;
font-weight: 600;
font-size: 16px;
/* Show initials, e.g. "JD" for John Doe */
```

### Search Bar

```css
position: relative;
/* Search icon positioned inside left */
input {
  padding-left: 44px; /* space for icon */
  width: 100%;
}
```

### Empty State

```css
text-align: center;
padding: 48px 24px;
color: #64748B;
/* Icon: 48px, muted color */
/* Text: "Inga kontakter \u00e4n" */
/* Subtext: "L\u00e4gg till din f\u00f6rsta kontakt ovan" */
```

### Modal / Dialog

```css
background: #FFFFFF;
border-radius: 12px;
padding: 24px;
box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
max-width: 480px;
/* Backdrop: rgba(0, 0, 0, 0.5) */
```

## Layout

### Page Structure

```
+------------------------------------------+
|  Header: "Kontaktbok"          [+ L\u00e4gg till] |
+------------------------------------------+
|  [Search bar                         \U0001F50D]  |
+------------------------------------------+
|                                          |
|  Contact Card                            |
|  +--------------------------------------+|
|  | Avatar | Name           [Edit][Del] ||
|  |   JD   | john@email.com             ||
|  |        | 070-123 45 67              ||
|  +--------------------------------------+|
|                                          |
|  Contact Card                            |
|  +--------------------------------------+|
|  | ...                                  ||
|  +--------------------------------------+|
|                                          |
+------------------------------------------+
```

### Add/Edit Form

```
+------------------------------------------+
|  L\u00e4gg till kontakt              [\u2715 St\u00e4ng]  |
+------------------------------------------+
|                                          |
|  Namn *                                  |
|  [________________________________]      |
|                                          |
|  Telefon                                 |
|  [________________________________]      |
|                                          |
|  E-post                                  |
|  [________________________________]      |
|                                          |
|  Anteckningar                            |
|  [________________________________]      |
|  [________________________________]      |
|                                          |
|  [Avbryt]              [Spara kontakt]   |
|                                          |
+------------------------------------------+
```

### Responsive Breakpoints

| Breakpoint | Width | Adjustments |
|------------|-------|-------------|
| Mobile | < 640px | Full-width cards, stacked buttons |
| Tablet | 640-1024px | Max-width 600px centered |
| Desktop | > 1024px | Max-width 800px centered |

## UX Guidelines

### Accessibility
- Minimum contrast ratio: 4.5:1 for text
- Touch targets: minimum 44x44px
- Focus states: visible ring on all interactive elements
- Labels on all form inputs

### Interactions
- Hover states on all clickable elements
- Loading spinner during API calls
- Success/error feedback after actions
- Confirm dialog before delete

### Copy (Swedish)
- Page title: "Kontaktbok"
- Add button: "L\u00e4gg till"
- Save button: "Spara"
- Cancel button: "Avbryt"
- Delete button: "Ta bort"
- Edit button: "Redigera"
- Search placeholder: "S\u00f6k kontakter..."
- Empty state: "Inga kontakter \u00e4nnu"
- Delete confirm: "\u00c4r du s\u00e4ker p\u00e5 att du vill ta bort denna kontakt?"
- Required field: "* Obligatoriskt"
- Error messages: "Namn \u00e4r obligatoriskt", "Ogiltig e-postadress"

## Icons

Use Lucide Icons (or similar minimal line icons):
- Search: `search`
- Add: `plus`
- Edit: `pencil`
- Delete: `trash-2`
- Close: `x`
- Phone: `phone`
- Email: `mail`
- Notes: `sticky-note`
- User: `user`
- Check: `check` (success)
- Alert: `alert-circle` (error)
- Warning: `alert-triangle` (warning)

---

## Sprint 2: Edit Contact Feature

### Edit Mode States

**Edit Button (in contact card)**
```css
/* Icon button style */
background: transparent;
color: #64748B;
padding: 8px;
border-radius: 8px;
transition: all 0.15s;

/* Hover */
background: #F1F5F9;
color: #0D9488;
```

**Modal Title - Edit vs Add**
```
Add mode:    "Lägg till kontakt"
Edit mode:   "Redigera kontakt"
```

**Edit Mode Indicator**
- Modal header shows contact name being edited
- Save button text changes: "Spara" (for both add/edit)
- Form fields pre-filled with existing data

### Form Validation States

**Color Palette - Validation**
| State | Border | Background | Text |
|-------|--------|------------|------|
| Default | #E2E8F0 | #FFFFFF | #1E293B |
| Focus | #0D9488 | #FFFFFF | #1E293B |
| Error | #EF4444 | #FEF2F2 | #1E293B |
| Success | #10B981 | #FFFFFF | #1E293B |

**Error Input State**
```css
border: 1px solid #EF4444;
background: #FEF2F2;
/* Focus ring */
box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.15);
```

**Success Input State** (use sparingly - only for validated email/phone)
```css
border: 1px solid #10B981;
/* Focus ring */
box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.15);
```

**Required Field Indicator**
```css
/* Asterisk after label */
.required::after {
  content: " *";
  color: #EF4444;
}

/* Legend at top of form */
.required-legend {
  font-size: 13px;
  color: #64748B;
  margin-bottom: 16px;
}
/* Text: "* Obligatoriskt fält" */
```

**Inline Error Message**
```css
color: #EF4444;
font-size: 13px;
margin-top: 4px;
display: flex;
align-items: center;
gap: 4px;
/* Icon: alert-circle, 14px */
```

**Error Message Copy (Swedish)**
| Field | Error Message |
|-------|---------------|
| Name (empty) | "Namn är obligatoriskt" |
| Email (invalid) | "Ogiltig e-postadress" |
| Phone (invalid) | "Ogiltigt telefonnummer" |

**Form Layout with Validation**
```
+------------------------------------------+
|  Redigera kontakt                   [✕]  |
+------------------------------------------+
|  * Obligatoriskt fält                    |
|                                          |
|  Namn *                                  |
|  [________________________________] ❌   |
|  ⚠ Namn är obligatoriskt                 |
|                                          |
|  Telefon                                 |
|  [________________________________] ✓    |
|                                          |
|  E-post                                  |
|  [________________________________]      |
|                                          |
|  Anteckningar                            |
|  [________________________________]      |
|                                          |
|  [Avbryt]              [Spara]           |
+------------------------------------------+
```

### Toast Notifications

**Toast Container Position**
```css
position: fixed;
bottom: 24px;
right: 24px;
z-index: 1000;
display: flex;
flex-direction: column;
gap: 8px;

/* Mobile: center bottom */
@media (max-width: 640px) {
  left: 16px;
  right: 16px;
  bottom: 16px;
}
```

**Toast Base Style**
```css
display: flex;
align-items: center;
gap: 12px;
padding: 14px 16px;
border-radius: 8px;
box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1),
            0 2px 4px -2px rgba(0, 0, 0, 0.1);
font-size: 14px;
font-weight: 500;
min-width: 280px;
max-width: 400px;
animation: slideIn 0.2s ease-out;
```

**Toast Types**

| Type | Background | Border | Icon Color | Icon |
|------|------------|--------|------------|------|
| Success | #ECFDF5 | 1px solid #10B981 | #10B981 | check |
| Error | #FEF2F2 | 1px solid #EF4444 | #EF4444 | alert-circle |
| Warning | #FFFBEB | 1px solid #F59E0B | #F59E0B | alert-triangle |

**Success Toast**
```css
background: #ECFDF5;
border: 1px solid #10B981;
color: #065F46;
/* Icon: check, color #10B981 */
/* Auto-dismiss: 3 seconds */
```

**Error Toast**
```css
background: #FEF2F2;
border: 1px solid #EF4444;
color: #991B1B;
/* Icon: alert-circle, color #EF4444 */
/* NO auto-dismiss - requires manual close */
```

**Warning Toast**
```css
background: #FFFBEB;
border: 1px solid #F59E0B;
color: #92400E;
/* Icon: alert-triangle, color #F59E0B */
/* Auto-dismiss: 5 seconds */
```

**Toast Animation**
```css
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

@keyframes slideOut {
  from {
    transform: translateX(0);
    opacity: 1;
  }
  to {
    transform: translateX(100%);
    opacity: 0;
  }
}
```

**Toast Close Button**
```css
margin-left: auto;
padding: 4px;
background: transparent;
border: none;
color: inherit;
opacity: 0.6;
cursor: pointer;
/* Hover: opacity 1 */
```

**Toast Messages (Swedish)**
| Action | Type | Message |
|--------|------|---------|
| Contact saved | Success | "Kontakten har sparats" |
| Contact updated | Success | "Kontakten har uppdaterats" |
| Contact deleted | Success | "Kontakten har tagits bort" |
| Save failed | Error | "Kunde inte spara kontakten" |
| Delete failed | Error | "Kunde inte ta bort kontakten" |
| Network error | Error | "Nätverksfel - försök igen" |

**Toast Layout**
```
+------------------------------------------+
| ✓  Kontakten har sparats            [✕]  |
+------------------------------------------+

+------------------------------------------+
| ⚠  Kunde inte spara kontakten       [✕]  |
|    Kontrollera fälten och försök igen    |
+------------------------------------------+
```

### Edit Flow UX

1. **Click Edit** → Modal opens with pre-filled data
2. **Validation** → Inline, on blur (not on every keystroke)
3. **Submit** → Loading state on button, disable form
4. **Success** → Close modal, show success toast, refresh list
5. **Error** → Show error toast, keep modal open, highlight invalid fields

---

## Sprint 3: Delete Contact + Polish

### Delete Confirmation Modal

A critical action modal that requires explicit user confirmation before permanently removing a contact.

**Modal Structure**
```css
/* Inherits base modal styles */
background: #FFFFFF;
border-radius: 12px;
padding: 24px;
box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
max-width: 400px;
text-align: center;
```

**Danger Icon (Warning)**
```css
width: 48px;
height: 48px;
margin: 0 auto 16px;
background: #FEF2F2;
border-radius: 9999px;
display: flex;
align-items: center;
justify-content: center;
/* Icon: alert-triangle or trash-2, 24px, color #EF4444 */
```

**Modal Title**
```css
font-size: 18px;
font-weight: 600;
color: #1E293B;
margin-bottom: 8px;
/* Text: "Ta bort kontakt" */
```

**Confirmation Message**
```css
font-size: 15px;
color: #64748B;
margin-bottom: 24px;
line-height: 1.5;
/* Text: "Är du säker på att du vill ta bort [Kontaktnamn]?" */
/* Contact name in bold: font-weight 600, color #1E293B */
```

**Button Group**
```css
display: flex;
gap: 12px;
justify-content: center;
/* Mobile: flex-direction column-reverse */
```

**Delete Confirmation Modal Layout**
```
+------------------------------------------+
|                   [✕]                    |
|                                          |
|              ⚠️ (danger icon)             |
|                                          |
|            Ta bort kontakt               |
|                                          |
|    Är du säker på att du vill ta bort    |
|              **Anna Svensson**?          |
|                                          |
|    Denna åtgärd kan inte ångras.         |
|                                          |
|      [Avbryt]        [Ta bort]           |
|                                          |
+------------------------------------------+
```

**Copy (Swedish)**
| Element | Text |
|---------|------|
| Title | "Ta bort kontakt" |
| Message | "Är du säker på att du vill ta bort {name}?" |
| Warning | "Denna åtgärd kan inte ångras." |
| Cancel | "Avbryt" |
| Confirm | "Ta bort" |

### Enhanced Danger Button

**Danger Button - Default**
```css
background: #EF4444;
color: #FFFFFF;
padding: 10px 20px;
border-radius: 8px;
font-weight: 500;
font-size: 15px;
border: none;
cursor: pointer;
transition: all 0.15s ease;
```

**Danger Button - Hover**
```css
background: #DC2626;
box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
```

**Danger Button - Focus**
```css
outline: none;
box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.3);
```

**Danger Button - Active/Pressed**
```css
background: #B91C1C;
transform: scale(0.98);
```

**Danger Button - Disabled**
```css
background: #FCA5A5;
cursor: not-allowed;
opacity: 0.7;
```

**Danger Button - Loading**
```css
/* Same as disabled + spinner */
background: #EF4444;
cursor: wait;
/* Add spinner icon, 16px, white */
```

**Icon Delete Button (in contact card)**
```css
background: transparent;
color: #64748B;
padding: 8px;
border-radius: 8px;
border: none;
cursor: pointer;
transition: all 0.15s;

/* Hover */
background: #FEF2F2;
color: #EF4444;
```

### Enhanced Empty State

**Container**
```css
text-align: center;
padding: 64px 24px;
background: #FFFFFF;
border-radius: 12px;
border: 2px dashed #E2E8F0;
margin: 24px 0;
```

**Icon**
```css
width: 80px;
height: 80px;
margin: 0 auto 24px;
background: #F1F5F9;
border-radius: 9999px;
display: flex;
align-items: center;
justify-content: center;
/* Icon: users or user-plus, 40px, color #94A3B8 */
```

**Title**
```css
font-size: 18px;
font-weight: 600;
color: #1E293B;
margin-bottom: 8px;
/* Text: "Inga kontakter ännu" */
```

**Description**
```css
font-size: 15px;
color: #64748B;
margin-bottom: 24px;
max-width: 300px;
margin-left: auto;
margin-right: auto;
/* Text: "Lägg till din första kontakt för att komma igång" */
```

**CTA Button (optional)**
```css
/* Primary button style */
background: #0D9488;
color: white;
padding: 10px 20px;
border-radius: 8px;
font-weight: 500;
display: inline-flex;
align-items: center;
gap: 8px;
/* Icon: plus, 18px */
/* Text: "Lägg till kontakt" */
```

**Empty State Layout**
```
+------------------------------------------+
|                                          |
|         +------------------------+       |
|         |                        |       |
|         |     👥 (icon circle)   |       |
|         |                        |       |
|         +------------------------+       |
|                                          |
|          Inga kontakter ännu             |
|                                          |
|    Lägg till din första kontakt för      |
|           att komma igång                |
|                                          |
|         [+ Lägg till kontakt]            |
|                                          |
+------------------------------------------+
```

**Copy (Swedish)**
| Element | Text |
|---------|------|
| Title | "Inga kontakter ännu" |
| Description | "Lägg till din första kontakt för att komma igång" |
| CTA | "Lägg till kontakt" |

### Delete Flow UX

1. **Click Delete** → Confirmation modal opens with contact name
2. **Confirm** → Loading state on button, disable form
3. **Success** → Close modal, show success toast, remove from list
4. **Error** → Show error toast, keep modal open

### Delete Animation (Optional Enhancement)

**Fade Out on Delete**
```css
@keyframes fadeOutDelete {
  from {
    opacity: 1;
    transform: translateX(0);
    max-height: 100px;
  }
  to {
    opacity: 0;
    transform: translateX(-20px);
    max-height: 0;
    padding: 0;
    margin: 0;
  }
}

.contact-deleting {
  animation: fadeOutDelete 0.3s ease-out forwards;
}
```

### Backdrop

**Modal Backdrop**
```css
position: fixed;
inset: 0;
background: rgba(0, 0, 0, 0.5);
backdrop-filter: blur(2px);
z-index: 999;
animation: fadeIn 0.15s ease-out;
```

```css
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
```
