# Design System

## Color Palette
Modern dark theme with neon mint accents.

| Name | Hex | Usage |
|------|-----|-------|
| primary | #64FFDA | Main buttons, active states, key highlights (Neon Mint) |
| primary-dim | #64FFDA1A | 10% opacity primary for backgrounds/hovers |
| secondary | #CCD6F6 | Headings, hover text (Off-white) |
| background | #0A192F | Main page background (Deep Navy) |
| surface | #112240 | Cards, navbar, sections (Lighter Navy) |
| surface-hover | #233554 | Hover state for cards/interactive elements |
| text | #8892B0 | Body text (Slate Blue-Grey) |
| text-muted | #A8B2D1 | Low priority text |
| border | #233554 | Borders, dividers |
| error | #FF6B6B | Error messages, danger actions |
| success | #64FFDA | Success states (Same as primary) |

## Typography
- **Headings:** 'Inter', sans-serif, 700/600 weight
- **Body:** 'Inter', sans-serif, 400 weight
- **Mono:** 'Fira Code', monospace (for code snippets or tags)

| Element | Size (Desktop) | Size (Mobile) | Weight | Line Height |
|---------|----------------|---------------|--------|-------------|
| h1 | 64px (4rem) | 40px (2.5rem) | 700 | 1.1 |
| h2 | 48px (3rem) | 32px (2rem) | 700 | 1.2 |
| h3 | 32px (2rem) | 24px (1.5rem) | 600 | 1.3 |
| h4 | 24px (1.5rem) | 20px (1.25rem) | 600 | 1.4 |
| body | 18px (1.125rem) | 16px (1rem) | 400 | 1.6 |
| small | 14px (0.875rem) | 14px | 400 | 1.5 |

## Spacing
Base: 4px
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px
- 2xl: 48px
- 3xl: 64px
- 4xl: 96px (Section spacing)

## Border Radius
- sm: 4px (small buttons, tags)
- md: 8px (standard buttons, inputs)
- lg: 16px (cards, large containers)
- full: 9999px (avatars, pills)

## Components

### Buttons
- **Primary:** `bg-transparent text-primary border border-primary hover:bg-primary-dim` (Ghost style popular in tech portfolios)
- **Filled:** `bg-primary text-background font-bold hover:bg-primary/90`
- **Text:** `text-primary hover:underline underline-offset-4`

### Cards
- `bg-surface rounded-lg p-lg shadow-xl`
- Hover effect: `transform translate-y-[-5px] transition-all duration-300`

### Navigation
- Glassmorphism: `bg-background/80 backdrop-blur-md`
- Sticky top
- Links: `text-text hover:text-primary transition-colors`

### Inputs (Contact Form)
- `bg-surface-hover border border-border rounded-md p-md text-secondary focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary`

## UX Principles
- **Minimalism:** Focus on content, plenty of whitespace (negative space).
- **Contrast:** High contrast for text (WCAG AA).
- **Motion:** Subtle fade-ins on scroll, hover effects on interactive elements.
- **Responsiveness:** Single column on mobile, multi-column on desktop. Hamburger menu for mobile nav.
