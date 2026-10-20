import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

const mem = new Map();
globalThis.localStorage = { getItem: (k) => mem.get(k) ?? null, setItem: (k, v) => mem.set(k, String(v)), removeItem: (k) => mem.delete(k) };
const ai = await import('../app/src/ai.js');
const { emptyState, makeItem } = await import('../app/src/store.js');

const today = '2026-10-20';
const settings = { sessionMin: 50, perDayMin: 120, bufferDays: 1 };
let calls = [];

function jsonFetch(body) {
  return async (url, init) => {
    calls.push({ url: String(url), headers: Object.fromEntries(new Headers(init.headers)), body: JSON.parse(init.body) });
    return new Response(JSON.stringify(body), { status: 200, headers: { 'content-type': 'application/json', 'request-id': 'req_test' } });
  };
}

function sseFetch(texts, content) {
  return async (url, init) => {
    calls.push({ url: String(url), headers: Object.fromEntries(new Headers(init.headers)), body: JSON.parse(init.body) });
    const ev = (name, data) => `event: ${name}\ndata: ${JSON.stringify(data)}\n\n`;
    let s = ev('message_start', { type: 'message_start', message: { id: 'msg_1', type: 'message', role: 'assistant', model: 'claude-opus-5-5', content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 900, output_tokens: 0 } } });
    s += ev('content_block_start', { type: 'content_block_start', index: 0, content_block: { type: 'thinking', thinking: '', signature: '' } });
    s += ev('content_block_delta', { type: 'content_block_delta', index: 0, delta: { type: 'signature_delta', signature: 'sig123' } });
    s += ev('content_block_stop', { type: 'content_block_stop', index: 0 });
    s += ev('content_block_start', { type: 'content_block_start', index: 1, content_block: { type: 'text', text: '' } });
    for (const t of texts) s += ev('content_block_delta', { type: 'content_block_delta', index: 1, delta: { type: 'text_delta', text: t } });
    s += ev('content_block_stop', { type: 'content_block_stop', index: 1 });
    s += ev('message_delta', { type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 120 } });
    s += ev('message_stop', { type: 'message_stop' });
    return new Response(s, { status: 200, headers: { 'content-type': 'text/event-stream' } });
  };
}

beforeEach(() => { calls = []; ai.setKey('sk-ant-test'); });

test('without a key nothing is sent', async () => {
  ai.setKey('');
  ai.useFetchForTests(jsonFetch({}));
  await assert.rejects(() => ai.structureText('x', today), /API key/);
  assert.equal(calls.length, 0);
});

test('structuring text sends a schema-constrained Opus 5.5 request with fallbacks', async () => {
  const items = [
    { title: 'Midterm', type: 'exam', date: '2026-11-13', time: '', course: 'HIST150', weightPct: 25, effortHours: 8, repeatDays: [], durationMin: 0 },
    { title: 'Lecture', type: 'event', date: '2026-10-20', time: '10:00', course: 'HIST150', weightPct: 0, effortHours: 0, repeatDays: [2, 4], durationMin: 75 },
    { title: 'No date', type: 'deadline', date: '', time: '', course: '', weightPct: 0, effortHours: 0, repeatDays: [], durationMin: 0 },
  ];
  ai.useFetchForTests(jsonFetch({ id: 'msg_1', type: 'message', role: 'assistant', model: 'claude-opus-5-5', stop_reason: 'end_turn', stop_sequence: null,
    content: [{ type: 'thinking', thinking: '', signature: 's' }, { type: 'text', text: JSON.stringify({ items }) }],
    usage: { input_tokens: 2000, output_tokens: 1000 } }));
  const r = await ai.structureText('HIST 150 syllabus…', today);
  const { body, headers, url } = calls[0];
  assert.match(url, /\/v1\/messages/);
  assert.equal(body.model, 'claude-opus-5-5');
  assert.equal(body.fallbacks, 'default');
  assert.match(headers['anthropic-beta'], /server-side-fallback-2026-07-01/);
  assert.equal(headers['anthropic-dangerous-direct-browser-access'], 'true');
  assert.equal(body.output_config.effort, 'medium');
  assert.equal(body.output_config.format.type, 'json_schema');
  assert.equal(body.thinking, undefined, 'Opus 5.5 always thinks; no thinking setting is sent');
  assert.equal(r.items.length, 2, 'items without a date are dropped');
  assert.equal(r.items[0].effortMin, 480);
  assert.equal(r.items[0].weightPct, 25);
  assert.deepEqual(r.items[1].recur, { freq: 'weekly', days: [2, 4] });
  assert.equal(r.items[1].durationMin, 75);
  assert.ok(Math.abs(r.cost.usd - 0.028) < 1e-9);
});

test('a refusal is reported instead of parsed', async () => {
  ai.useFetchForTests(jsonFetch({ id: 'm', type: 'message', role: 'assistant', model: 'claude-opus-5-5', stop_reason: 'refusal', stop_sequence: null,
    stop_details: { type: 'refusal', category: null, explanation: '' }, content: [], usage: { input_tokens: 10, output_tokens: 0 } }));
  await assert.rejects(() => ai.structureText('x', today), /declined/);
});

test('an invalid key gets a plain-language error', async () => {
  ai.useFetchForTests(async () => new Response(JSON.stringify({ type: 'error', error: { type: 'authentication_error', message: 'invalid x-api-key' } }), { status: 401, headers: { 'content-type': 'application/json' } }));
  await assert.rejects(() => ai.structureText('x', today), /rejected that API key/);
});

test('the coach streams, stores replies verbatim and appends planner changes as system messages', async () => {
  const s = emptyState();
  s.items.push(makeItem({ title: 'Calc midterm', type: 'exam', date: '2026-10-30', priority: 'A', effortMin: 240 }, settings, today));
  let convo = ai.newConversation(s, today);
  const firstSystem = convo.system;
  ai.useFetchForTests(sseFetch(['Start ', 'with the midterm.'], null));
  let streamed = '';
  const r1 = await ai.ask(convo, 'What first?', s, today, (t) => { streamed += t; });
  assert.equal(streamed, 'Start with the midterm.');
  assert.equal(r1.text, 'Start with the midterm.');
  convo = r1.convo;
  assert.equal(convo.messages.length, 2);
  assert.equal(convo.messages[1].content[0].type, 'thinking', 'thinking blocks are kept unchanged');
  assert.equal(calls[0].body.cache_control.type, 'ephemeral');
  assert.equal(calls[0].body.stream, true);

  // The planner changes; the next turn appends a system message instead of editing the prompt.
  s.items.push(makeItem({ title: 'Essay', type: 'deadline', date: '2026-10-25', priority: 'A', effortMin: 120 }, settings, today));
  ai.useFetchForTests(sseFetch(['Then the essay.'], null));
  const r2 = await ai.ask(convo, 'And then?', s, today);
  const sent = calls[1].body;
  assert.equal(sent.system, firstSystem);
  assert.deepEqual(sent.messages.slice(0, 2), convo.messages, 'earlier turns are sent back byte-for-byte');
  assert.equal(sent.messages[2].role, 'user');
  assert.equal(sent.messages[3].role, 'system');
  assert.match(sent.messages[3].content, /Essay/);
  assert.equal(r2.convo.messages.length, 5);
});

test('visible text skips what a declined model wrote before a fallback', () => {
  const content = [{ type: 'text', text: 'partial' }, { type: 'fallback', from: { model: 'a' }, to: { model: 'b' } }, { type: 'text', text: 'answer' }];
  assert.equal(ai.visibleText(content), 'answer');
});
