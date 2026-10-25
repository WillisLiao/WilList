// Build the iOS app and install it on your paired iPhone and iPad over Wi-Fi (or a cable).
//   npm run ios             every paired device within reach
//   npm run ios -- ipad     only devices whose name or model contains "ipad"
// Each device must be unlocked and on the same network as this Mac.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const BUNDLE = 'com.lull.willist';
const APP = 'build/ios/Build/Products/Release-iphoneos/WilList.app';
const only = (process.argv[2] || '').toLowerCase();
const run = (cmd, args, timeout) => execFileSync(cmd, args, { stdio: 'inherit', timeout });

process.chdir(path.join(path.dirname(new URL(import.meta.url).pathname), '..'));
// The owner's own AI key (AGENT_KEY=sk-... in the untracked .env.local) goes into the build installed
// on their own devices, so the Agent works there before its server exists. Never committed or shipped.
const key = fs.existsSync('.env.local') ? /^AGENT_KEY=(\S+)/m.exec(fs.readFileSync('.env.local', 'utf8'))?.[1] : undefined;
run('xcodebuild', ['-project', 'ios/WilList.xcodeproj', '-scheme', 'WilList', '-configuration', 'Release',
  '-destination', 'generic/platform=iOS', '-derivedDataPath', 'build/ios', '-allowProvisioningUpdates', '-quiet', 'build',
  ...(key ? [`WL_AGENT_KEY=${key}`] : [])]);

const list = path.join(os.tmpdir(), `willist-devices-${process.pid}.json`);
execFileSync('xcrun', ['devicectl', 'list', 'devices', '--json-output', list], { stdio: 'ignore' });
const devices = JSON.parse(fs.readFileSync(list, 'utf8')).result.devices.filter((d) =>
  d.hardwareProperties?.platform === 'iOS' && d.hardwareProperties?.reality === 'physical' &&
  d.connectionProperties?.pairingState === 'paired' &&
  `${d.deviceProperties?.name} ${d.hardwareProperties?.deviceType}`.toLowerCase().includes(only));
fs.rmSync(list, { force: true });

let installed = 0;
for (const d of devices) {
  const name = d.deviceProperties?.name || d.identifier;
  try {
    // Wi-Fi connections often drop on the first handshake; a second or third try usually works.
    for (let attempt = 1; ; attempt++) {
      try { run('xcrun', ['devicectl', 'device', 'install', 'app', '--device', d.identifier, APP], 180000); break; } catch (e) { if (attempt === 3) throw e; }
    }
  } catch {
    console.log(`Could not reach ${name}. Unlock it, keep it on this Mac's Wi-Fi, and run this again.`);
    continue;
  }
  installed++;
  try {
    run('xcrun', ['devicectl', 'device', 'process', 'launch', '--terminate-existing', '--device', d.identifier, BUNDLE], 60000);
  } catch {
    console.log(`Installed on ${name}. It was locked, so open WilList yourself.`);
  }
}
console.log(`Installed on ${installed} of ${devices.length} device(s).`);
if (!installed) process.exit(1);
