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
run('xcodebuild', ['-project', 'ios/WilList.xcodeproj', '-scheme', 'WilList', '-configuration', 'Release',
  '-destination', 'generic/platform=iOS', '-derivedDataPath', 'build/ios', '-allowProvisioningUpdates', '-quiet', 'build']);

const list = path.join(os.tmpdir(), `willist-devices-${process.pid}.json`);
execFileSync('xcrun', ['devicectl', 'list', 'devices', '--json-output', list], { stdio: 'ignore' });
const devices = JSON.parse(fs.readFileSync(list, 'utf8')).result.devices.filter((d) =>
  d.hardwareProperties?.platform === 'iOS' && d.connectionProperties?.pairingState === 'paired' &&
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
    run('xcrun', ['devicectl', 'device', 'process', 'launch', '--terminate-existing', '--device', d.identifier, BUNDLE], 60000);
    installed++;
  } catch {
    console.log(`Could not reach ${name}. Unlock it, keep it on this Mac's Wi-Fi, and run this again.`);
  }
}
console.log(`Installed on ${installed} of ${devices.length} device(s).`);
if (!installed) process.exit(1);
