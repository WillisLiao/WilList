// Screenshots of the iPhone app in the iOS Simulator, with the app's sample week loaded.
//   npm run ios:shots                          the four tabs, into shots/ios
//   npm run ios:shots -- today -open settings     one tab, with debug launch arguments
//   DEVICE="iPhone 17 Pro" npm run ios:shots   another simulator (default "iPhone 17")
//   EMPTY=1 npm run ios:shots                  an empty plan, welcome already seen (files get -empty)
//   FIRST=1 npm run ios:shots today            the very first launch: the welcome (files get -first)
//
// Debug builds read these launch arguments, so any screen can be shot without tapping:
//   -tab today|plan|progress|goals|agent   which tab opens
//   -open settings                   Settings, from the profile picture
//   -evening 1|2|3                   Plan tomorrow at that step (2 with a line written)
//   -scroll later|calendar           Plan: scroll to Later or the calendar
//   -scroll next                     Progress: scroll to Next 7 days
//   -sheet add|study|search|letters  open that sheet (New task and New study block from Plan, search and letters from Today)
//   -draft "Lab report fri 2pm"      text already typed in the Add sheet (no keyboard)
//   -edit t5                         Today: open that to-do's details (sample ids t1 to t6)
//   -show "Email TA"                 open the to-do or item whose title starts with this
//   -todoSort due                    Today's sort: manual, importance, due, alphabetical, created
//   -welcome 2                       the first-run welcome at step 2 or 3, with sample lines (use FIRST=1)
//   -gallery YES|lock|focus|ticked   every widget at its real size, the focus Live Activity, or a tick on each
//   -focus YES                       start a focus session on the A1 (NO, the default here, ends one left running)
//   -focusSpent 30                   with -focus YES: 30 minutes of it already spent
//   -agentDemo YES                   the Agent answers from a script, with no subscription (on by default here)
//   -agentConsent YES|NO             the Agent's ask before sending anything to the AI model, answered or not (YES here)
//   -agentAsk "Here's my syllabus"   the Agent is sent these words on launch
//
// If a notification permission prompt keeps covering the app, an earlier run asked and was never
// answered; `xcrun simctl erase <device>` clears it.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const BUNDLE = 'com.lull.willist';
const OUT = 'shots/ios';
process.chdir(path.join(path.dirname(new URL(import.meta.url).pathname), '..'));

const argv = process.argv.slice(2);
const tabs = argv[0] && !argv[0].startsWith('-') ? [argv.shift()] : ['today', 'plan', 'progress', 'goals', 'agent'];
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

// The plan: the app's own sample week (`-plan sample` in TestPlan.swift), an empty one, or none.
const { EMPTY, FIRST } = process.env;
const plan = FIRST ? 'new' : EMPTY ? 'empty' : 'sample';
fs.mkdirSync(OUT, { recursive: true });
const suffix = (argv.length ? `-${argv.join(' ').replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '')}` : '')
  + (EMPTY ? '-empty' : '') + (FIRST ? '-first' : '');
// A focus session left running by an earlier shot would cover the screen.
if (!argv.includes('-focus')) argv.push('-focus', 'NO');
// The Agent answers from its script: there is no server or key here.
if (!argv.includes('-agentDemo')) argv.push('-agentDemo', 'YES');
if (!argv.includes('-agentConsent')) argv.push('-agentConsent', 'YES');

for (const tab of tabs) {
  tryRun('xcrun', ['simctl', 'terminate', device.udid, BUNDLE]);
  run('xcrun', ['simctl', 'launch', device.udid, BUNDLE, '-plan', plan, '-tab', tab, ...argv]);
  run('sleep', ['5']); // the first launch after an install is slow
  const file = path.join(OUT, `${tab}${suffix}.png`);
  run('xcrun', ['simctl', 'io', device.udid, 'screenshot', file], true);
  console.log(file);
}
