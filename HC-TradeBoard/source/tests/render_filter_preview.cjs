// Pipe ui_smoke.lua --preview output into this optional geometry preview renderer.
// Usage: <lua test output> | node render_filter_preview.cjs <output-prefix> [sharp-module]
const fs = require('node:fs');
const path = require('node:path');

const output = process.argv[2];
if (!output) throw new Error('Pass a path prefix for the generated SVG and PNG.');
const sharp = require(process.argv[3] || 'sharp');
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', async () => {
  try {
    const match = input.match(/FILTER_PREVIEW_BEGIN\s*([\s\S]*?)\s*FILTER_PREVIEW_END/);
    if (!match || !input.includes('HC TradeBoard UI smoke test passed:')) {
      throw new Error(`UI test failed or did not emit a preview:\n${input}`);
    }
    fs.mkdirSync(path.dirname(path.resolve(output)), { recursive: true });
    fs.writeFileSync(`${output}.svg`, match[1]);
    await sharp(Buffer.from(match[1])).png().toFile(`${output}.png`);
    process.stdout.write(`Saved filter geometry preview: ${output}.png\n`);
  } catch (error) {
    process.stderr.write(`${error.stack}\n`);
    process.exitCode = 1;
  }
});
