// Optional AI polish (screenshots.md): passes a composed scaffold through
// OpenAI's latest ChatGPT image model ("ducktape", API id gpt-image-1) for
// photorealistic lighting / subtle breakout polish, keeping the app UI intact.
// Deterministic compose remains the backbone; this is a per-screen pass.
//
// Requires OPENAI_API_KEY. Usage:
//   node enhance.mjs --input final/01Main.png --output final/01Main.png \
//     [--prompt "..."] [--model gpt-image-1]
//
// Note: image models vary run-to-run. Review each output; re-run for variants.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve, basename } from 'node:path';

function arg(name, def) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : def;
}

const DEFAULT_PROMPT =
  'Enhance this App Store screenshot: keep the phone UI and all text pixel-exact ' +
  'and legible; improve the background lighting and depth so it looks premium and ' +
  'cohesive. Do not alter, cover, or distort the phone screen content or the caption.';

async function main() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) { console.error('OPENAI_API_KEY not set; skipping AI enhancement.'); process.exit(2); }
  const input = arg('input'), output = arg('output');
  if (!input || !output) { console.error('required: --input <png> --output <png>'); process.exit(1); }
  const model = arg('model', 'gpt-image-1');
  const prompt = arg('prompt', DEFAULT_PROMPT);

  const bytes = await readFile(resolve(input));
  const form = new FormData();
  form.append('model', model);
  form.append('prompt', prompt);
  form.append('input_fidelity', 'high');   // preserve UI + caption pixels
  form.append('image', new Blob([bytes], { type: 'image/png' }), basename(input));

  const res = await fetch('https://api.openai.com/v1/images/edits', {
    method: 'POST', headers: { authorization: `Bearer ${key}` }, body: form,
  });
  if (!res.ok) { console.error(`OpenAI API ${res.status}: ${await res.text()}`); process.exit(1); }
  const json = await res.json();
  const data = json?.data?.[0]?.b64_json;
  if (!data) { console.error('no image in response'); process.exit(1); }

  await mkdir(dirname(resolve(output)), { recursive: true });
  await writeFile(resolve(output), Buffer.from(data, 'base64'));
  console.log(`enhanced -> ${output}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
