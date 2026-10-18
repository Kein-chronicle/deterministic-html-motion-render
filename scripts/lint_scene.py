#!/usr/bin/env python3
"""Static lint for frame-pure scenes: forbidden time/randomness/network APIs. exit 0 clean | 1 violations | 2 input
usage: lint_scene.py scene.html [more files]
It masks strings, template literals and comments first (a URL inside a string is not a comment), keeps line numbers, then pattern-matches.
It is a pattern check, not a JavaScript parser: computed access such as globalThis["Date"]["now"]() can still slip through, which is why
determinism_check.mjs (the pixel check) is the real proof."""
import re, sys
FORBIDDEN = {
    r"\bDate\.now\b": "Date.now (wall clock)", r"\bnew\s+Date\b": "new Date (wall clock)", r"\bDate\s*\(\s*\)": "Date() (wall clock)",
    r"\bperformance\s*\.\s*now\b": "performance.now (wall clock)", r"\bMath\s*\.\s*random\b": "Math.random (non-deterministic)",
    r"\bMath\s*\[\s*['\"]random['\"]\s*\]": "Math['random'] (non-deterministic)", r"\bcrypto\s*\.\s*getRandomValues\b": "crypto.getRandomValues (non-deterministic)",
    r"\brequestAnimationFrame\b": "requestAnimationFrame (time-driven)", r"\bsetTimeout\b": "setTimeout (time-driven)",
    r"\bsetInterval\b": "setInterval (time-driven)", r"\bfetch\s*\(": "fetch (network)", r"\bXMLHttpRequest\b": "XMLHttpRequest (network)",
    r"\b(?:webkit)?AudioContext\b": "AudioContext (audio belongs to the runtime as cue data)",
}
def mask(src, strings=True):
    """Blank out comments, strings and template literals (keeping every newline) so a '//' inside a URL string cannot hide code."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]; two = src[i:i+2]
        if two == "//": j = src.find("\n", i); j = n if j < 0 else j; out.append(" " * (j - i)); i = j
        elif two == "/*": j = src.find("*/", i + 2); j = n if j < 0 else j + 2; out.append(re.sub(r"[^\n]", " ", src[i:j])); i = j
        elif strings and c in "'\"`":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            j = min(j + 1, n); out.append(c + re.sub(r"[^\n]", " ", src[i+1:j-1]) + (c if j - 1 > i else "")); i = j
        else: out.append(c); i += 1
    return "".join(out)
files = sys.argv[1:]
if not files: print(__doc__); sys.exit(2)
bad = 0
for f in files:
    try: txt = open(f, encoding="utf-8").read()
    except (OSError, UnicodeError) as e: print(f"cannot read {f}: {type(e).__name__}"); sys.exit(2)
    code = mask(txt)                                                      # comments and strings may mention the APIs
    code_keep_strings = mask(txt, strings=False)                          # bracket access names the API INSIDE a string: Math['random']
    for pat, why in FORBIDDEN.items():
        for m in re.finditer(pat, code_keep_strings if "[" in pat else code):
            line = txt[:m.start()].count("\n") + 1
            print(f"{f}:{line}: {why}"); bad += 1
print("clean" if not bad else f"{bad} violation(s)")
sys.exit(1 if bad else 0)
