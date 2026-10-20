// Builds the claude.ai artifact preview of the app (the owner's private link).
//   node scripts/build-artifact.mjs <out dir>
// Writes <out>/willist.html (the page body, no <html>/<head>: the artifact wraps it) and
// <out>/files.json, the `files` map for the Artifact tool: published path → absolute source.
// Paths removed from app/ since the last publish must be sent as null to delete them.
import fs from 'node:fs';
import path from 'node:path';

const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const app = path.join(repo, 'app');
const out = path.resolve(process.argv[2] || 'artifact');
const html = fs.readFileSync(path.join(app, 'index.html'), 'utf8');
// styles.css follows the viewer's theme switch itself (:root[data-theme]) as well as the OS setting.
const body = html.match(/<body>([\s\S]*)<\/body>/)[1].trim();
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'willist.html'), `<title>WilList</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preload" href="fonts/instrument-sans.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="styles.css">
${body}
`);

const files = { 'styles.css': path.join(app, 'styles.css') };
const walk = (dir) => fs.readdirSync(path.join(app, dir), { withFileTypes: true }).forEach((e) => {
  const rel = `${dir}/${e.name}`;
  if (e.isDirectory()) walk(rel); else files[rel] = path.join(app, rel);
});
['src', 'fonts', 'vendor'].forEach(walk);
fs.writeFileSync(path.join(out, 'files.json'), JSON.stringify(files, null, 2));
console.log(`${out}/willist.html + files.json (${Object.keys(files).length} files)`);
