// Deterministic compose stage (screenshots.md): frame a raw simulator capture
// with a device bezel + 2-line caption on a solid background, at App Store
// dimensions. Playwright renders web/renderer.html; no AI, fully reproducible.
//
// Usage:
//   node compose.mjs --screenshot raw/01Main.png --output final/01Main.png \
//     --line1 "Stamp every shot" --line2 "with GPS + location" --bg "#0B6E4F"
//
// Options: --fg (caption color, default #fff), --font (CSS family stack),
//   --width/--height (default 1320x2868, iPhone 6.9"), --device-scale (0.78),
//   --font-scale (0.058), --corner-scale (0.09).

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const HERE = dirname(fileURLToPath(import.meta.url));

function args(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    if (argv[i].startsWith('--')) out[argv[i].slice(2)] = argv[i + 1];
  }
  return out;
}

async function main() {
  const a = args(process.argv);
  if (!a.screenshot || !a.output) {
    console.error('required: --screenshot <in.png> --output <out.png>');
    process.exit(1);
  }
  const width = Number(a.width ?? 1320);
  const height = Number(a.height ?? 2868);

  const imgData = await readFile(resolve(a.screenshot));
  const cfg = {
    image: `data:image/png;base64,${imgData.toString('base64')}`,
    line1: a.line1 ?? '',
    line2: a.line2 ?? '',
    bg: a.bg ?? '#0B6E4F',
    fg: a.fg ?? '#ffffff',
    font: a.font ?? '',
    width, height,
    deviceScale: Number(a['device-scale'] ?? 0.78),
    fontScale: Number(a['font-scale'] ?? 0.058),
    cornerScale: Number(a['corner-scale'] ?? 0.09),
  };

  const html = await readFile(resolve(HERE, 'web/renderer.html'), 'utf8');

  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
    page.on('pageerror', (e) => console.error('[page error]', e.message));
    await page.setContent(html, { waitUntil: 'load' });
    await page.evaluate((c) => window.render(c), cfg);
    await page.waitForFunction('window.__ready === true', { timeout: 15000 });
    await mkdir(dirname(resolve(a.output)), { recursive: true });
    await page.screenshot({ path: resolve(a.output), clip: { x: 0, y: 0, width, height } });
  } finally {
    await browser.close();
  }
  console.log(`composed -> ${a.output}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
