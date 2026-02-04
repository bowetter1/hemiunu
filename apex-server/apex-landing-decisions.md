# Apex Landing Page — Design Decisions

## AI Team Input

### Gemini (gemini-2.5-pro) — "Dark Mode Industrialism"
- Near-black bg `#050505`, cyan accent `#00F0FF`, neon red `#FF2E63`
- Space Grotesk + Inter + JetBrains Mono
- Split hero: copy left, live terminal right
- Scramble text decode animation, spotlight hover on cards
- Glass HUD concept, grid background

### Codex (gpt-5.2-codex) — "Industrial Sci-fi + Developer Trust"
- Coal-black bg `#0B0E13`, neon mint `#30F2A2`, blue `#5B7CFF`
- Space Grotesk + IBM Plex Sans + IBM Plex Mono
- Pipeline visualization in hero
- Diagonal clip-path sections, staggered reveals
- Code + result side by side

## Synthesized Decision

**Taking from Gemini:**
- Scramble text decode animation (standout effect)
- Spotlight hover effect on feature cards
- Split hero layout (copy + terminal)
- Grid background with subtle animation

**Taking from Codex:**
- Color palette: mint green `#30F2A2` + blue `#5B7CFF` (more distinctive than cyan)
- IBM Plex Mono for code (better developer recognition)
- Diagonal clip-path sections
- Pipeline visualization (Build → Test → Deploy)

**Final palette:**
- Background: `#0A0D12`
- Surface: `#111827`
- Primary accent: `#30F2A2` (mint)
- Secondary accent: `#5B7CFF` (blue)
- Alert: `#FF2E63` (red, sparingly)
- Text: `#E6E9EF`
- Muted: `#94A3B8`
- Border: `#1E293B`

**Fonts:** Space Grotesk (headings), Inter (body), IBM Plex Mono (code)

**Hero copy:** "Build Software at the Speed of Thought" (Gemini's, stronger in English)

---

## V2 Review Round

### Gemini Review Feedback (applied):
1. Aurora ambient light blobs — adds depth (Linear/Raycast style)
2. Animated pipeline beam — data flowing left→right
3. Glassmorphism terminal — backdrop-filter, inner shadow, top highlight
4. Infinite tech marquee — scrolling tech stack strip
5. Gradient heading + text-wrap: balance — premium typography

### Codex Review Feedback (applied):
1. Floating artifact cards around terminal — file tree + preview URL
2. Stats strip — "2.1s sandbox creation", "0 environment setup"
3. Hero bullets + sharper CTA — "Generate a Live URL →" instead of generic
4. CTA arrow animation — slides right on hover
5. Case study section — "From Prompt to Live URL" with build.log output

### V2 Result
All 10 suggestions integrated. Live at Daytona sandbox.
Key improvements: gradient heading, ambient lights, glassmorphism, artifact cards,
stats strip, marquee, case study, sharper copy, pipeline beam, scroll reveals.
