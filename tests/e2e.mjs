// End-to-end smoke test in a real browser. Optional: needs Playwright.
//   npm i --no-save playwright && npx playwright install chromium && npm run test:e2e
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { Buffer } from 'node:buffer';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../app');
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.woff2': 'font/woff2', '.webmanifest': 'application/manifest+json' };
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
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
// The app never uses native alert/confirm/prompt (blocked in some embedded views).
page.on('dialog', (d) => { errors.push(`native dialog: ${d.message()}`); d.dismiss(); });
await page.clock.install({ time: new Date('2026-10-20T09:40:00') });
const state = () => page.evaluate(() => JSON.parse(localStorage.getItem('willist.v1') || '{}'));
const find = (s, title) => s.items.find((x) => x.title === title);
const step = (n) => console.log('ok', n);
const sheet = 'dialog.slip[open]';
const readFile = async (dl) => fs.promises.readFile(await dl.path(), 'utf8');

await page.goto(`${base}/`);
await page.waitForSelector('.view');

// 1. quick add: a class, a weighted exam, a plain task
for (const t of ['Calculus lecture mwf 10-10:50am #MATH201', 'Calc midterm oct 30 9am 25% #MATH201', 'Email TA about regrade']) {
  await page.fill('#qa-input', t);
  await page.press('#qa-input', 'Enter');
}
let s = await state();
assert.equal(s.items.length, 3);
const exam = find(s, 'Calc midterm');
assert.equal(exam.weightPct, 25);
assert.ok(exam.sessions.length > 0);
step('quick add');

// 2. the tray suggests A for a 25% exam; inking the pencil marks letters everything suggested
assert.equal(await page.locator('.tray-row').count(), 2);
await page.locator('.tray-row', { hasText: 'Email TA' }).locator('button.bubble').first().click();
s = await state();
assert.equal(find(s, 'Email TA about regrade').priority, 'A');
await page.locator('.tray-row', { hasText: 'Calc midterm' }).locator('button.bubble.ghost').click();
s = await state();
assert.equal(find(s, 'Calc midterm').priority, 'A');
step('fill in letters');

// 3. new item through the editor, with grade weight and size
await page.fill('#qa-input', 'History essay due nov 3');
await page.click('#qa-more');
await page.waitForSelector(sheet);
await page.fill(`${sheet} input[type=number] >> nth=0`, '30');
await page.locator(`${sheet} input[type=number] >> nth=0`).blur();
await page.click(`${sheet} .choice button:has-text("Project")`);
await page.click(`${sheet} .letters-pick button:has-text("Mild")`);
assert.ok(await page.locator(`${sheet} .sess li`).count() > 3);
await page.click(`${sheet} button[type=submit]`);
s = await state();
const essay = find(s, 'History essay');
assert.equal(essay.priority, 'B');
assert.equal(essay.weightPct, 30);
assert.equal(essay.effortMin, 600);
step('editor');

// 4. weekly class days
await page.locator('.tt li', { hasText: 'Calculus lecture' }).click().catch(async () => {
  // Tuesday has no Calculus lecture on the timetable; open it from Radar instead.
  await page.goto(`${base}/#radar`);
  await page.locator('.lday li', { hasText: 'Calculus lecture' }).first().click();
});
await page.waitForSelector(sheet);
await page.click(`${sheet} button[aria-label="Fri"]`);
await page.click(`${sheet} button[type=submit]`);
s = await state();
assert.deepEqual(s.items.find((x) => x.type === 'event').recur.days, [1, 3]);
step('edit repeat days');

// 5. complete A1, then undo
await page.goto(`${base}/#today`);
await page.waitForSelector('.qa1');
const before = (await state()).meta.doneCount || 0;
await page.click('.qa1 button:has-text("Done")');
s = await state();
assert.equal(s.meta.doneCount, before + 1);
assert.ok(s.meta.firstDone['2026-10-20']);
await page.click('.toast-btn:has-text("Undo")');
assert.equal((await state()).meta.doneCount || 0, before);
step('complete + undo');

// 6. reorder: move the first A row above the A1
const a1 = await page.locator('.qa1 h2').textContent();
const aRows = page.locator('.part', { hasText: 'A · Must do' }).locator('.ans');
if (await aRows.count()) {
  await aRows.first().locator('button[aria-label$="up"]').click();
  assert.notEqual(await page.locator('.qa1 h2').textContent(), a1);
  step('reorder');
}

