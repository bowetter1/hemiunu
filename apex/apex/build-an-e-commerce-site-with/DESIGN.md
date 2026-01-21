# Design System

## Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| primary | #6366f1 | Buttons, links, active states (Indigo 500) |
| primary-hover | #4f46e5 | Hover state for primary buttons (Indigo 600) |
| secondary | #334155 | Secondary buttons, borders (Slate 700) |
| background | #0f172a | Main page background (Slate 900) |
| surface | #1e293b | Cards, headers, modals (Slate 800) |
| surface-hover | #334155 | Hover state for cards/list items (Slate 700) |
| text | #f8fafc | Primary text (Slate 50) |
| text-muted | #94a3b8 | Secondary text, placeholders (Slate 400) |
| accent | #38bdf8 | Highlights, badges (Sky 400) |
| danger | #ef4444 | Delete buttons, errors (Red 500) |
| success | #22c55e | Success messages, stock available (Green 500) |
| border | #334155 | Borders, dividers (Slate 700) |

## Typography
- **Font Family:** 'Inter', system-ui, -apple-system, sans-serif
- **Weights:** 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold)

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| h1 | 32px (2rem) | 700 | 1.2 |
| h2 | 24px (1.5rem) | 600 | 1.3 |
| h3 | 20px (1.25rem) | 600 | 1.4 |
| body | 16px (1rem) | 400 | 1.5 |
| small | 14px (0.875rem) | 400 | 1.5 |
| tiny | 12px (0.75rem) | 500 | 1.5 |

## Spacing
Base: 4px
- xs: 4px (0.25rem)
- sm: 8px (0.5rem)
- md: 16px (1rem)
- lg: 24px (1.5rem)
- xl: 32px (2rem)
- 2xl: 48px (3rem)
- 3xl: 64px (4rem)

## Border Radius
- sm: 4px (inputs, badges)
- md: 8px (buttons, cards)
- lg: 12px (modals, large containers)
- full: 9999px (circular avatars, pill badges)

## Shadows
- sm: 0 1px 2px 0 rgb(0 0 0 / 0.05)
- md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)
- lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)
- glow: 0 0 15px rgba(99, 102, 241, 0.3) (Primary glow)

## Components

### Buttons
- **Primary:** `bg-primary`, `text-white`, `hover:bg-primary-hover`, `rounded-md`, `px-4 py-2`, `font-medium`, `transition-colors`
- **Secondary:** `bg-transparent`, `text-text`, `border border-secondary`, `hover:bg-secondary`, `rounded-md`, `px-4 py-2`, `font-medium`
- **Icon Button:** `p-2`, `rounded-full`, `hover:bg-surface-hover`, `text-text-muted hover:text-text`

### Cards (Product)
- **Container:** `bg-surface`, `rounded-md`, `overflow-hidden`, `shadow-md`, `hover:shadow-lg`, `transition-shadow`, `border border-border`
- **Image:** `w-full`, `h-48`, `object-cover`, `bg-surface-hover` (placeholder)
- **Content:** `p-4`
- **Title:** `text-lg`, `font-semibold`, `text-text`, `mb-1`
- **Price:** `text-accent`, `font-bold`, `text-xl`

### Inputs
- **Base:** `bg-background`, `text-text`, `border border-border`, `rounded-sm`, `px-3 py-2`, `w-full`
- **Focus:** `outline-none`, `ring-2`, `ring-primary`, `border-transparent`
- **Placeholder:** `text-text-muted`

### Search & Filter (Sprint 2)
- **Controls Bar:** Container above grid. `flex`, `flex-col sm:flex-row`, `gap-4`, `mb-6`, `justify-between`.
- **Search Input:**
  - Extends **Inputs**.
  - **Icon:** Include magnifying glass icon (left or right).
  - **Width:** `w-full sm:w-64 lg:w-80`.
- **Select Dropdowns:**
  - **Style:** Matches **Inputs** (`bg-background`, `text-text`, `border-border`).
  - **Arrow:** Custom SVG arrow or system default styled to match text color.
  - **Options:** `bg-surface` (ensure visibility in dark mode).
  - **Hover:** `cursor-pointer`.

### Badges
- **Base:** `px-2 py-0.5`, `rounded-full`, `text-xs`, `font-semibold`
- **New/Accent:** `bg-accent/10`, `text-accent`
- **Stock:** `bg-success/10`, `text-success`

### Navigation
- **Bar:** `bg-surface`, `border-b border-border`, `h-16`, `flex items-center`
- **Link:** `text-text-muted`, `hover:text-primary`, `font-medium`, `transition-colors`

## UX Principles
- **Dark Mode First:** All colors optimized for low-light viewing.
- **Visual Hierarchy:** Use font weight and color (text vs text-muted) to guide the eye.
- **Feedback:** All interactive elements must have a hover and active state.
- **Images:** Product images should have a subtle overlay or background to blend with dark theme if transparent.
