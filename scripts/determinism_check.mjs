#!/usr/bin/env node
// D-01/D-02 gate: the same frame rendered in continuous order and in shuffled "jump" order must be pixel-identical.
// usage: node determinism_check.mjs scene.html [--frames 0,15,30,45,60,89] [--width 640 --height 360]
// exit 0 deterministic | 1 mismatch or a scene that never changes | 2 bad arguments | 3 could not measure (no playwright/browser, scene not loadable)
// Only the frames you sample are proven: randomness that appears only at other frames is not seen. Sample frames across the whole timeline.
// Contract: the page exposes window.__seek(frameIndex) which sets the whole visual state from the index alone.
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const args = process.argv.slice(2);
const valueIdx = new Set(['--frames', '--width', '--height'].map((n) => args.indexOf(n)).filter((i) => i >= 0).map((i) => i + 1));
const file = args.find((a, i) => !a.startsWith('--') && !valueIdx.has(i));          // flags may come before the file
const opt = (n, d) => { const i = args.indexOf('--' + n); return i >= 0 ? args[i + 1] : d; };
if (!file) { console.error('usage: determinism_check.mjs scene.html [--frames a,b,c]'); process.exit(2); }
const frames = opt('frames', '0,15,30,45,60,89').split(',').map(Number);
if (frames.length < 2 || frames.some((f) => !Number.isInteger(f) || f < 0)) { console.error('--frames needs at least two non-negative integers, e.g. 0,30,60'); process.exit(2); }
const W = Number(opt('width', 640)), H = Number(opt('height', 360));

let chromium;
try { ({ chromium } = await import('playwright')); } catch { console.log('UNMEASURED: playwright not installed (npm i -D playwright)'); process.exit(3); }

const browser = await chromium.launch().catch((e) => { console.log('UNMEASURED: cannot launch browser: ' + e.message.split('\n')[0]); process.exit(3); });
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
try { await page.goto(pathToFileURL(resolve(file)).href); } catch (e) { await browser.close(); console.log('UNMEASURED: could not open the scene: ' + e.message.split('\n')[0]); process.exit(3); }
await page.waitForFunction(() => typeof window.__seek === 'function', null, { timeout: 5000 }).catch(() => {
  console.log('FAIL: page does not expose window.__seek(frame)'); process.exit(1);
});

const shot = async (f) => {
  await page.evaluate((fr) => {
    window.__seek(fr);
    // Force a full re-layout + re-raster. Without this, Chrome can leave sub-pixel differences that depend on the
    // previous frame (seen: glyph edges off by up to 29/255 between continuous and jump renders).
    const s = document.getElementById('stage'); if (s) { s.style.display = 'none'; void s.offsetHeight; s.style.display = ''; }
  }, f);
  const buf = await page.screenshot({ clip: { x: 0, y: 0, width: W, height: H } });
  return createHash('sha256').update(buf).digest('hex').slice(0, 16);
};

const continuous = {}; for (const f of [...frames].sort((a, b) => a - b)) continuous[f] = await shot(f);   // D-01
const shuffled = [...frames].reverse().sort((a, b) => ((a * 7) % 5) - ((b * 7) % 5));                      // D-02 (fixed odd order)
if (new Set(Object.values(continuous)).size < 2) { await browser.close(); console.log('FAIL: every sampled frame renders identically, so __seek changes nothing and this check would prove nothing (is the scene animated?)'); process.exit(1); }
const bad = [];
for (const f of shuffled) { const h = await shot(f); if (h !== continuous[f]) bad.push(f); }
await browser.close();
if (bad.length) { console.log(`FAIL: frames ${bad.join(', ')} differ between continuous and jump rendering (scene is not a pure function of the frame index)`); process.exit(1); }
console.log(`PASS: ${frames.length} frames identical in continuous and shuffled order`); process.exit(0);
