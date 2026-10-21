// Screenshots of the iPhone app in the iOS Simulator, with a full sample planner loaded.
//   npm run ios:shots                          the four tabs, into shots/ios
//   npm run ios:shots -- goals -open tomorrow  one tab, with debug launch arguments
//   DEVICE="iPhone 17 Pro" npm run ios:shots   another simulator (default "iPhone 17")
//
// Debug builds read these launch arguments, so any screen can be shot without tapping:
//   -tab today|goals|study|more      which tab opens
//   -open tomorrow|goals             Goals: push Plan tomorrow or Your goals
//   -scroll letters|bottom           Goals: scroll to Needs a letter or the bottom rows
//   -sheet add|import|search         open that sheet (add and import from Goals, search from Today)
//   -draft "Calc midterm fri 2pm"    text already typed in the Add sheet (no keyboard)
//   -edit t5                         Today: open that to-do's details (sample ids t1 to t6)
//   -show "Email TA"                 open the to-do or item whose title starts with this
//   -todoSort due                    Today's sort: manual, importance, due, alphabetical, created
//
// If a notification permission prompt keeps covering the app, an earlier run asked and was never
// answered; `xcrun simctl erase <device>` clears it.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { sampleData } from '../app/src/sample.js';
import { emptyState, normalize } from '../app/src/store.js';
import { todayISO, addDays } from '../app/src/dates.js';

const BUNDLE = 'com.lull.willist';
const OUT = 'shots/ios';
process.chdir(path.join(path.dirname(new URL(import.meta.url).pathname), '..'));

const argv = process.argv.slice(2);
const tabs = argv[0] && !argv[0].startsWith('-') ? [argv.shift()] : ['today', 'goals', 'study', 'more'];
const run = (cmd, args, quiet = false) => execFileSync(cmd, args, { encoding: 'utf8', stdio: quiet ? 'ignore' : 'pipe' });
const tryRun = (cmd, args) => { try { run(cmd, args, true); } catch { /* already in that state */ } };

// The simulator.
const want = process.env.DEVICE || 'iPhone 17';
const all = Object.entries(JSON.parse(run('xcrun', ['simctl', 'list', 'devices', 'available', '-j'])).devices)
  .filter(([runtime]) => runtime.includes('iOS')).flatMap(([, list]) => list);
const device = all.find((d) => d.name === want);
if (!device) {
  console.error(`No simulator named "${want}". Set DEVICE to one of: ${[...new Set(all.map((d) => d.name))].join(', ')}`);
  process.exit(1);
}
tryRun('xcrun', ['simctl', 'boot', device.udid]);
run('xcrun', ['simctl', 'bootstatus', device.udid, '-b'], true);

// Build and install the debug app.
execFileSync('xcodebuild', ['-project', 'ios/WilList.xcodeproj', '-scheme', 'WilList', '-configuration', 'Debug',
  '-destination', `id=${device.udid}`, '-derivedDataPath', 'build/sim', '-quiet', 'build'], { stdio: 'inherit' });
run('xcrun', ['simctl', 'install', device.udid, 'build/sim/Build/Products/Debug-iphonesimulator/WilList.app']);
run('xcrun', ['simctl', 'ui', device.udid, 'appearance', 'light']);
run('xcrun', ['simctl', 'status_bar', device.udid, 'override', '--time', '9:41', '--batteryLevel', '100', '--cellularBars', '4', '--wifiBars', '3']);

// The sample planner: the website's sample, plus to-dos and items that use every task detail.
function sample() {
  const s = emptyState();
  const today = todayISO();
  const d = (n) => addDays(today, n);
  Object.assign(s, sampleData(today, s.settings));
  s.meta.onboarded = true;
  s.meta.firstDone = { [d(-1)]: 'A', [d(-2)]: 'A', [d(-3)]: 'A', [d(-4)]: 'B', [d(-5)]: 'A', [d(-7)]: 'A' };
  s.todos = [
    { id: 't1', title: 'Pick up laundry', done: false, doneAt: null, createdAt: d(-1) },
    { id: 't2', title: 'Return the lab goggles to Sam', done: false, doneAt: null, date: d(1), time: '10:00', remindAt: `${d(1)}T09:00`, starred: true, createdAt: d(-2) },
    { id: 't3', title: 'Top up transit card', done: false, doneAt: null, date: d(-1), createdAt: d(-3) },
    { id: 't5', title: 'Pack for the field trip', done: false, doneAt: null, date: d(2), createdAt: today, notes: 'Bus leaves from the north gate.',
      steps: [{ id: 's1', title: 'Rain jacket', done: true }, { id: 's2', title: 'Notebook', done: false }, { id: 's3', title: 'Water bottle', done: false }] },
    { id: 't6', title: 'Water the plants', done: false, doneAt: null, date: today, recur: { freq: 'weekly', days: [] }, createdAt: d(-7) },
    { id: 't4', title: 'Reply to Mia about Saturday', done: true, doneAt: today, createdAt: d(-1) },
  ];
  const ta = s.items.find((i) => i.title.startsWith('Email TA'));
  if (ta) {
    Object.assign(ta, { myDay: today, remindAt: `${today}T16:00`,
      steps: [{ id: 'x1', title: 'Find the quiz', done: true }, { id: 'x2', title: 'Write two lines', done: false }] });
  }
  return JSON.stringify(normalize(s));
}

const container = run('xcrun', ['simctl', 'get_app_container', device.udid, BUNDLE, 'data']).trim();
const support = path.join(container, 'Library', 'Application Support');
fs.mkdirSync(support, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });
const data = sample();
const suffix = argv.length ? `-${argv.join(' ').replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '')}` : '';

for (const tab of tabs) {
  fs.writeFileSync(path.join(support, 'willist.v1.json'), data);
  tryRun('xcrun', ['simctl', 'terminate', device.udid, BUNDLE]);
  run('xcrun', ['simctl', 'launch', device.udid, BUNDLE, '-tab', tab, ...argv]);
  run('sleep', ['5']); // the first launch after an install is slow
  const file = path.join(OUT, `${tab}${suffix}.png`);
  run('xcrun', ['simctl', 'io', device.udid, 'screenshot', file], true);
  console.log(file);
}
