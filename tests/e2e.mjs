// End-to-end smoke test in a real browser. Optional: needs Playwright.
//   npm i --no-save playwright && npx playwright install chromium && npm run test:e2e
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../app');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.webmanifest': 'application/manifest+json' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const file = path.join(root, rel.endsWith('/') ? `${rel}index.html` : rel);
  if (!file.startsWith(root) || !fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://localhost:${server.address().port}`;

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 390, height: 844 }, acceptDownloads: true });
const page = await context.newPage();
const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('dialog', (d) => d.accept());
await page.clock.install({ time: new Date('2026-10-19T09:40:00') });
await page.goto(`${base}/`);
const state = () => page.evaluate(() => JSON.parse(localStorage.getItem('willist.v1') || '{}'));
const step = (n) => console.log('ok', n);

// 1. quick add a recurring class and an exam
for (const t of ['Calculus lecture mwf 10-10:50am #MATH201', 'Calc midterm oct 30 9am #MATH201 !a', 'Email TA about regrade']) {
  await page.fill('#qa-input', t); await page.press('#qa-input', 'Enter');
}
let s = await state();
assert.equal(s.items.length, 3);
const exam = s.items.find((x) => x.type === 'exam');
assert.equal(exam.priority, 'A'); assert.ok(exam.sessions.length > 0);
assert.ok(await page.locator('text=Calculus lecture').count());
step('quick add');

// 2. letter the email via tray -> appears as A
await page.locator('.tray-list li', { hasText: 'Email TA' }).locator('button.letter.l-A').click();
s = await state(); assert.equal(s.items.find((x) => x.title.startsWith('Email')).priority, 'A');
step('tray letter');

// 3. new item via details editor
await page.fill('#qa-input', 'History essay due nov 3');
await page.click('#qa-more');
await page.waitForSelector('dialog.sheet[open]');
assert.equal(await page.inputValue('dialog.sheet[open] input[type=text] >> nth=0'), 'History essay');
await page.click('dialog.sheet[open] .letter.l-B');
await page.click('dialog.sheet[open] .chip-btn:has-text("Project")');
assert.ok(await page.locator('dialog.sheet[open] .sess-list li').count() > 3);
await page.click('dialog.sheet[open] button[type=submit]');
s = await state(); const essay = s.items.find((x) => x.title === 'History essay');
assert.equal(essay.priority, 'B'); assert.equal(essay.effortMin, 600); assert.ok(essay.sessions.length >= 10);
step('editor create');

// 4. edit recurring class days
await page.click('.sched-title:has-text("Calculus lecture")');
await page.waitForSelector('dialog.sheet[open]');
await page.click('dialog.sheet[open] .days-pick button:has-text("Fr")');
await page.click('dialog.sheet[open] button[type=submit]');
s = await state(); assert.deepEqual(s.items.find((x) => x.type === 'event').recur.days, [1, 3]);
step('edit recurrence');

// 5. complete A1 then undo
const before = (await state()).meta.doneCount || 0;
await page.click('.hero .btn:has-text("Done")');
s = await state(); assert.equal(s.meta.doneCount, before + 1);
await page.click('.toast-btn:has-text("Undo")');
s = await state(); assert.equal(s.meta.doneCount || 0, before);
step('complete + undo');

// 6. reorder: move first A row down
const firstA = await page.locator('.hero-title').textContent();
const aRows = page.locator('.group:has(h3:has-text("A · Must do")) .row');
if (await aRows.count()) {
  await aRows.first().locator('button[aria-label^="Move"][aria-label$="up"]').click();
  const newA1 = await page.locator('.hero-title').textContent();
  assert.notEqual(newA1, firstA);
  step('reorder');
}

// 7. plan tomorrow: add all + lock
await page.goto(`${base}/#plan`);
await page.fill('#dump', 'Buy printer ink\nChem quiz thu\nCall advisor tomorrow 3pm');
await page.click('text=Add all');
s = await state(); assert.equal(s.items.length, 7);
await page.click('text=Lock in tomorrow');
s = await state(); assert.equal(s.meta.lastPlanned, '2026-10-19');
await page.click('text=Weekly review');
step('plan');

