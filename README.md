# deterministic-html-motion-render

**Lint and verify HTML motion scenes so any frame can be rendered exactly, in any order: no wall clock, no randomness, no timers.**

[![test](https://github.com/Kein-chronicle/deterministic-html-motion-render/actions/workflows/test.yml/badge.svg)](https://github.com/Kein-chronicle/deterministic-html-motion-render/actions/workflows/test.yml) ![license](https://img.shields.io/badge/license-MIT-blue.svg)

## Why

Frame-exact rendering needs a scene that is a pure function of time. This checks the source for the usual leaks and then proves it in a browser by rendering the same frames twice in a different order and comparing pixels.

## Install

**As a Claude Code skill** (Claude uses it when the task matches the skill description):

```sh
git clone https://github.com/Kein-chronicle/deterministic-html-motion-render.git ~/.claude/skills/deterministic-motion-render
```

For a single project, clone into `<project>/.claude/skills/deterministic-motion-render` instead, then start a new Claude Code session.

**As plain scripts:**

```sh
git clone https://github.com/Kein-chronicle/deterministic-html-motion-render.git
cd deterministic-html-motion-render
```

**Requires:** Node.js 22+ and Python 3.10+ and bash, Playwright (for determinism_check.mjs).

Install the browser test runtime:

```sh
npm install --no-save playwright@1.64.1
npx playwright install chromium
```

## Quick start

Lint a clean and a forbidden scene:

```console
$ bash examples/demo.sh
# Static lint: scene code that cannot be replayed frame-exact
$ python3 scripts/lint_scene.py examples/scene.html
clean
[exit 0]

$ python3 scripts/lint_scene.py examples/scene_forbidden.html
examples/scene_forbidden.html:2: Date.now (wall clock)
examples/scene_forbidden.html:4: Math.random (non-deterministic)
examples/scene_forbidden.html:4: setTimeout (time-driven)
3 violation(s)
[exit 1]

# Behavioural check: render the same frames twice, in a different order, and compare pixels (needs Playwright)
(install first:  npm install playwright && npx playwright install chromium)
```

The output above is real: it is produced by the files in `examples/`.

## Use it on your own files

```sh
python3 scripts/lint_scene.py my-scene.html
node scripts/determinism_check.mjs my-scene.html --frames 0,30,60   # needs: npm install playwright
```

Sample inputs for every file format are in `examples/` and `tests/`; the details are in [SKILL.md](SKILL.md).

## What it checks

- `lint_scene.py`: flags `Date.now`, `Math.random`, `setTimeout` and similar in scene code.
- `determinism_check.mjs scene.html [--frames a,b,c]`: renders frames twice in different orders and compares them (needs Playwright).

## Limits

- Verification only, not a renderer.
- Needs Playwright for the pixel check.

## Related projects

These solve neighbouring problems; use them when they fit better.

- **Remotion**: React-based video rendering
- **Motion Canvas**: TypeScript animation tool

## More from the same collection

Small, tested tools that grew out of running AI agents and game/app pipelines for months:

- [**canvas-render-pixel-gate**](https://github.com/Kein-chronicle/canvas-render-pixel-gate): Detect grey-box screenshots: measure unique colors and flat-fill share of a rendered game canvas, and refuse to pass what it could not measure.
- [**web-game-asset-reality-check**](https://github.com/Kein-chronicle/web-game-asset-reality-check): Catch web-game bugs the type checker can't: fonts that are declared but not shipped, runtime CDN dependencies, and page errors from headless Chromium.
- [**ffmpeg-video-qa-gates**](https://github.com/Kein-chronicle/ffmpeg-video-qa-gates): Machine QA for short videos with ffmpeg: frozen frames, dead air, loudness, true peak, size, a busy opening, and readable subtitle timing.

## Development

```sh
env REQUIRE_BROWSER=1 bash run_tests.sh
```

The tests include inputs that are supposed to be rejected, so a green run also shows the checks can fail. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

If this saved you a debugging session, a star helps other people find it. Bug reports and failing test cases are even better.

<sub>Keywords: motion-graphics, html, video, playwright, determinism, animation, rendering, claude-skills</sub>
