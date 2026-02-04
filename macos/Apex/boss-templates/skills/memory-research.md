# Memory — Research

Read before every project. Update with new learnings after each project. Max ~20 items.

## Speed

- Your job is to deliver brief.md + research.md as fast as possible — builders are waiting on you.
- Aim for 3 WebFetch calls (brand site + 1 competitor + 1 inspiration) and 2-3 WebSearch calls. More than that rarely adds value and slows down the whole pipeline.
- Do NOT take screenshots — builders have browser tools and can screenshot sites themselves if they need visuals.
- WebFetch is faster than Playwright for extracting text content. Use it as your primary tool.

## Research Quality

- Extract exact hex colors, font names, and weights — builders need precise values, not descriptions like "dark blue".
- Include all relevant URLs in research.md so builders can visit them if they want visual reference.
- Pick inspiration sites from outside the client's industry — this leads to more creative proposals.
- Keep research.md under 60 lines. Dense facts beat long descriptions.

## Tools

- WebFetch extracts page content as text — works for most sites without browser overhead.
- WebSearch finds competitors and inspiration — use specific queries like "[brand] competitors" or "best [industry] website design".
- If WebFetch fails on a site (JS-heavy, requires interaction), fall back to screenshot MCP tool as a last resort.
