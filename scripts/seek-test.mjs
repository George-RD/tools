// Seek test: loads a HyperFrames composition, then drives registered timelines
// via CDP and checks that the rendered pixels actually change.
//
// Usage: node seek-test.mjs <composition.html> [<chrome-launch.sh>] [puppeteer-root]
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const here = path.dirname(new URL(import.meta.url).pathname);
const [, , comp, launcher, pupRoot] = process.argv;
if (!comp) {
  console.error('usage: seek-test.mjs <composition.html> [launcher] [puppeteer-root]');
  process.exit(2);
}
const exe = launcher || path.join(here, '..', 'vendor', 'chrome-launch.sh');
const root = pupRoot || path.join(here, '..', 'hyperframes', 'cli', 'node_modules');
const {default: puppeteer} = await import(
  pathToFileURL(path.join(root, 'puppeteer-core', 'lib', 'puppeteer', 'puppeteer-core.js')).href
);

const browser = await puppeteer.launch({
  executablePath: exe,
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
});
try {
  const page = await browser.newPage();
  await page.setViewport({width: 640, height: 360});
  await page.goto(pathToFileURL(path.resolve(comp)).href, {waitUntil: 'networkidle0', timeout: 60000});

  const info = await page.evaluate(() => ({
    timelines: Object.keys(window.__timelines || {}),
    hasGsap: typeof window.gsap !== 'undefined',
    ids: [...document.querySelectorAll('[data-composition-id]')].map((e) => e.dataset.compositionId),
  }));

  async function seekShot(t) {
    await page.evaluate((tt) => {
      const tls = window.__timelines || {};
      for (const k of Object.keys(tls)) {
        const tl = tls[k];
        if (tl && typeof tl.seek === 'function') tl.seek(tt);
      }
    }, t);
    await new Promise((r) => setTimeout(r, 300));
    return (await page.screenshot({type: 'png'})).toString('base64');
  }

  const a = await seekShot(0);
  const b = await seekShot(2);
  const c = await seekShot(5);
  const changed = a !== b || b !== c;
  console.log(JSON.stringify({...info, seekChanged: changed, lenA: a.length, lenB: b.length, lenC: c.length}));
  if (!changed) {
    console.error('SEEK DID NOT CHANGE PIXELS');
    process.exitCode = 1;
  }
} finally {
  await browser.close();
}
