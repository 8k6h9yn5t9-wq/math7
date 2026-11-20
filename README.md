# Math 7 Practice

An iPad-friendly web app for 7th grade math practice. It follows the class pacing, generates new problems every time, and includes a scratchpad for Apple Pencil, progress tracking and a PIN-locked parent view.

**Use it:** open https://8k6h9yn5t9-wq.github.io/math7/ in Safari on the iPad, tap **Share**, then **Add to Home Screen**. After the first visit it works offline.

## Files
- `index.html`: page layout and styles
- `problems.js`: problem generators for all 10 units, 3 difficulty levels each, plus the class pacing calendar (`PACING`)
- `app.js`: screens, keypad, scratchpad, progress tracking and parent view
- `sw.js`, `manifest.webmanifest`, icons: offline support and home-screen install

Progress is stored in the browser on the device (localStorage). Use **Back up progress** in the parent view to save a copy.

No build step. To change the current class unit's dates, edit `PACING` in `problems.js`, or pick a unit in the parent view.

## iPad app (native)

The `ios/` folder has a native SwiftUI version with Apple Pencil handwriting answers and an optional Roblox lock
(Screen Time) that unlocks games when the daily goal is met. It uses the same `problems.js`. See [ios/SETUP.md](ios/SETUP.md).
