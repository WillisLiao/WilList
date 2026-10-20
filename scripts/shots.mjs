// Screenshots of every tab with the sample week, for design review.
//   node scripts/shots.mjs <out dir> [light|dark] [phone|desktop]
// Needs Playwright (see tests/e2e.mjs). The clock is fixed so shots are comparable run to run.
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../app');
const [out = 'shots', scheme = 'light', size = 'phone'] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const file = path.join(root, rel.endsWith('/') ? `${rel}index.html` : rel);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;
// Playwright's own Chromium if installed, else the system Chrome.
const browser = await chromium.launch().catch(() => chromium.launch({ channel: 'chrome' }));
const viewport = size === 'desktop' ? { width: 1280, height: 860 } : { width: 390, height: 844 };
const page = await (await browser.newContext({ viewport, deviceScaleFactor: 2, colorScheme: scheme, serviceWorkers: 'block' })).newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.clock.install({ time: new Date('2026-10-20T09:40:00') });
const shot = async (name, fullPage = false) => {
  await page.evaluate(() => document.getElementById('toast')?.classList.remove('show'));
  await page.mouse.move(0, 0);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(900);
  await page.screenshot({ path: path.join(out, `${scheme}-${size}-${name}.png`), fullPage });
};
await page.goto(`${base}/`);
await page.waitForSelector('.view');
await shot('0-welcome');
await page.click('text=Try a sample');
await page.waitForSelector('.qa1');
// Finish one thing so the day shows what is behind you.
await page.click('.slot:not(.hero-slot) .item.r-A .check');
await page.waitForTimeout(700);
await shot('1-today');
await shot('1-today-full', true);
await page.click('.seg button:has-text("Tomorrow")');
await shot('2-tomorrow');
await page.click('.seg button:has-text("Today")');
for (const [n, route] of [['3', 'ahead'], ['4', 'goals'], ['5', 'more']]) {
  await page.goto(`${base}/#${route}`);
  await page.waitForSelector('.view');
  await shot(`${n}-${route}`);
}
await page.goto(`${base}/#today`);
await page.waitForSelector('.qa1');
await page.click('#fab');
await page.fill('#qa-input', 'Organic chem final dec 10 9am 30% #CHEM210');
await shot('6-add');
await page.keyboard.press('Escape');
await page.click('.notice.sort .btn');
await shot('7-sort');
await page.keyboard.press('Escape');
await page.click('.qa1 .btn.primary');
await page.clock.runFor(9 * 60000);
await shot('8-focus');
console.log(errors.length ? `Console errors:\n${errors.join('\n')}` : 'no console errors');
await browser.close();
server.close();
