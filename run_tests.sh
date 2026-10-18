#!/usr/bin/env bash
tmpf="$(mktemp)"; trap 'rm -f "$tmpf"' EXIT
set -u; here="$(cd "$(dirname "$0")" && pwd)"; bad=0
# playwright is resolved from the nearest node_modules; set PW_DIR to a project that has it
export NODE_PATH="${PW_DIR:+$PW_DIR/node_modules}"
cd "$here"
if [ -n "${PW_DIR:-}" ]; then ln -sfn "$PW_DIR/node_modules" "$here/scripts/node_modules"; trap 'rm -f "$here/scripts/node_modules"' EXIT; fi
have_pw() { (cd scripts && node -e "import('playwright').then(()=>process.exit(0),()=>process.exit(1))" 2>/dev/null); }
if have_pw; then
  node scripts/determinism_check.mjs examples/scene.html >"$tmpf" 2>&1; rc=$?; [ $rc = 0 ] && echo "ok   pure scene is deterministic" || { echo "FAIL pure scene rc=$rc"; cat "$tmpf"; bad=1; }
  node scripts/determinism_check.mjs examples/scene_nondeterministic.html >"$tmpf" 2>&1; rc=$?; [ $rc = 1 ] && grep -q "differ between continuous and jump" "$tmpf" && echo "ok   stateful scene is caught (for the right reason)" || { echo "FAIL stateful scene rc=$rc"; cat "$tmpf"; bad=1; }
  out=$(node scripts/determinism_check.mjs examples/scene_static.html 2>&1); rc=$?; [ $rc = 1 ] && echo "$out" | grep -q "renders identically" && echo "ok   a scene whose __seek does nothing is not 'deterministic'" || { echo "FAIL static scene rc=$rc"; echo "$out"; bad=1; }
  node scripts/determinism_check.mjs --frames 0,30 examples/scene.html >/dev/null 2>&1; [ $? = 0 ] && echo "ok   flags may come before the scene path" || { echo "FAIL arg order"; bad=1; }
  node scripts/determinism_check.mjs examples/does-not-exist.html >/dev/null 2>&1; [ $? = 3 ] && echo "ok   a missing scene is unmeasured (3)" || { echo "FAIL missing scene"; bad=1; }
else [ "${REQUIRE_BROWSER:-0}" = 1 ] && { echo "UNMEASURED: required browser checks unavailable"; exit 3; }; echo "SKIPPED browser checks: Playwright not found (npm install playwright && npx playwright install chromium, or set PW_DIR). The pixel check did NOT run."; fi
python3 scripts/lint_scene.py examples/scene.html >/dev/null; [ $? = 0 ] && echo "ok   lint: clean scene passes" || { echo "FAIL lint clean"; bad=1; }
out=$(python3 scripts/lint_scene.py examples/scene_forbidden.html); [ $? = 1 ] && echo "$out" | grep -q 'Math.random' && echo "$out" | grep -q 'setTimeout' && ! echo "$out" | grep -q ':3:' && echo "ok   lint: forbidden APIs caught, comments ignored" || { echo "FAIL lint forbidden"; echo "$out"; bad=1; }
lt() { printf '%s\n' "$2" > "$tmpf.html"; python3 scripts/lint_scene.py "$tmpf.html" >/dev/null; [ $? = $3 ] && echo "ok   lint: $1" || { echo "FAIL lint: $1"; bad=1; }; }
lt "a URL inside a string does not hide a later Math.random" 'const u = "http://x"; const r = Math.random();' 1
lt "Math['random'] bracket access is caught" "const r = Math['random']();" 1
lt "new Date without parentheses is caught" "const d = new Date;" 1
lt "webkitAudioContext is caught" "new webkitAudioContext();" 1
lt "a comment mentioning the API is fine" "// Date.now is banned" 0
rm -f "$tmpf" "$tmpf.html"; exit $bad
