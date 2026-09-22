// CDP smoke test for a chrome-headless-shell binary: launches with puppeteer-core,
// opens a data: page, reads the rendered text, and screenshots via CDP.
//
// Usage: node cdp-smoke.mjs <path-to-chrome-binary> [--env LD_LIBRARY_PATH=...] [<puppeteer-root>]
// Used by scripts/verify.sh to check the vendored browser + vendored libraries.
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const [, , bin, ...rest] = process.argv;
if (!bin) {
  console.error('usage: cdp-smoke.mjs <chrome-binary> [puppeteer-root]');
  process.exit(2);
}
let puppeteerRoot = rest.find((a) => !a.startsWith('--'));
const here = path.dirname(new URL(import.meta.url).pathname);
puppeteerRoot = puppeteerRoot || path.join(here, '..', 'hyperframes', 'cli', 'node_modules');

const {default: puppeteer} = await import(
  pathToFileURL(path.join(puppeteerRoot, 'puppeteer-core', 'lib', 'puppeteer', 'puppeteer-core.js')).href
);

const browser = await puppeteer.launch({
  executablePath: bin,
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
});
try {
  const page = await browser.newPage();
  await page.setViewport({width: 300, height: 120});
  await page.setContent('<html><body style="background:#282828"><h1 id="t" style="color:#57A5E0">cdp ok</h1></body></html>');
  const text = await page.$eval('#t', (el) => el.textContent);
  const version = await browser.version();
  // Screenshot through CDP (the same path renderers use).
  const shot = await page.screenshot({type: 'png'});
  console.log(JSON.stringify({ok: text === 'cdp ok', text, version, screenshotBytes: shot.length}));
  if (text !== 'cdp ok' || shot.length < 100) process.exitCode = 1;
} finally {
  await browser.close();
}
