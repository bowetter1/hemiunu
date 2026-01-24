# 🚕 Cargo Panic

A taxi driving game where your passengers FREAK OUT when you drift!

## Play Now

1. Start the server:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  
   pip install flask
   python main.py
   ```

2. Open http://localhost:8000 in your browser

## How to Play

- **Arrow Keys** or **WASD** - Drive the taxi
- Pick up passengers (green markers 🧑)
- Deliver them to destinations (orange markers 📍)
- **DON'T PANIC THEM!** Drifting scares passengers!

## The Challenge

- **Drifting** is fast but increases PANIC
- **Smooth driving** is slow but keeps passengers calm
- If panic reaches 100%, your passenger BAILS OUT!
- Deliver passengers to earn score and bonus time

## Game Features

- Dynamic panic system with visual feedback
- Drift physics with tire smoke effects
- Animated passengers that react to your driving
- Time pressure with bonus time per delivery
- Screen shake on high panic moments

## Tech Stack

- **Phaser 3** - Game engine
- **Flask** - Python web server
- **Pear36** - Color palette from Lospec

## Project Structure

```
src/
  config/         - Game constants and colors
  entities/       - Car and Passenger classes  
  scenes/         - Menu, Game, GameOver scenes
  systems/        - Screen effects
  main.js         - Entry point
```

---

Built with ❤️ as a unique twist on racing games
