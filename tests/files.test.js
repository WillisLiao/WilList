import { test } from 'node:test';
import assert from 'node:assert/strict';
import { officeText, xmlText } from '../app/src/files.js';

const enc = new TextEncoder();
const deflate = async (bytes) => new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('deflate-raw'))).arrayBuffer());

// A minimal zip writer, enough to build .docx and .xlsx fixtures: [name, text, deflate?].
async function zip(files) {
  const parts = [];
  const central = [];
  let offset = 0;
  for (const [name, text, compress] of files) {
    const nameBytes = enc.encode(name);
    const raw = enc.encode(text);
    const data = compress ? await deflate(raw) : raw;
    const local = new DataView(new ArrayBuffer(30));
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(8, compress ? 8 : 0, true);
    local.setUint32(18, data.length, true);
    local.setUint32(22, raw.length, true);
    local.setUint16(26, nameBytes.length, true);
    parts.push(new Uint8Array(local.buffer), nameBytes, data);
    const entry = new DataView(new ArrayBuffer(46));
    entry.setUint32(0, 0x02014b50, true);
    entry.setUint16(10, compress ? 8 : 0, true);
    entry.setUint32(20, data.length, true);
    entry.setUint32(24, raw.length, true);
    entry.setUint16(28, nameBytes.length, true);
    entry.setUint32(42, offset, true);
    central.push(new Uint8Array(entry.buffer), nameBytes);
    offset += 30 + nameBytes.length + data.length;
  }
  const size = central.reduce((a, b) => a + b.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, files.length, true);
  end.setUint16(10, files.length, true);
  end.setUint32(12, size, true);
  end.setUint32(16, offset, true);
  return new Blob([...parts, ...central, new Uint8Array(end.buffer)]).arrayBuffer();
}

test('Word documents come out as paragraphs of plain text', async () => {
  const doc = '<w:document><w:body><w:p><w:r><w:t>Midterm &amp; review</w:t></w:r></w:p><w:p><w:r><w:t>Nov 13</w:t><w:tab/><w:t>25%</w:t></w:r></w:p></w:body></w:document>';
  const buf = await zip([['[Content_Types].xml', '<Types/>', false], ['word/document.xml', doc, true]]);
  assert.equal(await officeText(buf, 'docx'), 'Midterm & review\nNov 13\t25%');
});

test('spreadsheets come out row by row with shared strings filled in', async () => {
  const strings = '<sst><si><t>Essay 2</t></si><si><t>Due</t></si></sst>';
  const sheet = '<worksheet><sheetData><row r="1"><c r="A1" t="s"><v>1</v></c></row><row r="2"><c r="A2" t="s"><v>0</v></c><c r="B2"><v>46339</v></c></row></sheetData></worksheet>';
  const buf = await zip([['xl/sharedStrings.xml', strings, true], ['xl/worksheets/sheet1.xml', sheet, false]]);
  const text = await officeText(buf, 'xlsx');
  assert.match(text, /Excel dates/);
  assert.ok(text.endsWith('Due\nEssay 2\t46339'), text);
});

test('slides keep their order and entities are decoded', async () => {
  const slide = (t) => `<p:sld><a:p><a:r><a:t>${t}</a:t></a:r></a:p></p:sld>`;
  const buf = await zip([['ppt/slides/slide10.xml', slide('Last'), true], ['ppt/slides/slide2.xml', slide('Week 2 &#8211; quiz'), true]]);
  assert.equal(await officeText(buf, 'pptx'), 'Slide 1\nWeek 2 – quiz\n\nSlide 2\nLast');
  assert.equal(xmlText('<t>A &lt;B&gt; &#x41;</t>', /(?!)/g), 'A <B> A');
});
