# AIRLIFT — Search & Rescue

A 2.5D side-scrolling helicopter rescue game built with React, Vite, TypeScript and a hand-drawn Canvas renderer. Fly three scenarios, lower the winch onto stranded survivors, avoid trees, radio towers, power lines and wildfire, then bring everyone home to the base helipad.

## Run it

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # outputs a self-contained dist/index.html
npm run preview  # serve the production build
```

## Share it

```bash
node scripts/inline-assets.mjs   # produces airlift.html
```

`airlift.html` is the entire game — code, styles and all three backdrop paintings base64-inlined — in one 751 KB file. Double-click it and it plays from `file://`, no server, no build step, no assets folder. Upload that single file to Netlify Drop, Cloudflare Pages, GitHub Pages or itch.io and you have a public link in under a minute.

`dist/` is the conventional build (`index.html` + `images/`) if you would rather host the folder and keep the full-resolution art.

## Controls

| Action | Keyboard | On screen |
| --- | --- | --- |
| Steer left / right | `A` `D` or `←` `→` | Steer buttons |
| Throttle (climb) | hold `W` or `↑` | Throttle button |
| Descend faster | hold `S` or `↓` | — |
| Winch | `Space` or `E` | Deploy winch button |
| Pause / resume | `P` or `Esc` | Scene button |

While the winch is deployed, hover assist holds your altitude. Fly over an orange beacon and the hook catches the survivor automatically; the winch then reels in and stows.

## Missions

1. **Pine Ridge** — North Cascades, light wind, trees and two radio towers.
2. **Storm Coast** — Pacific Northwest, strong crosswinds that drift the aircraft, tall towers with live power lines.
3. **Ember Valley** — Sierra Nevada, drifting ash, updrafts and wall-of-flame hazards.

Each mission tracks fuel, airframe integrity (three hits), flight time and rescued count. Land on the base helipad to refuel; rescue all three survivors and return to base to complete the operation. Completed missions are remembered in `localStorage`.

## Source layout

```
src/
  App.tsx            page shell, HUD, flight deck, dialogs
  index.css          full visual system and responsive breakpoints
  game/engine.ts     game loop, physics, winch, collisions, Canvas rendering
  game/scenarios.ts  terrain, survivors and hazards for the three missions
  game/audio.ts      Web Audio rotor bed and event cues
public/
  images/*.png       parallax backdrop art per scenario
  favicon.svg
tests/rescue.spec.ts Playwright gameplay, control and layout tests
playwright.config.ts
```

## Optional tests

```bash
npx playwright install chromium
npx playwright test
```

The tests drive a real browser: keyboard and touch input, an automated rescue-and-return flight for each mission, collision damage and failure states, mission switching, dialogs, sound toggling and phone-layout overflow. They are not needed to run or build the game.