// 8. goals: mdp + goal
await page.goto(`${base}/#goals`);
await page.fill('.mdp-card input', 'I finish with a 3.7 GPA'); await page.press('.mdp-card input', 'Enter');
await page.locator('.goals .group').first().locator('button:has-text("Add a goal")').click();
await page.waitForSelector('dialog.sheet[open]');
await page.fill('dialog.sheet[open] input[type=text] >> nth=0', 'I earn an A in Calculus');
await page.click('dialog.sheet[open] button[type=submit]');
s = await state(); assert.equal(s.mdp, 'I finish with a 3.7 GPA'); assert.equal(s.goals.length, 1);
await page.click('button:has-text("Add the next step")');
await page.waitForSelector('dialog.sheet[open]');
await page.fill('dialog.sheet[open] input[type=text] >> nth=0', 'Go to office hours');
await page.click('dialog.sheet[open] button[type=submit]');
s = await state(); assert.equal(s.items.find((x) => x.title === 'Go to office hours').goalId, s.goals[0].id);
step('goals');

// 9. tools: worry buster -> tasks, mind storm -> A task
await page.goto(`${base}/#tools`);
await page.click('.tool:has-text("Worry Buster")');
await page.fill('dialog[open] textarea >> nth=0', 'Failing the midterm');
await page.fill('dialog[open] textarea >> nth=3', 'Do 20 practice problems\nForm a study group');
await page.click('dialog[open] button:has-text("Save")');
s = await state(); assert.equal(s.worries.length, 1); assert.ok(s.items.some((x) => x.title === 'Form a study group'));
await page.click('.tool:has-text("20 Ideas")');
await page.fill('dialog[open] input[type=text] >> nth=0', 'What can I do to raise my GPA?');
await page.fill('dialog[open] .ideas li:nth-child(3) input[type=text]', 'Start problem sets the day they are assigned');
await page.check('dialog[open] .ideas li:nth-child(3) input[type=radio]');
await page.click('dialog[open] button:has-text("Act on")');
s = await state(); assert.equal(s.items.find((x) => x.title.startsWith('Start problem sets')).priority, 'A');
step('tools');

// 10. settings change replans
await page.click('.tool:has-text("Settings")');
await page.fill('dialog[open] input[type=number] >> nth=0', '3');
await page.click('dialog[open] button[type=submit]');
s = await state(); assert.equal(s.settings.perDayMin, 180);
step('settings');

// 11. downloads
await page.click('.tool:has-text("Add to calendar")');
const [ics] = await Promise.all([page.waitForEvent('download'), page.click('dialog[open] button:has-text("Download")')]);
const icsText = await (await import('node:fs')).promises.readFile(await ics.path(), 'utf8');
assert.match(icsText, /BEGIN:VCALENDAR/); assert.match(icsText, /RRULE:FREQ=WEEKLY;BYDAY=MO,WE/);
await page.keyboard.press('Escape');
await page.click('.tool:has-text("Backup")');
const [bk] = await Promise.all([page.waitForEvent('download'), page.click('dialog[open] button:has-text("Download backup")')]);
const backup = JSON.parse(await (await import('node:fs')).promises.readFile(await bk.path(), 'utf8'));
assert.equal(backup.items.length, (await state()).items.length);
// restore round trip
await page.click('dialog[open] button:has-text("Erase everything")');
s = await state(); assert.equal(s.items.length, 0);
await page.click('.toast-btn:has-text("Undo")');
s = await state(); assert.equal(s.items.length, backup.items.length);
step('downloads + erase/undo');

// 12. radar balance
await page.goto(`${base}/#radar`);
if (await page.locator('text=Balance my plan').count()) { await page.click('text=Balance my plan'); step('balance'); }

// 13. delete via editor + undo
await page.goto(`${base}/#today`);
const n = (await state()).items.length;
await page.locator('.row-main').first().click();
await page.click('dialog.sheet[open] button:has-text("Delete")');
s = await state(); assert.equal(s.items.length, n - 1);
await page.click('.toast-btn:has-text("Undo")');
s = await state(); assert.equal(s.items.length, n);
step('delete + undo');

// 14. reload persists, offline SW registered
await page.reload(); await page.waitForSelector('.view');
assert.ok(await page.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => !!r)));
step('reload + service worker');
await browser.close();
server.close();
if (errors.length) { console.error('Console errors:\n' + errors.join('\n')); process.exit(1); }
console.log('e2e passed');
