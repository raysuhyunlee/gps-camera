// Optional AI polish (screenshots.md): passes a composed scaffold through
// Google's "Nano Banana" image model (Gemini 2.5 Flash Image) for photorealistic
// lighting / subtle breakout polish, keeping the app UI intact. Deterministic
// compose remains the backbone; this is a per-screen enhancement pass.
//
// Requires GEMINI_API_KEY. Usage:
//   node enhance.mjs --input final/01Main.png --output final/01Main.png \
//     [--prompt "..."] [--model gemini-2.5-flash-image]
//
// Note: image models vary run-to-run. Review each output; re-run for variants.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const DEFAULT_PROMPT =
  'Enhance this App Store screenshot: keep the phone UI and all text pixel-exact ' +
  'and legible; improve the background lighting and depth so it looks premium and ' +
  'cohesive. Do not alter, cover, or distort the phone screen content or the caption.';

async function main() {
  const key = process.env.GEMINI_API_KEY;
  if (!key) { console.error('GEMINI_API_KEY not set; skipping AI enhancement.'); process.exit(2); }
  const input = arg('input'), output = arg('output');
  if (!input || !output) { console.error('required: --input <png> --output <png>'); process.exit(1); }
  const model = arg('model', 'gemini-2.5-flash-image');
  const prompt = arg('prompt', DEFAULT_PROMPT);

  const b64 = (await readFile(resolve(input))).toString('base64');
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`;
  const body = {
    contents: [{
      role: 'user',
      parts: [{ text: prompt }, { inline_data: { mime_type: 'image/png', data: b64 } }],
    }],
  };

  const res = await fetch(url, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
  });
  if (!res.ok) { console.error(`Gemini API ${res.status}: ${await res.text()}`); process.exit(1); }
  const json = await res.json();
  const part = json?.candidates?.[0]?.content?.parts?.find((p) => p.inline_data || p.inlineData);
  const data = part?.inline_data?.data ?? part?.inlineData?.data;
  if (!data) { console.error('no image in response'); process.exit(1); }

  await mkdir(dirname(resolve(output)), { recursive: true });
  await writeFile(resolve(output), Buffer.from(data, 'base64'));
  console.log(`enhanced -> ${output}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
