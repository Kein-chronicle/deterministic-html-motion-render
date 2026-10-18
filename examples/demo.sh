#!/usr/bin/env bash
cd "$(dirname "$0")/.."
run() { printf '$ %s\n' "$*"; "$@"; printf '[exit %s]\n\n' "$?"; }
echo "# Static lint: scene code that cannot be replayed frame-exact"
run python3 scripts/lint_scene.py examples/scene.html
run python3 scripts/lint_scene.py examples/scene_forbidden.html
echo "# Behavioural check: render the same frames twice, in a different order, and compare pixels (needs Playwright)"
if [ -d node_modules/playwright ] || [ -n "${NODE_PATH:-}" ]; then
  run node scripts/determinism_check.mjs examples/scene.html
  run node scripts/determinism_check.mjs examples/scene_nondeterministic.html
else
  echo "(install first:  npm install playwright && npx playwright install chromium)"
fi
