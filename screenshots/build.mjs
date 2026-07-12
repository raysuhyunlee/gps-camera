// Turnkey compose driver (screenshots.md): frames every raw simulator capture
// into a store-ready image. Reads ../ios/fastlane/screenshots_raw/<locale>/*.png,
// looks up per-screen captions, and writes ../ios/fastlane/screenshots/<locale>/.
//
// Usage: node build.mjs [--raw <dir>] [--out <dir>] [--captions <dir>]
// The AI polish step (enhance.mjs) is applied separately, before or after this,
// per the skill's orchestration.

import { readdir, readFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const HERE = dirname(fileURLToPath(import.meta.url));
function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const rawDir = resolve(arg('raw', join(HERE, '../ios/fastlane/screenshots_raw')));
const outDir = resolve(arg('out', join(HERE, '../ios/fastlane/screenshots')));
const capDir = resolve(arg('captions', join(HERE, 'captions')));

// Raw files are "<device>-<screen>.png"; the screen key is the last segment.
const screenKey = (file) => basename(file, '.png').split('-').pop();
// One store listing holds every device's shots, so the output name carries the
// device too; deliver routes each file to a display type by its pixel size.
const deviceKey = (file) => (/ipad/i.test(file) ? 'ipad' : 'iphone');

async function loadCaptions(locale) {
  for (const name of [`${locale}.json`, 'en-US.json']) {
    const p = join(capDir, name);
    if (existsSync(p)) return JSON.parse(await readFile(p, 'utf8'));
  }
  return {};
}

function compose(opts) {
  return new Promise((res, rej) => {
    const args = ['compose.mjs',
      '--screenshot', opts.screenshot, '--output', opts.output,
      '--line1', opts.line1 ?? '', '--line2', opts.line2 ?? '', '--bg', opts.bg ?? '#0B6E4F'];
    if (opts.fg) args.push('--fg', opts.fg);
    if (opts.font) args.push('--font', opts.font);
    const p = spawn('node', args, { cwd: HERE, stdio: 'inherit' });
    p.on('close', (c) => (c === 0 ? res() : rej(new Error(`compose exited ${c}`))));
  });
}

async function main() {
  if (!existsSync(rawDir)) { console.error(`no raw dir: ${rawDir}`); process.exit(1); }
  const locales = (await readdir(rawDir, { withFileTypes: true }))
    .filter((d) => d.isDirectory()).map((d) => d.name);

  for (const locale of locales) {
    const captions = await loadCaptions(locale);
    const files = (await readdir(join(rawDir, locale))).filter((f) => f.endsWith('.png'));
    await mkdir(join(outDir, locale), { recursive: true });
    for (const file of files) {
      const key = screenKey(file);
      const cap = captions[key] ?? {};
      await compose({
        screenshot: join(rawDir, locale, file),
        output: join(outDir, locale, `${deviceKey(file)}-${key}.png`),
        ...cap,
      });
    }
    console.log(`  ${locale}: ${files.length} screens`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
