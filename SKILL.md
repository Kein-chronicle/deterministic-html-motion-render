---
name: deterministic-motion-render
description: Build or audit a code-driven motion-graphics / video renderer (HTML+CSS+JS scenes captured frame by frame with headless Chrome and ffmpeg) so output is reproducible. Use when AI-written animation code renders differently on re-runs, when jumping to a frame gives a different image than playing up to it, when an agent writes scene code that must not touch clocks/randomness/network, or when you want sound as data (cue lists) instead of audio code.
---

# deterministic-motion-render

Core idea: **a frame is a pure function of its index.** The scene code (often written by an AI) only implements
`window.__seek(frame)`; the runtime owns everything else.

## Contract

1. Scenes are authored at one fixed **design size** (e.g. 1920x1080). Lower-quality drafts scale by device scale
   factor only; never re-layout at a smaller size.
2. **The runtime owns the contract**, not the model: it assembles `__seek`, scene transitions, preloads fonts, and
   *hooks/forbids* `Date.now`, `new Date`, `performance.now`, `Math.random`, `requestAnimationFrame`, `setTimeout`,
   `setInterval`, `fetch`, `XMLHttpRequest`. `scripts/lint_scene.py` checks the same list statically.
3. **Sound is data, not code.** The model emits a cue list (kind, frame, frequency, length, gain). A fixed synth in the
   renderer produces audio from a seed. Scene code never touches an audio API (so it can't, and the linter bans it).
   Loudness: aim near a target (e.g. -16 LUFS, true peak <= -1.5 dBTP); when a limit conflicts, yield loudness first.
4. After `__seek(f)`, **force a full re-layout/re-raster** by toggling `display:none` -> `''` on the stage root.
   Without it, Chrome rasterises text edges slightly differently depending on the previous frame (observed: up to
   29/255 per pixel on glyph edges between a continuous render and a jump render). With it, hashes match exactly.

## Gates (run them)

| Gate | Test |
|---|---|
| D-01 | render frames in ascending order, hash each |
| D-02 | render the same frames in a shuffled order; every hash must equal D-01's |
| lint | forbidden APIs (wall clock, randomness, timers, network, AudioContext), found even after a `://` URL inside a string or with bracket access. It does NOT detect state mutated inside `__seek`: that is what D-01/D-02 prove |
| not-a-no-op | frames that all render identically fail: a `__seek` that changes nothing proves nothing |

```bash
node scripts/determinism_check.mjs examples/scene.html          # exit 0 pure | 1 mismatch or never changes | 2 bad args | 3 unmeasured
# Only the frames you sample are proven. Sample across the whole timeline: --frames 0,30,60,90
python3 scripts/lint_scene.py scene.html
PW_DIR=/path/to/project-with-playwright ./run_tests.sh          # forgery test: stateful scene must be caught
```
Test determinism on your real content (text, transforms, fonts), not a demo scene: a toy scene can pass where a real one fails. The gate, not human review, should be what finds it.

## Process notes

- Keep the gate list **fixed**; what you could not measure stays as an explicit UNKNOWN slot. "Not seen" must never read as "passed".
- Show failed checks on public samples instead of hiding them; it keeps the quality claim honest.
- Render on the user's machine or a machine with a real browser and enough memory, not on a tiny shared web server.
- Keep sample content, tests and docs about neutral fictional subjects; do not let one real video or topic leak into them.