// 7. My day places work around classes
await page.click('button[role=radio]:has-text("My day")');
assert.ok(await page.locator('.timeline li').count() >= 2);
assert.equal((await state()).settings.todayMode, 'day');
await page.click('button[role=radio]:has-text("The list")');
step('my day');

// 8. plan tomorrow
await page.goto(`${base}/#plan`);
await page.fill('#dump', 'Buy printer ink\nChem quiz thu\nCall advisor tomorrow 3pm');
await page.click('text=Add every line');
s = await state();
assert.equal(s.items.length, 7);
await page.click('text=Lock in tomorrow');
assert.equal((await state()).meta.lastPlanned, '2026-10-20');
await page.click('[role=tab]:has-text("Weekly review")');
assert.ok(await page.locator('.stat').count() === 4);
step('plan');

// 9. goals
await page.goto(`${base}/#goals`);
await page.fill('#mdp', 'I finish with a 3.7 GPA');
await page.press('#mdp', 'Enter');
await page.locator('.goals .part').first().locator('button:has-text("Add a goal")').click();
await page.waitForSelector(sheet);
await page.fill(`${sheet} input[type=text] >> nth=0`, 'I earn an A in Calculus');
await page.click(`${sheet} button[type=submit]`);
s = await state();
assert.equal(s.mdp, 'I finish with a 3.7 GPA');
assert.equal(s.goals.length, 1);
await page.click('button:has-text("Add the next step")');
await page.waitForSelector(sheet);
await page.fill(`${sheet} input[type=text] >> nth=0`, 'Go to office hours');
await page.click(`${sheet} button[type=submit]`);
s = await state();
assert.equal(find(s, 'Go to office hours').goalId, s.goals[0].id);
step('goals');

// 10. import a pasted syllabus, then the same text again (no duplicates)
await page.goto(`${base}/#tools`);
const syllabus = 'HIST 150\nWeek 9 Thu: Map quiz (5%)\nNov 13: Midterm exam (25%)\nDec 8: Final presentation (20%)';
for (let round = 0; round < 2; round++) {
  await page.click('.index button:has-text("Bring in your semester")');
  await page.waitForSelector(sheet);
  await page.click(`${sheet} [role=tab]:has-text("Paste text")`);
  await page.fill(`${sheet} textarea`, syllabus);
  await page.fill(`${sheet} input[type=text]`, 'HIST150');
  await page.fill(`${sheet} input[type=date]`, '2026-08-31');
  await page.click(`${sheet} button:has-text("Read it")`);
  await page.waitForSelector(`${sheet} .pick li`);
  if (round === 0) {
    await page.click(`${sheet} button:has-text("Add 3 items")`);
  } else {
    assert.equal(await page.locator(`${sheet} .pick li.off`).count(), 3, 'second paste: everything is already there');
    await page.keyboard.press('Escape');
  }
  await page.goto(`${base}/#tools`);
}
s = await state();
assert.equal(s.items.filter((x) => x.course === 'HIST150').length, 3);
assert.equal(find(s, 'Map quiz').date, '2026-10-29');
step('import syllabus');

// 11. import a calendar file
const ics = ['BEGIN:VCALENDAR', 'BEGIN:VEVENT', 'UID:event-assignment-1', 'SUMMARY:Lab report 4 [CHEM 110]',
  'DTSTART:20261106T235900', 'DTEND:20261106T235900', 'END:VEVENT', 'END:VCALENDAR'].join('\r\n');
await page.click('.index button:has-text("Bring in your semester")');
await page.waitForSelector(sheet);
await page.setInputFiles(`${sheet} input[type=file]`, { name: 'canvas.ics', mimeType: 'text/calendar', buffer: Buffer.from(ics) });
await page.waitForSelector(`${sheet} .pick li`);
await page.click(`${sheet} button:has-text("Add 1 item")`);
s = await state();
assert.equal(find(s, 'Lab report 4').course, 'CHEM110');
step('import calendar file');

// 12. tools
await page.goto(`${base}/#tools`);
await page.click('.index button:has-text("Worry Buster")');
await page.fill(`${sheet} textarea >> nth=0`, 'Failing the midterm');
await page.fill(`${sheet} textarea >> nth=3`, 'Do 20 practice problems\nForm a study group');
await page.click(`${sheet} button:has-text("Save and add")`);
s = await state();
assert.equal(s.worries.length, 1);
assert.ok(find(s, 'Form a study group'));
await page.click('.index button:has-text("20 Ideas")');
await page.fill(`${sheet} input[type=text] >> nth=0`, 'What can I do to raise my GPA?');
await page.fill(`${sheet} .rows li:nth-child(3) input`, 'Start problem sets the day they are assigned');
await page.click(`${sheet} .rows li:nth-child(3) .pickme`);
await page.click(`${sheet} button:has-text("Act on")`);
assert.equal(find(await state(), 'Start problem sets the day they are assigned').priority, 'A');
step('tools');

