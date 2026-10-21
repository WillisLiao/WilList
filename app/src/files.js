// Any file someone has into something Claude can read: PDFs and photos go as they are,
// Word, PowerPoint and Excel files are unzipped to their text, everything else is read as text.

const MAX_BYTES = 20 * 1024 * 1024; // the API takes 32 MB per request; base64 adds a third
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
const ext = (name) => (name.match(/\.([a-z0-9]+)$/i)?.[1] || '').toLowerCase();

export class FileError extends Error {}

export function isCalendarFile(file) {
  return ext(file.name) === 'ics' || file.type === 'text/calendar';
}

// ------------------------------------------------------------ zip (Office files)

async function inflate(bytes) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

// The entries of a zip whose names pass `wanted`, as [name, text], in archive order.
export async function unzipText(buffer, wanted) {
  const v = new DataView(buffer);
  let end = buffer.byteLength - 22;
  while (end >= 0 && v.getUint32(end, true) !== 0x06054b50) end--;
  if (end < 0) throw new FileError('That file looks damaged.');
  const count = v.getUint16(end + 10, true);
  let p = v.getUint32(end + 16, true);
  const utf8 = new TextDecoder();
  const out = [];
  for (let i = 0; i < count; i++) {
    const method = v.getUint16(p + 10, true);
    const size = v.getUint32(p + 20, true);
    const nameLen = v.getUint16(p + 28, true);
    const skip = nameLen + v.getUint16(p + 30, true) + v.getUint16(p + 32, true);
    const local = v.getUint32(p + 42, true);
    const name = utf8.decode(new Uint8Array(buffer, p + 46, nameLen));
    p += 46 + skip;
    if (!wanted(name)) continue;
    const start = local + 30 + v.getUint16(local + 26, true) + v.getUint16(local + 28, true);
    const raw = new Uint8Array(buffer, start, size);
    out.push([name, utf8.decode(method === 8 ? await inflate(raw) : raw)]);
  }
  return out;
}

const ENTITY = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };
export function xmlText(xml, breaks) {
  return xml.replace(breaks, '\n').replace(/<w:tab\/>/g, '\t').replace(/<[^>]+>/g, '')
    .replace(/&(#x?[0-9a-f]+|\w+);/gi, (m, e) => e[0] === '#'
      ? String.fromCodePoint(parseInt(e.slice(e[1] === 'x' ? 2 : 1), e[1] === 'x' ? 16 : 10))
      : ENTITY[e] ?? m)
    .replace(/\n{3,}/g, '\n\n').trim();
}

const byNumber = (a, b) => Number(a[0].match(/(\d+)\.xml$/)?.[1] || 0) - Number(b[0].match(/(\d+)\.xml$/)?.[1] || 0);

export async function officeText(buffer, kind) {
  if (kind === 'docx') {
    const parts = await unzipText(buffer, (n) => /^word\/(document|footnotes|endnotes)\.xml$/.test(n));
    return parts.map(([, x]) => xmlText(x, /<\/w:p>/g)).join('\n\n');
  }
  if (kind === 'pptx') {
    const slides = (await unzipText(buffer, (n) => /^ppt\/slides\/slide\d+\.xml$/.test(n))).sort(byNumber);
    return slides.map(([, x], i) => `Slide ${i + 1}\n${xmlText(x, /<\/a:p>/g)}`).join('\n\n');
  }
  // xlsx: each row as tab-separated cells; shared strings looked up by index.
  const parts = await unzipText(buffer, (n) => n === 'xl/sharedStrings.xml' || /^xl\/worksheets\/sheet\d+\.xml$/.test(n));
  const shared = [...(parts.find(([n]) => n === 'xl/sharedStrings.xml')?.[1] || '').matchAll(/<si>([\s\S]*?)<\/si>/g)].map((m) => xmlText(m[1], /(?!)/g));
  const sheets = parts.filter(([n]) => n !== 'xl/sharedStrings.xml').sort(byNumber).map(([, x]) =>
    [...x.matchAll(/<row[^>]*>([\s\S]*?)<\/row>/g)].map((row) =>
      [...row[1].matchAll(/<c([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)].map(([, attrs, body = '']) => {
        const val = body.match(/<v>([\s\S]*?)<\/v>/)?.[1] ?? body.match(/<t[^>]*>([\s\S]*?)<\/t>/)?.[1] ?? '';
        return /t="s"/.test(attrs) ? shared[Number(val)] ?? '' : xmlText(val, /(?!)/g);
      }).join('\t')).join('\n'));
  return `Spreadsheet. Numbers between 30000 and 60000 in date columns are Excel dates (days since 1899-12-30).\n\n${sheets.join('\n\n')}`;
}

// ------------------------------------------------------------ to content blocks

function base64(buffer) {
  const bytes = new Uint8Array(buffer);
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

// Photos are re-encoded as JPEG no larger than 2000 px: iPhone HEIC photos aren't accepted
// as they are, and a smaller picture reads just as well for less.
async function photoBlock(file) {
  let bitmap;
  try { bitmap = await createImageBitmap(file); } catch { throw new FileError('Could not open that picture. Save it as JPEG or PDF and try again.'); }
  const scale = Math.min(1, 2000 / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  const data = canvas.toDataURL('image/jpeg', 0.9).split(',')[1];
  return { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data } };
}

export async function fileBlocks(file) {
  if (file.size > MAX_BYTES) throw new FileError('That file is over 20 MB. Split it or export just the schedule pages.');
  const kind = ext(file.name);
  if (file.type === 'application/pdf' || kind === 'pdf') {
    return [{ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: base64(await file.arrayBuffer()) }, title: file.name }];
  }
  if (file.type.startsWith('image/') || ['heic', 'heif', 'jpg', 'jpeg', 'png', 'gif', 'webp'].includes(kind)) {
    if (IMAGE_TYPES.includes(file.type) && file.size < 3.5 * 1024 * 1024) {
      return [{ type: 'image', source: { type: 'base64', media_type: file.type, data: base64(await file.arrayBuffer()) } }];
    }
    return [await photoBlock(file)];
  }
  if (['docx', 'pptx', 'xlsx'].includes(kind)) {
    const text = await officeText(await file.arrayBuffer(), kind);
    if (!text.trim()) throw new FileError('That file has no text in it.');
    return [{ type: 'text', text: `${file.name}\n\n${text}` }];
  }
  if (['doc', 'ppt', 'xls', 'pages', 'numbers', 'key'].includes(kind)) {
    throw new FileError(`WilList can't read .${kind} files. Save it as PDF and try again.`);
  }
  const text = await file.text();
  if (text.slice(0, 4000).includes('\u0000')) throw new FileError(`WilList can't read .${kind || 'this kind of'} files. Save it as PDF and try again.`);
  return [{ type: 'text', text: `${file.name}\n\n${text}` }];
}
