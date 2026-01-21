# Design System - Kontaktbok

## Design Philosophy
This design system embraces Scandinavian minimalism with warm, modern touches inspired by 2026 UI trends. The palette uses soft, natural tones that feel approachable and calm, perfect for a Swedish contact management app. Focus on clarity, generous spacing, and purposeful interactions.

## Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| primary | #5B7C99 | Primary buttons, active links, focus states |
| secondary | #7D9BB5 | Hover states, secondary actions |
| accent | #D4A574 | Success messages, highlights, warm accents |
| background | #F7F5F2 | Page background (warm off-white) |
| surface | #FFFFFF | Cards, modals, raised surfaces |
| text | #2D3142 | Primary text, headings |
| text-muted | #6B7280 | Secondary text, descriptions, placeholders |
| border | #E5E7EB | Input borders, dividers, subtle lines |
| error | #C4756E | Error messages, delete actions |
| success | #8FAA92 | Success confirmations |

**Color Philosophy**: Soft blues evoke trust and calm (Swedish flag connection), warm beige accent adds approachability, neutral warm background reduces eye strain.

## Typography
- **Headings:** 'Inter', weight 600-700
- **Body:** 'Inter', weight 400-500
- **Mono:** 'JetBrains Mono' (for email addresses, phone numbers)

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| h1 | 32px | 700 | 1.2 |
| h2 | 24px | 600 | 1.3 |
| h3 | 20px | 600 | 1.4 |
| body | 16px | 400 | 1.6 |
| small | 14px | 400 | 1.5 |
| mono | 14px | 500 | 1.5 |

**Font Loading**: Use Google Fonts or system fallback:
```css
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
```

## Spacing
Base: 4px (0.25rem)

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Tight spacing, inline elements |
| sm | 8px | Small gaps, icon spacing |
| md | 16px | Standard element spacing |
| lg | 24px | Section padding, card padding |
| xl | 32px | Page padding, large gaps |
| 2xl | 48px | Section margins |
| 3xl | 64px | Hero spacing, major sections |

## Border Radius
| Token | Value | Usage |
|-------|-------|-------|
| sm | 4px | Inputs, small elements |
| md | 8px | Buttons, badges |
| lg | 12px | Cards, modals |
| xl | 16px | Large containers |
| full | 9999px | Pills, avatars |

## Shadows
```css
/* Card shadow - soft, subtle */
shadow-card: 0 2px 8px rgba(45, 49, 66, 0.08);

/* Button hover - gentle lift */
shadow-hover: 0 4px 12px rgba(45, 49, 66, 0.12);

/* Modal/Dropdown - more pronounced */
shadow-modal: 0 8px 24px rgba(45, 49, 66, 0.16);
```

## Components

### Buttons
**Primary Button**
```css
background: #5B7C99
color: #FFFFFF
padding: 12px 24px
border-radius: 8px
font-weight: 500
font-size: 16px

hover: background #7D9BB5
active: background #4A6380
focus: ring 2px #5B7C99 with 50% opacity
```

**Secondary Button**
```css
background: #FFFFFF
color: #2D3142
border: 2px solid #E5E7EB
padding: 12px 24px
border-radius: 8px
font-weight: 500

hover: border-color #5B7C99, background #F7F5F2
```

**Danger Button** (for delete actions)
```css
background: #C4756E
color: #FFFFFF
padding: 12px 24px
border-radius: 8px

hover: background #B06559
```

**Minimum touch target**: 44x44px (WCAG 2.1)

### Cards
**Contact Card**
```css
background: #FFFFFF
border-radius: 12px
padding: 24px
box-shadow: 0 2px 8px rgba(45, 49, 66, 0.08)

hover: box-shadow 0 4px 12px rgba(45, 49, 66, 0.12)
transition: all 0.2s ease
```

**Empty State Card**
```css
background: #FFFFFF
border: 2px dashed #E5E7EB
border-radius: 12px
padding: 48px 24px
text-align: center
color: #6B7280
```

### Inputs
**Text Input / Search**
```css
background: #FFFFFF
border: 2px solid #E5E7EB
border-radius: 4px
padding: 10px 16px
font-size: 16px
color: #2D3142

placeholder: color #6B7280

focus:
  border-color #5B7C99
  ring 2px #5B7C99 with 20% opacity
  outline: none

error:
  border-color #C4756E
```

**Form Label**
```css
font-size: 14px
font-weight: 500
color: #2D3142
margin-bottom: 8px
```

**Error Message**
```css
font-size: 14px
color: #C4756E
margin-top: 4px
```

### Lists
**Contact List**
```css
display: grid
gap: 16px
grid-template-columns: 1fr

@media (min-width: 768px):
  grid-template-columns: repeat(2, 1fr)

@media (min-width: 1024px):
  grid-template-columns: repeat(3, 1fr)
```

### Header
```css
background: #FFFFFF
border-bottom: 1px solid #E5E7EB
padding: 24px 32px
box-shadow: 0 1px 3px rgba(45, 49, 66, 0.04)
```

## Layout
**Container**
```css
max-width: 1200px
margin: 0 auto
padding: 32px 16px

@media (min-width: 768px):
  padding: 48px 32px
```

**Page Structure**
```
┌─────────────────────────────────┐
│ Header (sticky)                 │
├─────────────────────────────────┤
│                                 │
│  Container                      │
│   ┌─────────────────────────┐  │
│   │ Search Bar              │  │
│   ├─────────────────────────┤  │
│   │ Add Contact Form        │  │
│   ├─────────────────────────┤  │
│   │ Contact Grid            │  │
│   │  [Card] [Card] [Card]   │  │
│   │  [Card] [Card] [Card]   │  │
│   └─────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

## UX Principles

### Accessibility
- **Contrast ratio**: Minimum 4.5:1 for body text, 3:1 for large text (WCAG AA)
- **Touch targets**: Minimum 44x44px for all interactive elements
- **Focus indicators**: Visible 2px ring on all focusable elements
- **Keyboard navigation**: Full keyboard support (Tab, Enter, Esc)
- **Screen readers**: Semantic HTML, ARIA labels where needed

### Responsive Design
Mobile-first approach with breakpoints:
- **Mobile**: < 640px (1 column)
- **Tablet**: 640px - 1023px (2 columns)
- **Desktop**: 1024px+ (3 columns)

### Micro-interactions
- **Button hover**: 0.2s ease transition
- **Card hover**: Subtle shadow lift (0.2s)
- **Input focus**: Border color + ring animation (0.15s)
- **Form submission**: Loading spinner + disabled state
- **Success/Error**: Toast notification with slide-in animation

### Empty States
When no contacts exist:
```
📇

Inga kontakter än

Lägg till din första kontakt med formuläret ovan.
```

### Loading States
```
Laddar kontakter...
[Spinner animation]
```

### Error States
```
❌ Ett fel uppstod