// 13. coach: setup refuses a bad key, accepts a plausible one, and can forget it
await page.click('.index button:has-text("Coach")');
await page.fill('#coach-key', 'not-a-key');
await page.click(`${sheet} button:has-text("Turn on the coach")`);
assert.equal(await page.evaluate(() => localStorage.getItem('willist.ai-key')), null);
await page.fill('#coach-key', 'sk-ant-test-key');
await page.click(`${sheet} button:has-text("Turn on the coach")`);
await page.waitForSelector('#coach-q');
await page.click(`${sheet} button:has-text("Remove key")`);
assert.equal(await page.evaluate(() => localStorage.getItem('willist.ai-key')), null);
await page.keyboard.press('Escape');
const backupHasKey = JSON.stringify(await state()).includes('sk-ant');
assert.ok(!backupHasKey, 'the API key never enters the planner data');
step('coach setup');

// 14. settings re-plan
await page.click('.index button:has-text("Settings")');
await page.fill(`${sheet} input[type=number] >> nth=0`, '3');
await page.click(`${sheet} button[type=submit]`);
assert.equal((await state()).settings.perDayMin, 180);
step('settings');

// 15. downloads, erase + undo
await page.click('.index button:has-text("Add to calendar")');
const [icsDl] = await Promise.all([page.waitForEvent('download'), page.click(`${sheet} button:has-text("Download .ics")`)]);
assert.match(await readFile(icsDl), /RRULE:FREQ=WEEKLY;BYDAY=MO,WE/);
await page.keyboard.press('Escape');
await page.click('.index button:has-text("Backup")');
const [bk] = await Promise.all([page.waitForEvent('download'), page.click(`${sheet} button:has-text("Download backup")`)]);
const backup = JSON.parse(await readFile(bk));
assert.equal(backup.items.length, (await state()).items.length);
await page.click(`${sheet} button:has-text("Erase everything")`);
await page.click('dialog.confirm[open] button:has-text("Yes, erase")');
await page.waitForFunction(() => JSON.parse(localStorage.getItem('willist.v1')).items.length === 0);
await page.click('.toast-btn:has-text("Undo")');
assert.equal((await state()).items.length, backup.items.length);
step('downloads + erase/undo');

// 16. radar balance, focus logging
await page.goto(`${base}/#radar`);
if (await page.locator('.btn.primary:has-text("Balance my plan")').count()) await page.click('.btn.primary:has-text("Balance my plan")');
await page.goto(`${base}/#today`);
await page.waitForSelector('.qa1');
// starting a B while A's remain asks first, in the page
await page.fill('#qa-input', 'Tidy desk !b');
await page.press('#qa-input', 'Enter');
await page.locator('.ans.dim:has-text("Tidy desk") .go').click();
await page.click('dialog.confirm[open] button:has-text("Back to my A")');
assert.equal(await page.locator('dialog.focus').count(), 0);
await page.click('.qa1 button:has-text("Start now")');
await page.waitForSelector('dialog.focus[open]');
await page.clock.runFor(12 * 60000);
await page.click('dialog.focus button:has-text("Stop")');
await page.waitForSelector('dialog.focus', { state: 'detached' });
s = await state();
assert.ok(s.log.length >= 1 && s.log.at(-1).minutes >= 11);
step('radar + focus log');

// 17. delete + undo, reload, offline shell
const n = (await state()).items.length;
await page.locator('.ans-main').first().click();
await page.click(`${sheet} button:has-text("Delete")`);
assert.equal((await state()).items.length, n - 1);
await page.click('.toast-btn:has-text("Undo")');
assert.equal((await state()).items.length, n);
await page.reload();
await page.waitForSelector('.view');
assert.ok(await page.evaluate(() => navigator.serviceWorker.getRegistration().then((r) => !!r)));
step('delete + undo, reload, service worker');

await browser.close();
server.close();
if (errors.length) { console.error(`Console errors:\n${errors.join('\n')}`); process.exit(1); }
console.log('e2e passed');
