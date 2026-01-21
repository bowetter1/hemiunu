# Design System

## Color Palette
| Name | Hex | Usage |
|------|-----|-------|
| primary | #4F46E5 | Main actions (Add button), focus rings |
| secondary | #4338CA | Primary hover state |
| background | #F3F4F6 | Page background (Gray 100) |
| surface | #FFFFFF | Cards, inputs, list items |
| text | #1F2937 | Body text (Gray 800) |
| text-muted | #9CA3AF | Completed items, placeholder text (Gray 400) |
| danger | #EF4444 | Delete actions |
| danger-hover | #DC2626 | Delete hover state |
| border | #E5E7EB | Borders (Gray 200) |

## Typography
- **Font Family:** System UI (`-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`)
- **Base Size:** 16px

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| h1 | 2rem (32px) | 700 (Bold) | 1.25 |
| body | 1rem (16px) | 400 (Regular) | 1.5 |
| button | 0.875rem (14px) | 500 (Medium) | 1.25 |

## Spacing
Base: 4px
- xs: 4px (0.25rem)
- sm: 8px (0.5rem)
- md: 16px (1rem)
- lg: 24px (1.5rem)
- xl: 32px (2rem)
- 2xl: 48px (3rem)

## Border Radius
- sm: 4px (inputs)
- md: 6px (buttons, list items)
- lg: 8px (main container card)

## Shadows
- sm: `0 1px 2px 0 rgba(0, 0, 0, 0.05)` (cards, items)

## Components

### Layout
- **Container:** Max-width 480px, centered horizontally, `mt-xl`.
- **Background:** Page uses `background` color.

### Main Card
- `bg-surface`, `rounded-lg`, `shadow-sm`, `p-lg`.

### Header
- `h1` styled, centered or left-aligned. `text` color. `mb-lg`.

### Add Todo Form
- **Layout:** Flex row, gap `md`.
- **Input:**
  - `flex-1` (takes available space).
  - `bg-surface`, `border` color.
  - `rounded-md`, `p-sm`.
  - Focus: `ring-2 ring-primary/50`, `border-primary`.
- **Button (Primary):**
  - `bg-primary`, `text-white`.
  - `px-md`, `py-sm`.
  - `rounded-md`.
  - Hover: `bg-secondary`.
  - Focus: `ring-2 ring-offset-2 ring-primary`.

### Todo List
- **List Container:** `mt-lg`, `flex flex-col`, `gap-sm`.
- **Todo Item:**
  - Flex row, align center, justify between.
  - `bg-surface` (or transparent if inside card), `border` bottom (optional) or `rounded-md` + `border` + `shadow-sm`.
  - Padding `p-sm` or `p-md`.
- **Checkbox:**
  - Custom or native accent `primary`.
  - Clicking text/container should toggle checkbox.
- **Text:**
  - Normal: `text` color.
  - Completed: `text-muted` color, `line-through`.
- **Delete Button:**
  - Icon based (Trash) or text "Delete".
  - `text-danger`.
  - Hover: `bg-red-50` or `text-danger-hover`.
  - Opacity: 0 (hidden) by default, 100 on hover (group-hover) for desktop, always visible on mobile.

## UX Principles
- **Simplicity:** Focus on the content (the tasks).
- **Feedback:** Immediate visual update on add/delete/complete.
- **Accessibility:** High contrast text. Focus states for keyboard navigation.
- **Mobile-first:** Large touch targets (min 44px) for check/delete actions.