Kunde inte ladda kontakter. Försök igen.
[Försök igen-knapp]
```

## Swedish Language UI (Svensk UI)
- Use Swedish labels: "Lägg till", "Sök", "Radera"
- Friendly empty states in Swedish
- Error messages in Swedish
- Date format: YYYY-MM-DD (ISO 8601)

## Performance
- **Load time target**: < 2 seconds on 3G
- **Minimize assets**: Use system fonts as fallback
- **Lazy load**: Images and non-critical components
- **Debounce search**: 300ms delay on search input

---

## Quick Reference for Frontend

**Primary Action**: `bg-[#5B7C99] text-white py-3 px-6 rounded-lg hover:bg-[#7D9BB5]`

**Input**: `bg-white border-2 border-[#E5E7EB] rounded px-4 py-2 focus:border-[#5B7C99]`

**Card**: `bg-white rounded-xl p-6 shadow-[0_2px_8px_rgba(45,49,66,0.08)]`

**Container**: `max-w-[1200px] mx-auto px-4 py-8 md:px-8 md:py-12`

---

---

## Sprint 2: Add Contact Form Design

### Add Contact Form Layout

**Form Container**
```css
background: #FFFFFF
border-radius: 12px
padding: 32px
box-shadow: 0 2px 8px rgba(45, 49, 66, 0.08)
margin-bottom: 32px
```

**Form Fields Stack**
```css
display: flex
flex-direction: column
gap: 20px
```

**Field Group Structure**
```
┌─────────────────────────────────┐
│ Label (required indicator)      │
│ ┌─────────────────────────────┐ │
│ │ Input field                 │ │
│ └─────────────────────────────┘ │
│ Error message (if invalid)      │
└─────────────────────────────────┘
```

### Form Field Specifications

**Label with Required Indicator**
```css
font-size: 14px
font-weight: 500
color: #2D3142
margin-bottom: 8px
display: block

/* Required asterisk */
.required::after {
  content: " *"
  color: #C4756E
}
```

**Input Fields**
```css
/* Name Input (required) */
background: #FFFFFF
border: 2px solid #E5E7EB
border-radius: 4px
padding: 12px 16px
font-size: 16px
color: #2D3142
width: 100%
min-height: 44px /* WCAG touch target */

placeholder: {
  color: #6B7280
  font-style: normal
}

/* Email Input (optional but validated) */
/* Same styling as name */
font-family: 'JetBrains Mono', monospace /* for email addresses */

/* Phone Input (optional) */
/* Same styling as name */
font-family: 'JetBrains Mono', monospace /* for phone numbers */
```

**Input States - Normal**
```css
default:
  border: 2px solid #E5E7EB

focus:
  border-color: #5B7C99
  box-shadow: 0 0 0 3px rgba(91, 124, 153, 0.15)
  outline: none
  transition: all 0.15s ease
```

**Input States - Validation**
```css
/* Valid (after user leaves field) */
.input-valid {
  border-color: #8FAA92
}

.input-valid:focus {
  border-color: #8FAA92
  box-shadow: 0 0 0 3px rgba(143, 170, 146, 0.15)
}

/* Invalid (after user leaves field) */
.input-invalid {
  border-color: #C4756E
}

.input-invalid:focus {
  border-color: #C4756E
  box-shadow: 0 0 0 3px rgba(196, 117, 110, 0.15)
}
```

### Form Validation - Inline Feedback

**Validation Timing**
- **NO validation while user is typing** (don't disrupt flow)
- **Validate on blur** (when user leaves field)
- **Real-time error removal** (as soon as input becomes valid)
- **Full validation on submit** (catch any missed fields)

**Error Message**
```css
font-size: 14px
color: #C4756E
margin-top: 6px
display: flex
align-items: center
gap: 6px
animation: slideDown 0.2s ease

/* Error icon (optional) */
.error-icon {
  width: 16px
  height: 16px
}
```

**Validation Rules**
- **Name (required)**: "Namn är obligatoriskt"
- **Email (optional)**: "Ogiltig e-postadress" (if entered but invalid format)
- **Phone (optional)**: No validation (accept any format)

**Example Error Messages (Swedish)**
```
❌ Namn är obligatoriskt
❌ Ogiltig e-postadress (exempel: namn@example.com)
```

### Submit Button

**Primary Submit Button**
```css
background: #5B7C99
color: #FFFFFF
border: none
border-radius: 8px
padding: 14px 32px
font-size: 16px
font-weight: 500
width: 100%
min-height: 48px
cursor: pointer
transition: all 0.2s ease

hover:
  background: #7D9BB5
  transform: translateY(-1px)
  box-shadow: 0 4px 12px rgba(91, 124, 153, 0.25)

active:
  background: #4A6380
  transform: translateY(0)

disabled (while submitting):
  background: #E5E7EB
  color: #6B7280
  cursor: not-allowed
  opacity: 0.6
```

**Button Text States**
- Default: "Lägg till kontakt"
- Loading: "Lägger till..." (with spinner)
- After success: "Lägg till kontakt" (returns to default)

**Loading Spinner**
```css
/* Inline spinner during submission */
.spinner {
  display: inline-block
  width: 16px
  height: 16px
  border: 2px solid rgba(255, 255, 255, 0.3)
  border-top-color: #FFFFFF
  border-radius: 50%
  animation: spin 0.6s linear infinite
  margin-right: 8px
}
```

### Success Message - Toast Notification

**Toast Container**
```css
position: fixed
top: 24px
right: 24px
z-index: 1000
max-width: 400px
animation: slideInRight 0.3s ease

@media (max-width: 640px):
  left: 16px
  right: 16px
  max-width: none
```

**Success Toast**
```css
background: #8FAA92
color: #FFFFFF
border-radius: 8px
padding: 16px 20px
box-shadow: 0 8px 24px rgba(45, 49, 66, 0.16)
display: flex
align-items: center
gap: 12px
```

**Toast Content Structure**
```
┌─────────────────────────────────────┐
│ ✓  Kontakt tillagd!            [×]  │
│    [Name] har sparats              │
└─────────────────────────────────────┘
```

**Toast Elements**
```css
/* Success icon */
.toast-icon {
  width: 24px
  height: 24px
  flex-shrink: 0
  /* Use ✓ checkmark or similar */
}

/* Toast text */
.toast-text {
  flex: 1
}

.toast-title {
  font-weight: 600
  font-size: 15px
  margin-bottom: 2px
}

.toast-message {
  font-size: 14px
  opacity: 0.9
}

/* Close button */
.toast-close {
  background: transparent
  border: none
  color: #FFFFFF
  font-size: 20px
  cursor: pointer
  padding: 0
  width: 24px
  height: 24px
  opacity: 0.8
}

.toast-close:hover {
  opacity: 1
}
```

**Toast Animations**
```css
@keyframes slideInRight {
  from {
    transform: translateX(100%)
    opacity: 0
  }
  to {
    transform: translateX(0)
    opacity: 1
  }
}

@keyframes slideOutRight {
  from {
    transform: translateX(0)
    opacity: 1
  }
  to {
    transform: translateX(100%)
    opacity: 0
  }
}

/* Auto-dismiss after 4 seconds */
/* Show progress bar at bottom */
.toast-progress {
  position: absolute
  bottom: 0
  left: 0
  height: 3px
  background: rgba(255, 255, 255, 0.5)
  animation: shrink 4s linear
}

@keyframes shrink {
  from { width: 100% }
  to { width: 0% }
}
```

**Error Toast (for failed submissions)**
```css
background: #C4756E
/* Same structure as success toast */
```

### Form Behavior & UX Flow

**Step-by-Step User Flow**

1. **User arrives at page**
   - Form is empty, all fields pristine
   - No validation errors visible
   - Submit button enabled

2. **User fills in "Namn" field**
   - While typing: no validation
   - On blur (leaving field): validate
   - If empty: show "Namn är obligatoriskt" error
   - If filled: subtle green border (optional)

3. **User fills in "E-post" field**
   - While typing: no validation
   - On blur: validate email format IF field has content
   - If invalid format: show "Ogiltig e-postadress" error
   - If valid or empty: no error (field is optional)

4. **User fills in "Telefon" field**
   - No validation (accept any format)
   - Optional field

5. **User clicks "Lägg till kontakt"**
   - Button shows loading state: "Lägger till..."
   - Button disabled during submission
   - Spinner appears

6. **On success**
   - Form clears all fields
   - Success toast appears: "✓ Kontakt tillagd! [Name] har sparats"
   - Toast auto-dismisses after 4 seconds
   - Contact appears in list below (if visible)
   - Focus returns to "Namn" field

7. **On error (network/server)**
   - Error toast appears: "❌ Något gick fel. Försök igen."
   - Form fields retain values
   - Button re-enables
   - User can retry

### Mobile Responsiveness

**Mobile Form (< 640px)**
```css
.form-container {
  padding: 24px 16px
  margin: 16px
}

/* Increase touch targets */
input, button {
  min-height: 48px
  font-size: 16px /* Prevent zoom on iOS */
}

/* Stack everything vertically */
gap: 16px
```

**Tablet (640px - 1023px)**
```css
.form-container {
  padding: 32px 24px
  max-width: 600px
  margin: 0 auto
}
```

**Desktop (1024px+)**
```css
.form-container {
  max-width: 600px
  margin: 0 auto 32px
}
```

### Accessibility Checklist

- [x] Labels associated with inputs (for/id)
- [x] Required fields marked with aria-required="true"
- [x] Error messages announced via aria-live="polite"
- [x] Form has clear heading (h2: "Lägg till ny kontakt")
- [x] Color is not the only indicator (icons + text)
- [x] Focus visible on all inputs (2px ring)
- [x] Keyboard navigation works (Tab, Enter to submit)
- [x] Success toast dismissable via keyboard (Esc)

### Example HTML Structure Reference

```html
<form class="add-contact-form" aria-label="Lägg till ny kontakt">
  <h2>Lägg till ny kontakt</h2>

  <!-- Name field (required) -->
  <div class="field-group">
    <label for="name" class="required">Namn</label>
    <input
      type="text"
      id="name"
      name="name"
      placeholder="Ange namn"
      aria-required="true"
      aria-invalid="false"
    />
    <span class="error-message" role="alert"></span>
  </div>

  <!-- Email field (optional) -->
  <div class="field-group">
    <label for="email">E-post</label>
    <input
      type="email"
      id="email"
      name="email"
      placeholder="namn@example.com"
      aria-invalid="false"
    />
    <span class="error-message" role="alert"></span>
  </div>

  <!-- Phone field (optional) -->
  <div class="field-group">
    <label for="phone">Telefon</label>
    <input
      type="tel"
      id="phone"
      name="phone"
      placeholder="070-123 45 67"
    />
  </div>

  <button type="submit" class="btn-primary">
    Lägg till kontakt
  </button>
</form>

<!-- Toast container (hidden by default) -->
<div class="toast-container" aria-live="polite" aria-atomic="true"></div>
```

---

---

## Sprint 3: Contact List / Table View Design

### Layout Choice: Card-Based List

**Why Cards over Table:**
Based on research, cards are better for this use case because:
- Users will browse and read individual contacts (not bulk actions)
- Each contact has limited fields (name, email, phone) - cards are more readable
- Cards work better on mobile devices (responsive)
- Better visual hierarchy for mixed text lengths

*Source: [Cards vs Tables UX](https://medium.com/design-bootcamp/when-to-use-which-component-a-case-study-of-card-view-vs-table-view-7f5a6cff557b)*

### Contact Card Design

**Card Container**
```css
background: #FFFFFF
border-radius: 12px
padding: 20px 24px
box-shadow: 0 2px 8px rgba(45, 49, 66, 0.08)
transition: all 0.2s ease
cursor: default

hover:
  box-shadow: 0 4px 12px rgba(45, 49, 66, 0.12)
  transform: translateY(-2px)
```

**Card Structure**
```
┌─────────────────────────────────────┐
│ Anna Andersson              [icon]  │
│ anna.andersson@example.com          │
│ 070-123 45 67                       │
└─────────────────────────────────────┘
```

**Name (Primary Text)**
```css
font-size: 18px
font-weight: 600
color: #2D3142
margin-bottom: 8px
line-height: 1.3
/* Allow line break for long names */
word-wrap: break-word
```

**Email (Secondary Text - Monospace)**
```css
font-family: 'JetBrains Mono', monospace
font-size: 14px
color: #5B7C99
margin-bottom: 6px
word-break: break-all /* Handle long emails */
line-height: 1.4
```

**Phone (Secondary Text - Monospace)**
```css
font-family: 'JetBrains Mono', monospace
font-size: 14px
color: #6B7280
line-height: 1.4
```

**Optional: Contact Icon**
```css
/* Top-right corner - person icon or avatar placeholder */
position: absolute
top: 20px
right: 24px
width: 32px
height: 32px
border-radius: 50%
background: #F7F5F2
color: #5B7C99
display: flex
align-items: center
justify-content: center
font-size: 16px
```

### Contact List Grid

**List Container**
```css
display: grid
gap: 16px
margin-top: 32px

/* Mobile: 1 column */
grid-template-columns: 1fr

/* Tablet: 2 columns */
@media (min-width: 640px):
  grid-template-columns: repeat(2, 1fr)
  gap: 20px

/* Desktop: 3 columns */
@media (min-width: 1024px):
  grid-template-columns: repeat(3, 1fr)
  gap: 24px
```

**List Section Heading**
```css
font-size: 20px
font-weight: 600
color: #2D3142
margin-bottom: 16px
margin-top: 32px
/* Example: "Alla kontakter (12)" */
```

### Empty State Design

**Empty State Container**
```css
background: #FFFFFF
border: 2px dashed #E5E7EB
border-radius: 12px
padding: 64px 32px
text-align: center
margin-top: 32px
min-height: 300px
display: flex
flex-direction: column
align-items: center
justify-content: center
gap: 16px
```

**Empty State Icon**
```css
/* Use emoji or SVG icon */
font-size: 48px
margin-bottom: 8px
opacity: 0.6
/* Suggestion: 📇 or 👤 or contact book icon */
```

**Empty State Heading**
```css
font-size: 20px
font-weight: 600
color: #2D3142
margin-bottom: 8px
/* Text: "Inga kontakter ännu" */
```

**Empty State Message**
```css
font-size: 16px
color: #6B7280
line-height: 1.6
max-width: 400px
/* Text: "Lägg till din första kontakt med formuläret ovan." */
```

**Empty State Best Practices Applied:**
- **Clear & Direct**: "Inga kontakter ännu" (no contacts yet) - states what's empty
- **Actionable Guidance**: "Lägg till din första kontakt..." - tells user what to do
- **Friendly Tone**: Swedish, warm, encouraging language
- **Visual Balance**: Icon + text keeps it from feeling too stark

*Source: [Empty State UX Best Practices](https://www.eleken.co/blog-posts/empty-state-ux)*

### Missing Field Handling

**When Email is Missing**
```css
/* Don't show empty email line - hide it */
display: none
```

**When Phone is Missing**
```css
/* Don't show empty phone line - hide it */
display: none
```

**Card with Only Name (no email, no phone)**
```
┌─────────────────────────────────────┐
│ Anna Andersson              [icon]  │
│                                     │
└─────────────────────────────────────┘
```

### Loading State

**Loading Skeleton Cards**
```css
/* Show 3-6 skeleton cards while loading */
background: linear-gradient(90deg, #F7F5F2 25%, #E5E7EB 50%, #F7F5F2 75%)
background-size: 200% 100%
animation: shimmer 1.5s infinite
border-radius: 12px
height: 120px

@keyframes shimmer {
  0% { background-position: 200% 0 }
  100% { background-position: -200% 0 }
}
```

**Loading Text**
```
Laddar kontakter...
```

### No Search Results State

**When Search Returns Empty**
```css
/* Similar to empty state but different message */
padding: 48px 32px
text-align: center

/* Icon: 🔍 */
/* Heading: "Inga kontakter hittades" */
/* Message: "Försök med ett annat sökord" */
```

### Section Heading with Count

**"Alla kontakter (12)"**
```css
font-size: 20px
font-weight: 600
color: #2D3142
margin-bottom: 16px

/* Count in muted color */
span.count {
  color: #6B7280
  font-weight: 400
}
```

### Responsive Behavior

**Mobile (< 640px)**
- 1 column layout
- Full-width cards
- Padding: 16px
- Font sizes slightly smaller for better fit

**Tablet (640px - 1023px)**
- 2 column layout
- Cards maintain 20px gap
- Balanced grid

**Desktop (1024px+)**
- 3 column layout
- 24px gap between cards
- Max 3 cards per row for better readability

### Accessibility

- **Semantic HTML**: Use `<article>` or `<div role="article">` for each contact card
- **Keyboard Navigation**: Cards should be tabbable if interactive
- **Screen Reader**: Clear structure - "Contact: [Name], Email: [Email], Phone: [Phone]"
- **Empty State**: Clear messaging, no reliance on icons alone
- **Contrast**: All text meets WCAG AA (4.5:1 for body, 3:1 for large text)

### Micro-interactions

**Card Hover**
```css
transition: all 0.2s ease
hover:
  transform: translateY(-2px)
  box-shadow: 0 4px 12px rgba(45, 49, 66, 0.12)
```

**Stagger Animation (when list loads)**
```css
/* Fade in cards one by one */
@keyframes fadeInUp {
  from {
    opacity: 0
    transform: translateY(20px)
  }
  to {
    opacity: 1
    transform: translateY(0)
  }
}

.contact-card:nth-child(1) { animation: fadeInUp 0.3s ease 0.1s both }
.contact-card:nth-child(2) { animation: fadeInUp 0.3s ease 0.2s both }
.contact-card:nth-child(3) { animation: fadeInUp 0.3s ease 0.3s both }
/* etc... max 0.6s for performance */
```

### Example HTML Structure Reference

```html
<!-- Contact List Section -->
<section class="contact-list-section">
  <h2>Alla kontakter <span class="count">(12)</span></h2>

  <!-- Contact Grid -->
  <div class="contact-grid">

    <!-- Contact Card -->
    <article class="contact-card">
      <div class="contact-icon">👤</div>
      <h3 class="contact-name">Anna Andersson</h3>
      <p class="contact-email">anna.andersson@example.com</p>
      <p class="contact-phone">070-123 45 67</p>
    </article>

    <!-- More contact cards... -->

  </div>
</section>

<!-- Empty State (when no contacts) -->
<div class="empty-state">
  <div class="empty-icon">📇</div>
  <h3>Inga kontakter ännu</h3>
  <p>Lägg till din första kontakt med formuläret ovan.</p>
</div>
```

### Design Decisions Summary

1. **Cards over table**: Better readability, mobile-friendly, suits small dataset
2. **Monospace for email/phone**: Easier to scan and copy technical data
3. **Generous spacing**: 16-24px gaps keep cards breathable
4. **Subtle hover effects**: Lift cards 2px on hover for interactivity cue
5. **Friendly empty state**: Swedish messaging, actionable guidance, warm icon
6. **Responsive grid**: 1-2-3 column layout adapts to screen size
7. **Hide missing fields**: Don't show empty email/phone lines

---

## Sprint 4: Search Contacts Design

### Search Input Field Design

**Why Search is Important:**
Search enables quick discovery in growing contact lists. For this app, search should be fast, visible, and user-friendly - following 2026 UX best practices for search interfaces.

*Research: [Search UX Best Practices 2026](https://www.designstudiouiux.com/blog/search-ux-best-practices/), [Search Bar Examples & UX Tips](https://www.eleken.co/blog-posts/search-bar-examples)*

### Search Bar Placement & Layout

**Position: Top of Contact List**
```css
/* Search bar sits above contact grid */
position: relative
margin-bottom: 24px
width: 100%
max-width: 600px /* Don't make search too wide */

@media (min-width: 768px):
  max-width: 100% /* Full width on larger screens */
```

**Page Structure with Search**
```
┌─────────────────────────────────┐
│ Header                          │
├─────────────────────────────────┤
│ Container                       │
│  ┌───────────────────────────┐ │
│  │ Add Contact Form          │ │
│  ├───────────────────────────┤ │
│  │ 🔍 Search Bar             │ │ ← NEW (Sprint 4)
│  ├───────────────────────────┤ │
│  │ Contact Grid              │ │
│  │  [Card] [Card] [Card]     │ │
│  └───────────────────────────┘ │
└─────────────────────────────────┘
```

### Search Input Field Specifications

**Search Container**
```css
position: relative
width: 100%
display: flex
align-items: center
```

**Search Input**
```css
background: #FFFFFF
border: 2px solid #E5E7EB
border-radius: 4px
padding: 12px 16px 12px 48px /* Extra left padding for icon */
font-size: 16px
color: #2D3142
width: 100%
min-height: 48px /* WCAG touch target */
font-family: 'Inter', sans-serif

placeholder: {
  color: #6B7280
  content: "Sök kontakter..." /* Swedish placeholder */
}

focus:
  border-color: #5B7C99
  box-shadow: 0 0 0 3px rgba(91, 124, 153, 0.15)
  outline: none
  transition: all 0.15s ease
```

**Search Icon (Magnifying Glass)**
```css
/* Position inside input on left side */
position: absolute
left: 16px
top: 50%
transform: translateY(-50%)
width: 20px
height: 20px
color: #6B7280
pointer-events: none /* Icon is decorative */
z-index: 1

/* Use SVG icon or Unicode: 🔍 */
```

**Clear Button (X Icon)**
```css
/* Position inside input on right side */
position: absolute
right: 12px
top: 50%
transform: translateY(-50%)
width: 32px
height: 32px
background: transparent
border: none
border-radius: 50%
color: #6B7280
cursor: pointer
padding: 6px
display: flex
align-items: center
justify-content: center
transition: all 0.2s ease
opacity: 0 /* Hidden by default */
pointer-events: none /* Disabled when hidden */

/* Show when input has value */
.has-value .clear-button {
  opacity: 1
  pointer-events: auto
}

hover:
  background: #F7F5F2
  color: #2D3142

active:
  background: #E5E7EB

/* Icon: × or ✕ (Unicode) or SVG close icon */
font-size: 18px
font-weight: 500
line-height: 1
```

### Search Behavior & Interaction

**Input Length**
```css
/* Standard user query: ~27 characters (covers 90% of queries) */
min-width: 250px /* Mobile */
width: 100% /* Responsive */

@media (min-width: 768px):
  min-width: 400px /* Tablet/Desktop */
```

*Research: [Search Box UX Design Elements](https://www.algolia.com/blog/ux/3-key-ux-design-elements-of-the-search-bar/)*

**Search Trigger**
- **Live search** (debounced 300ms): Results update as user types
- **Performance**: Debounce prevents excessive API calls
- **Alternative**: Search on Enter key (if live search causes performance issues)

**Clear Button Behavior**
1. **Hidden by default** - only appears when input has text
2. **Smooth fade-in** - 0.2s transition when text appears
3. **Single click clears** - removes all text, refocuses input
4. **Resets results** - shows all contacts again
5. **Keyboard accessible** - Tab to focus, Enter to activate

### Search States

**Empty (Default)**
```css
/* No text in input */
border: 2px solid #E5E7EB
/* Search icon visible on left */
/* Clear button hidden */
```

**Active (User Typing)**
```css
/* Input has focus */
border-color: #5B7C99
box-shadow: 0 0 0 3px rgba(91, 124, 153, 0.15)
/* Clear button visible (if text exists) */
```

**Has Value (Text Entered)**
```css
/* Input contains text */
/* Search icon visible */
/* Clear button visible and functional */
```

### "No Results" Empty State Design

**When Search Returns Zero Matches**

**No Results Container**
```css
background: #FFFFFF
border: 2px dashed #E5E7EB
border-radius: 12px
padding: 48px 32px
text-align: center
margin-top: 24px
min-height: 250px
display: flex
flex-direction: column
align-items: center
justify-content: center
gap: 12px
```

**No Results Icon**
```css
font-size: 40px
margin-bottom: 8px
opacity: 0.6
/* Icon: 🔍 (magnifying glass) */
```

**No Results Heading**
```css
font-size: 18px
font-weight: 600
color: #2D3142
margin-bottom: 4px
/* Text: "Inga träffar" (No matches) */
```

**No Results Message**
```css
font-size: 15px
color: #6B7280
line-height: 1.5
max-width: 350px
/* Text: "Försök med ett annat sökord" (Try another search term) */
```

**No Results State Structure**
```
┌─────────────────────────────────────┐
│                                     │
│           🔍                         │
│                                     │
│      Inga träffar                   │
│                                     │
│  Försök med ett annat sökord        │
│                                     │
└─────────────────────────────────────┘
```

### Accessibility

**ARIA Labels & Roles**
```html
<input
  type="search"
  role="searchbox"
  aria-label="Sök kontakter"
  placeholder="Sök kontakter..."
  aria-describedby="search-help"
/>

<button
  class="clear-button"
  aria-label="Rensa sökning"
  title="Rensa"
>
  ×
</button>

<!-- Hidden helper text for screen readers -->
<span id="search-help" class="sr-only">
  Sök efter namn, e-post eller telefonnummer
</span>
```

**Keyboard Support**
- **Tab**: Focus search input
- **Type**: Start searching (live results)
- **Esc**: Clear search and reset results
- **Tab (from input)**: Focus clear button (if visible)
- **Enter (on clear button)**: Clear search

**Screen Reader Announcements**
```html
<!-- Announce result count -->
<div aria-live="polite" aria-atomic="true" class="sr-only">
  {count} kontakter hittades
</div>

<!-- Announce no results -->
<div aria-live="polite" aria-atomic="true" class="sr-only">
  Inga kontakter hittades för "{query}"
</div>
```

### Mobile Responsiveness

**Mobile (< 640px)**
```css
.search-container {
  padding: 0
  margin-bottom: 20px
}

input[type="search"] {
  font-size: 16px /* Prevent iOS zoom */
  min-height: 48px /* Touch target */
  width: 100%
}

.clear-button {
  width: 36px
  height: 36px
  /* Larger touch target on mobile */
}
```

**Tablet & Desktop (640px+)**
```css
.search-container {
  max-width: 600px
  margin: 0 auto 32px
}
```

### Performance Optimization

**Debounced Search**
```javascript
/* Wait 300ms after user stops typing before searching */
const DEBOUNCE_DELAY = 300; // milliseconds

/* Prevents excessive API calls */
/* Recommended by [DesignRush Search UX 2026](https://www.designrush.com/best-designs/websites/trends/search-ux-best-practices) */
```

**Loading State (Optional)**
```css
/* Subtle loading indicator while search is processing */
.search-input.searching {
  background-image: linear-gradient(90deg, transparent, rgba(91, 124, 153, 0.1), transparent)
  background-size: 200% 100%
  animation: shimmer 1.5s infinite
}
```

### Visual Hierarchy

**Search Section Spacing**
```css
/* Spacing from form above */
margin-top: 32px

/* Spacing from contact list below */
margin-bottom: 24px
```

**Search Label (Optional)**
```css
/* If you want a label above search */
font-size: 14px
font-weight: 500
color: #2D3142
margin-bottom: 8px
display: block
/* Text: "Sök i kontakter" */
```

### Example HTML Structure Reference

```html
<!-- Search Section -->
<div class="search-section">
  <!-- Optional label -->
  <label for="contact-search" class="search-label">
    Sök i kontakter
  </label>

  <!-- Search Container -->
  <div class="search-container">
    <!-- Search Icon -->
    <svg class="search-icon" aria-hidden="true">
      <!-- Magnifying glass SVG -->
    </svg>

    <!-- Search Input -->
    <input
      type="search"
      id="contact-search"
      class="search-input"
      placeholder="Sök kontakter..."
      role="searchbox"
      aria-label="Sök kontakter efter namn, e-post eller telefon"
    />

    <!-- Clear Button -->
    <button
      class="clear-button"
      aria-label="Rensa sökning"
      title="Rensa"
      type="button"
    >
      ×
    </button>
  </div>

  <!-- Screen reader result announcement -->
  <div id="search-results-status" aria-live="polite" aria-atomic="true" class="sr-only"></div>
</div>

<!-- Contact List (filtered by search) -->
<section class="contact-list-section">
  <h2>Kontakter <span class="count">(12)</span></h2>
  <div class="contact-grid">
    <!-- Contact cards here -->
  </div>
</section>

<!-- No Results State (when search returns nothing) -->
<div class="no-results-state" style="display: none;">
  <div class="no-results-icon">🔍</div>
  <h3>Inga träffar</h3>
  <p>Försök med ett annat sökord</p>
</div>
```

### Design Decisions Summary

1. **Prominent placement**: Search sits above contact list for easy discovery
2. **27-character width**: Accommodates 90% of search queries (industry standard)
3. **Clear button inside input**: Single-click to reset, only visible when needed
4. **Debounced live search**: 300ms delay prevents excessive API calls
5. **Friendly "no results" state**: Swedish messaging with search icon
6. **Full keyboard support**: Tab, Esc to clear, Enter works
7. **Mobile-optimized**: 16px font prevents iOS zoom, full-width responsive
8. **Accessible**: ARIA labels, screen reader announcements, semantic HTML

---

*Design inspiration sources:*
- Scandinavian minimalism with warm Japandi influences
- 2026 UI trends: performance-first, accessible, purposeful motion
- Swedish design principles: clarity, functionality, natural materials
- [Modern contact form design trends 2026](https://www.eleken.co/blog-posts/contact-form-design)
- [Form validation best practices](https://www.designstudiouiux.com/blog/form-ux-design-best-practices/)
- [Toast notification UX patterns](https://blog.logrocket.com/ux-design/toast-notifications/)
- [Card UI Design Best Practices 2026](https://www.eleken.co/blog-posts/card-ui-examples-and-best-practices-for-product-owners)
- [Cards vs Tables UX Decision Guide](https://medium.com/design-bootcamp/when-to-use-which-component-a-case-study-of-card-view-vs-table-view-7f5a6cff557b)
- [Empty State UX Examples](https://www.eleken.co/blog-posts/empty-state-ux)
- [Empty State Design Best Practices](https://www.nngroup.com/articles/empty-state-interface-design/)
- [Search UX Best Practices 2026](https://www.designstudiouiux.com/blog/search-ux-best-practices/)
- [Search Bar Examples & UX Tips](https://www.eleken.co/blog-posts/search-bar-examples)
- [Search Box UX Design Elements](https://www.algolia.com/blog/ux/3-key-ux-design-elements-of-the-search-bar/)
- [Search UX Best Practices - DesignRush](https://www.designrush.com/best-designs/websites/trends/search-ux-best-practices)

---

## Sprint 5: Delete Contact Design

### Delete Button Design & Placement

**Why Confirmation is Critical:**
Delete actions are irreversible and destructive. Best practices from [Delete Button UI Best Practices](https://www.designmonks.co/blog/delete-button-ui) and [Confirmation Dialog Guidelines](https://www.nngroup.com/articles/confirmation-dialog/) emphasize that:
- Confirmation modals prevent accidental deletion
- Destructive actions should introduce friction for safety
- Clear, specific language reduces user anxiety
- Scandinavian design (Helsinki Design System) uses danger colors and reversed button order for emphasis

### Delete Button on Contact Card

**Button Placement**
```css
/* Position in top-right corner of card */
position: absolute
top: 16px
right: 16px
width: 36px
height: 36px
border-radius: 50% /* Circular button */
background: transparent
border: none
cursor: pointer
transition: all 0.2s ease
z-index: 1

/* Icon color (muted by default) */
color: #6B7280

/* Center icon */
display: flex
align-items: center
justify-content: center
```

**Delete Icon**
```css
/* Use trash can icon or × symbol */
width: 18px
height: 18px
/* SVG icon preferred: trash-can, bin, or delete icon */
/* Alternative: Unicode 🗑️ or ✕ */
```

**Button States**
```css
default:
  background: transparent
  color: #6B7280
  opacity: 0.7

hover:
  background: rgba(196, 117, 110, 0.1) /* Error color with 10% opacity */
  color: #C4756E /* Error color */
  opacity: 1
  transform: scale(1.05)

active:
  background: rgba(196, 117, 110, 0.2)
  transform: scale(0.95)

focus:
  outline: 2px solid #C4756E
  outline-offset: 2px
```

**Card with Delete Button Structure**
```
┌─────────────────────────────────────┐
│ Anna Andersson              [🗑️]   │ ← Delete button top-right
│ anna.andersson@example.com          │
│ 070-123 45 67                       │
└─────────────────────────────────────┘
```

### Confirmation Modal Design

**Modal Purpose:**
Following [Modal UX Best Practices](https://www.eleken.co/blog-posts/modal-ux), confirmation modals for delete actions:
- Force user to pause and think before committing
- Provide specific information about what will be deleted
- Use danger styling (red) to signal destructive action
- Default focus to "Cancel" for safety (Scandinavian pattern from Helsinki Design System)

**Modal Overlay**
```css
/* Full-screen darkened overlay */
position: fixed
top: 0
left: 0
right: 0
bottom: 0
background: rgba(45, 49, 66, 0.6) /* Dark overlay 60% opacity */
z-index: 1000
display: flex
align-items: center
justify-content: center
padding: 16px
animation: fadeIn 0.2s ease
```

**Modal Container**
```css
background: #FFFFFF
border-radius: 12px
padding: 32px
max-width: 480px
width: 100%
box-shadow: 0 20px 60px rgba(45, 49, 66, 0.3)
animation: slideUp 0.3s ease
position: relative

@media (max-width: 640px):
  padding: 24px
  max-width: calc(100% - 32px)
```

**Modal Animations**
```css
@keyframes fadeIn {
  from { opacity: 0 }
  to { opacity: 1 }
}

@keyframes slideUp {
  from {
    opacity: 0
    transform: translateY(30px) scale(0.95)
  }
  to {
    opacity: 1
    transform: translateY(0) scale(1)
  }
}

/* Exit animation */
@keyframes slideDown {
  from {
    opacity: 1
    transform: translateY(0) scale(1)
  }
  to {
    opacity: 0
    transform: translateY(30px) scale(0.95)
  }
}
```

**Modal Structure**
```
┌──────────────────────────────────────┐
│  [⚠️]                        [×]     │ ← Warning icon + close button
│                                      │
│  Radera kontakt?                     │ ← Heading
│                                      │
│  Vill du verkligen ta bort           │
│  "Anna Andersson"?                   │ ← Specific contact name
│                                      │
│  Denna åtgärd kan inte ångras.       │ ← Consequence warning
│                                      │
│  [   Avbryt   ]  [   Radera   ]     │ ← Buttons (reversed order)
│                                      │
└──────────────────────────────────────┘
```

### Modal Elements Specifications

**Warning Icon (Top)**
```css
width: 48px
height: 48px
margin: 0 auto 16px
background: rgba(196, 117, 110, 0.1) /* Error color 10% opacity */
border-radius: 50%
display: flex
align-items: center
justify-content: center
color: #C4756E
font-size: 24px

/* Icon: ⚠️ warning triangle or 🗑️ trash can */
```

**Close Button (Top-Right)**
```css
position: absolute
top: 16px
right: 16px
width: 32px
height: 32px
background: transparent
border: none
border-radius: 50%
color: #6B7280
cursor: pointer
display: flex
align-items: center
justify-content: center
font-size: 20px
transition: all 0.2s ease

hover:
  background: #F7F5F2
  color: #2D3142

/* Icon: × or ✕ */
```

**Modal Heading**
```css
font-size: 24px
font-weight: 600
color: #2D3142
text-align: center
margin-bottom: 16px
line-height: 1.3

/* Swedish text: "Radera kontakt?" */
```

**Modal Message**
```css
font-size: 16px
color: #6B7280
text-align: center
line-height: 1.6
margin-bottom: 8px

/* First line: "Vill du verkligen ta bort" */
/* Second line (emphasized): Contact name in bold/quotes */
strong {
  color: #2D3142
  font-weight: 600
}
```

**Consequence Warning**
```css
font-size: 14px
color: #C4756E /* Error color */
text-align: center
line-height: 1.5
margin-bottom: 24px
font-weight: 500

/* Swedish text: "Denna åtgärd kan inte ångras." */
/* (This action cannot be undone.) */
```

### Modal Button Design

**Button Container**
```css
display: flex
gap: 12px
justify-content: flex-end /* Align buttons to right */
flex-direction: row-reverse /* Reversed order (Scandinavian pattern) */

/* On mobile: stack vertically */
@media (max-width: 480px):
  flex-direction: column-reverse
  gap: 8px
```

**Cancel Button (Default Focus - Safety First)**
```css
/* Secondary button style - SAFE action */
background: #FFFFFF
color: #2D3142
border: 2px solid #E5E7EB
border-radius: 8px
padding: 12px 24px
font-size: 16px
font-weight: 500
min-width: 120px
cursor: pointer
transition: all 0.2s ease
order: 1 /* Appears FIRST visually (Scandinavian pattern) */

/* DEFAULT FOCUS for safety */
focus:
  border-color: #5B7C99
  box-shadow: 0 0 0 3px rgba(91, 124, 153, 0.15)
  outline: none

hover:
  border-color: #5B7C99
  background: #F7F5F2

/* Swedish text: "Avbryt" (Cancel) */
```

**Delete Button (Danger - Destructive Action)**
```css
/* Danger button style - DESTRUCTIVE action */
background: #C4756E /* Error color */
color: #FFFFFF
border: 2px solid #C4756E
border-radius: 8px
padding: 12px 24px
font-size: 16px
font-weight: 500
min-width: 120px
cursor: pointer
transition: all 0.2s ease
order: 2 /* Appears LAST visually (Scandinavian pattern) */

hover:
  background: #B06559 /* Darker red */
  border-color: #B06559
  transform: translateY(-1px)
  box-shadow: 0 4px 12px rgba(196, 117, 110, 0.3)

active:
  background: #9D564D
  transform: translateY(0)

focus:
  box-shadow: 0 0 0 3px rgba(196, 117, 110, 0.3)
  outline: none

/* Swedish text: "Radera" (Delete) */
```

**Mobile Button Layout**
```css
@media (max-width: 480px):
  /* Stack vertically, full-width */
  .modal-buttons {
    flex-direction: column-reverse
    gap: 8px
  }

  .modal-button {
    width: 100%
    min-height: 48px /* Touch target */
  }

  /* Cancel button on TOP (default focus) */
  /* Delete button on BOTTOM (requires scrolling/deliberate tap) */
```

### Scandinavian Design Pattern: Reversed Button Order

**Why Reverse Order:**
Following the [Helsinki Design System](https://hds.hel.fi/components/dialog/) (Finnish/Scandinavian):
- **Danger dialogs reverse button order** to emphasize the destructive action
- **Cancel button appears FIRST** (left) for safety
- **Delete button appears LAST** (right) to introduce friction
- **Default focus on Cancel** prevents accidental deletion via keyboard (Enter key)

This differs from typical Western patterns (primary action first) but is safer for destructive actions.

### Swedish Language (Svensk UI)

**Modal Text in Swedish:**
- **Heading**: "Radera kontakt?" (Delete contact?)
- **Message**: "Vill du verkligen ta bort [Namn]?" (Do you really want to delete [Name]?)
- **Warning**: "Denna åtgärd kan inte ångras." (This action cannot be undone.)
- **Cancel Button**: "Avbryt" (Cancel)
- **Delete Button**: "Radera" (Delete)

**Specific Contact Name:**
Always include the specific contact name being deleted (e.g., "Anna Andersson") to give users clarity and prevent mistakes.

### Modal Accessibility

**ARIA Attributes**
```html
<!-- Modal container -->
<div
  class="modal-overlay"
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  aria-describedby="modal-description"
>
  <!-- Modal content -->
  <div class="modal-content">
    <h2 id="modal-title">Radera kontakt?</h2>
    <p id="modal-description">
      Vill du verkligen ta bort <strong>"Anna Andersson"</strong>?
    </p>
    <p class="modal-warning">Denna åtgärd kan inte ångras.</p>

    <!-- Buttons -->
    <div class="modal-buttons">
      <button
        class="btn-cancel"
        autofocus
        aria-label="Avbryt radering"
      >
        Avbryt
      </button>
      <button
        class="btn-delete"
        aria-label="Radera kontakt permanent"
      >
        Radera
      </button>
    </div>
  </div>
</div>
```

**Keyboard Navigation**
- **Tab**: Navigate between Close (×), Cancel, Delete buttons
- **Enter**: Activate focused button
- **Esc**: Close modal (same as Cancel)
- **Default focus**: Cancel button (autofocus for safety)

**Focus Trap**
```javascript
/* Modal should trap focus within itself */
/* Prevent tabbing to elements behind modal */
/* Tab cycles: Close → Cancel → Delete → Close */
```

**Screen Reader Announcements**
```html
<!-- Announce modal opening -->
<div aria-live="assertive" class="sr-only">
  Radera kontakt dialog öppnad. Vill du verkligen ta bort Anna Andersson?
</div>
```

### Delete UX Flow (Step-by-Step)

**User Journey:**

1. **User hovers over contact card**
   - Delete button becomes visible/highlighted (subtle)
   - Icon changes to error color (#C4756E)

2. **User clicks delete button**
   - Modal overlay fades in (0.2s)
   - Modal container slides up (0.3s)
   - Focus automatically moves to Cancel button (safety)
   - Background content is inert (cannot interact)

3. **User reads confirmation**
   - Clear heading: "Radera kontakt?"
   - Specific contact name shown
   - Warning: "Denna åtgärd kan inte ångras."

4. **User chooses action**
   - **Option A: Cancel** (default focus)
     - Clicks "Avbryt" or presses Esc
     - Modal slides down and fades out
     - Focus returns to delete button on card
     - Contact remains in list

   - **Option B: Delete** (requires deliberate action)
     - Tabs to "Radera" button or clicks it
     - Delete button shows loading state: "Raderar..."
     - API call: DELETE /contacts/{id}
     - On success:
       - Modal closes immediately
       - Contact card fades out (0.3s)
       - Success toast: "✓ [Namn] har raderats"
       - Contact list updates (remaining cards adjust)
     - On error:
       - Error toast: "❌ Kunde inte radera kontakt"
       - Modal stays open
       - User can retry or cancel

5. **After deletion**
   - List count updates: "Alla kontakter (11)" → "(10)"
   - Empty state appears if last contact deleted
   - Success toast auto-dismisses after 4s

### Loading State During Delete

**Delete Button (While Processing)**
```css
.btn-delete.loading {
  background: #E5E7EB
  color: #6B7280
  cursor: not-allowed
  pointer-events: none
}

/* Spinner icon */
.btn-delete.loading::before {
  content: ""
  display: inline-block
  width: 14px
  height: 14px
  border: 2px solid rgba(107, 114, 128, 0.3)
  border-top-color: #6B7280
  border-radius: 50%
  margin-right: 8px
  animation: spin 0.6s linear infinite
}

/* Button text changes */
/* "Radera" → "Raderar..." */
```

### Success Toast After Delete

**Toast Message**
```css
/* Same toast design as Sprint 2 */
background: #8FAA92 /* Success color */
color: #FFFFFF
border-radius: 8px
padding: 16px 20px
box-shadow: 0 8px 24px rgba(45, 49, 66, 0.16)

/* Position: top-right */
position: fixed
top: 24px
right: 24px
z-index: 1001 /* Above modal */
animation: slideInRight 0.3s ease

/* Content */
/* Icon: ✓ checkmark */
/* Text: "[Namn] har raderats" */
/* Example: "✓ Anna Andersson har raderats" */

/* Auto-dismiss after 4 seconds */
```

**Error Toast (If Delete Fails)**
```css
background: #C4756E /* Error color */
/* Same structure as success toast */

/* Content */
/* Icon: ❌ */
/* Text: "Kunde inte radera kontakt. Försök igen." */
```

### Empty State After Deleting All Contacts

**Transition to Empty State**
```css
/* If user deletes the last contact */
/* Fade out last contact card (0.3s) */
/* Fade in empty state (0.3s delay) */
/* Smooth transition, not jarring */

/* Empty state design (from Sprint 3) */
background: #FFFFFF
border: 2px dashed #E5E7EB
border-radius: 12px
padding: 64px 32px
text-align: center

/* Icon: 📇 */
/* Heading: "Inga kontakter ännu" */
/* Message: "Lägg till din första kontakt med formuläret ovan." */
```

### Responsive Modal Design

**Mobile (< 640px)**
```css
.modal-content {
  padding: 24px 20px
  max-width: calc(100% - 32px)
  border-radius: 12px
}

/* Heading smaller */
.modal-title {
  font-size: 20px
}

/* Buttons stack vertically */
.modal-buttons {
  flex-direction: column-reverse
  gap: 8px
}

.modal-button {
  width: 100%
  min-height: 48px /* Touch target */
}

/* Cancel button on TOP */
/* Delete button on BOTTOM (safer on mobile) */
```

**Tablet & Desktop (640px+)**
```css
.modal-content {
  padding: 32px
  max-width: 480px
}

/* Buttons horizontal */
.modal-buttons {
  flex-direction: row-reverse
  justify-content: flex-end
  gap: 12px
}

.modal-button {
  min-width: 120px
  width: auto
}
```

### Design Decisions Summary

1. **Delete button on card**: Top-right corner, circular, subtle by default, danger color on hover
2. **Confirmation modal required**: Follows UX best practices to prevent accidental deletion
3. **Specific contact name shown**: "Vill du verkligen ta bort [Namn]?" for clarity
4. **Danger styling**: Red/error color (#C4756E) for destructive action
5. **Reversed button order**: Scandinavian pattern (Helsinki Design System) - Cancel first, Delete last
6. **Default focus on Cancel**: Safety-first approach, prevents accidental Enter key deletion
7. **Warning message**: "Denna åtgärd kan inte ångras" sets clear expectations
8. **Success toast feedback**: Confirms deletion with contact name
9. **Smooth animations**: Fade in/out, slide up/down for modal (0.2-0.3s)
10. **Full accessibility**: ARIA labels, focus trap, keyboard navigation (Tab, Esc, Enter)
11. **Swedish language**: All text in Swedish for consistency

### Example HTML Structure Reference

```html
<!-- Delete Button on Contact Card -->
<article class="contact-card">
  <button
    class="delete-button"
    aria-label="Radera Anna Andersson"
    data-contact-id="123"
    data-contact-name="Anna Andersson"
  >
    <svg class="delete-icon" aria-hidden="true">
      <!-- Trash can icon -->
    </svg>
  </button>

  <h3 class="contact-name">Anna Andersson</h3>
  <p class="contact-email">anna.andersson@example.com</p>
  <p class="contact-phone">070-123 45 67</p>
</article>

<!-- Confirmation Modal (Initially Hidden) -->
<div
  class="modal-overlay"
  role="dialog"
  aria-modal="true"
  aria-labelledby="delete-modal-title"
  aria-describedby="delete-modal-description"
  style="display: none;"
>
  <div class="modal-content">
    <!-- Close Button -->
    <button class="modal-close" aria-label="Stäng" title="Stäng">
      ×
    </button>

    <!-- Warning Icon -->
    <div class="modal-icon" aria-hidden="true">
      ⚠️
    </div>

    <!-- Heading -->
    <h2 id="delete-modal-title" class="modal-title">
      Radera kontakt?
    </h2>

    <!-- Message -->
    <p id="delete-modal-description" class="modal-message">
      Vill du verkligen ta bort <strong>"Anna Andersson"</strong>?
    </p>

    <!-- Warning -->
    <p class="modal-warning">
      Denna åtgärd kan inte ångras.
    </p>

    <!-- Buttons (Reversed Order) -->
    <div class="modal-buttons">
      <!-- Cancel button (appears first visually) -->
      <button
        class="btn-cancel"
        autofocus
        aria-label="Avbryt radering"
      >
        Avbryt
      </button>

      <!-- Delete button (appears last visually) -->
      <button
        class="btn-delete btn-danger"
        aria-label="Radera kontakt permanent"
        data-contact-id="123"
      >
        Radera
      </button>
    </div>
  </div>
</div>
```

---

*Additional design inspiration sources for Sprint 5:*
- [Delete Button UI Best Practices](https://www.designmonks.co/blog/delete-button-ui)
- [Confirmation Dialog Guidelines - NN/G](https://www.nngroup.com/articles/confirmation-dialog/)
- [Modal UX Best Practices](https://www.eleken.co/blog-posts/modal-ux)
- [Helsinki Design System - Danger Dialog](https://hds.hel.fi/components/dialog/)
- [Designing Better Destructive Actions](https://www.designsystemscollective.com/designing-better-buttons-how-to-handle-destructive-actions-d7c55eef6bdf)
- [UX Guide to Destructive Actions](https://medium.com/design-bootcamp/a-ux-guide-to-destructive-actions-their-use-cases-and-best-practices-f1d8a9478d03)