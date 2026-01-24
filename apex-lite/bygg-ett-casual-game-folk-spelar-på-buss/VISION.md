# ORBIT - Game Vision Document

## Concept
A minimalist, hypnotic orbital game where you tap to switch gravity fields and collect stars in space.

## Tagline
"Easy to play, beautiful to watch, impossible to put down"

## Target Audience
Commuters aged 18-35 who want something beautiful and relaxing to do on the bus.

## What Makes It Unique
1. **Visually hypnotic** - Soft circles, glowing particles, smooth animations
2. **Satisfying feedback** - Every tap has a subtle "pulse", perfect timing gives combo
3. **Zen but challenging** - No harsh "game over" screen, just soft restart
4. **Progression** - Unlock new color themes, beat your highscore

## Core Loop
1. Tap to switch orbit
2. Collect stars for points
3. Avoid obstacles (smoothly)
4. Streak system for combos
5. Beat your highscore

## Mechanics

### Primary Mechanic: Orbital Switching
- A small orb orbits around a central point
- Tap anywhere to switch to a different orbital path
- Multiple orbital "rings" at different distances
- The orb smoothly transitions between orbits

### Scoring
- Stars spawn on different orbits
- Collect stars by being on the correct orbit when you reach them
- Consecutive stars = combo multiplier
- Miss a star = combo resets (but game continues)

### Challenge (Soft)
- Obstacles (asteroids) appear on some orbits
- Hitting an obstacle = game over (but with beautiful fade, not harsh)
- Speed gradually increases
- More stars and obstacles spawn over time

### Progression
- Highscore saved locally
- Every 10 stars = new ring color unlocked
- Visual themes unlock based on total stars collected
- Daily challenge: Beat yesterday's score

## Visual Style
- Dark space background with subtle gradient
- Neon/glow aesthetic (soft, not harsh)
- Particle trails behind the orb
- Pulsing animations on tap
- Stars that glow and rotate
- Screen shake on collision (subtle)
- Confetti burst on new highscore

## Color Palette
Primary: Deep space blue (#0a0a1a)
Accent 1: Soft cyan (#00d4ff)
Accent 2: Warm orange (#ff6b35)
Stars: Golden yellow (#ffd700)
Obstacles: Soft red (#ff4757)

## Audio (if time)
- Soft ambient background
- Satisfying "ding" on star collect
- Whoosh on orbit switch
- Mellow sound on game over

## Technical Requirements
- FastAPI + Jinja2 + Vanilla JS
- Mobile-first (works on desktop too)
- Touch controls (tap anywhere)
- LocalStorage for scores
- Smooth 60fps animations
- PWA support for offline play
