// Optional coach powered by Claude. It runs on the student's own Anthropic API
// key, which is kept in this browser only (never in backups), and calls go
// straight from the browser to Anthropic. Without a key, none of this loads.

import { fmtLong, diffDays } from './dates.js';
import { dayRows, missedSessions, isOpen } from './agenda.js';
import { a1Streak } from './insights.js';
import { fileBlocks } from './files.js';

const KEY_STORE = 'willist.ai-key';
export const MODEL = 'claude-opus-5-5';
// Opus 5.5 pricing per million tokens, for the cost line shown after each call.
const PRICE = { input: 4, output: 20, cacheRead: 0.2, cacheWrite: 5 };
// A declined request is re-run on Anthropic's recommended fallback model instead of failing.
const FALLBACK = { betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default' };

export function getKey() {
  try { return localStorage.getItem(KEY_STORE) || ''; } catch { return ''; }
}

export function setKey(key) {
  try {
    if (key) localStorage.setItem(KEY_STORE, key.trim());
    else localStorage.removeItem(KEY_STORE);
  } catch { /* storage blocked */ }
}

let cached = null;
let testFetch = null;

// Tests swap in a fake fetch so no real request (or charge) is made.
export function useFetchForTests(fn) {
  testFetch = fn;
  cached = null;
}

async function sdk() {
  const key = getKey();
  if (!key) throw new CoachError('Add your Anthropic API key first (More → Coach).');
  if (!cached || cached.key !== key) {
    const { default: Anthropic } = await import('../vendor/anthropic-sdk-0.131.0.mjs');
    const opts = { apiKey: key, dangerouslyAllowBrowser: true, maxRetries: 2 };
    if (testFetch) opts.fetch = testFetch;
    cached = { key, Anthropic, client: new Anthropic(opts) };
  }
  return cached;
}

export class CoachError extends Error {}

// Plain-language messages for the errors a student can do something about.
function explain(err, Anthropic) {
  if (err instanceof CoachError) return err;
  if (Anthropic) {
    if (err instanceof Anthropic.AuthenticationError) return new CoachError('Anthropic rejected that API key. Check it in More → Coach.');
    if (err instanceof Anthropic.PermissionDeniedError) return new CoachError('This API key is not allowed to use Claude Opus 5.5.');
    if (err instanceof Anthropic.RateLimitError) return new CoachError('Too many requests right now. Wait a minute and try again.');
    if (err instanceof Anthropic.BadRequestError) return new CoachError(`Anthropic could not process that request: ${err.message}`);
    if (err instanceof Anthropic.APIConnectionError) return new CoachError('Could not reach Anthropic. Check your connection.');
    if (err instanceof Anthropic.APIError) return new CoachError(`Anthropic returned an error (${err.status ?? 'network'}). Try again shortly.`);
  }
  return new CoachError(err?.message || 'Something went wrong talking to the coach.');
}

export function costOf(usage) {
  if (!usage) return null;
  const usd = ((usage.input_tokens || 0) * PRICE.input + (usage.output_tokens || 0) * PRICE.output +
    (usage.cache_read_input_tokens || 0) * PRICE.cacheRead + (usage.cache_creation_input_tokens || 0) * PRICE.cacheWrite) / 1e6;
  const tokens = (usage.input_tokens || 0) + (usage.output_tokens || 0) + (usage.cache_read_input_tokens || 0) + (usage.cache_creation_input_tokens || 0);
  return { usd, tokens };
}

// Text the student should see: after a mid-answer fallback, only the part the fallback model wrote.
export function visibleText(content) {
  const blocks = content || [];
  const cut = blocks.map((b) => b.type).lastIndexOf('fallback');
  return blocks.slice(cut + 1).filter((b) => b.type === 'text').map((b) => b.text).join('');
}

// ------------------------------------------------------------ structuring text into items

const ITEM_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['items'],
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['title', 'type', 'date', 'time', 'course', 'weightPct', 'effortHours', 'repeatDays', 'durationMin'],
        properties: {
          title: { type: 'string', description: 'Short name in the source’s own words, at most 60 characters.' },
          type: { type: 'string', enum: ['exam', 'deadline', 'presentation', 'reading', 'event', 'task'] },
          date: { type: 'string', description: 'YYYY-MM-DD, or "" if the text gives none.' },
          time: { type: 'string', description: '24-hour HH:MM, or "" if none.' },
          course: { type: 'string', description: 'Short label for the course, project or team, such as MATH201, or "".' },
          weightPct: { type: 'number', description: 'Share of the final grade if stated, else 0.' },
          effortHours: { type: 'number', description: 'Realistic preparation hours for exams, deadlines, presentations and readings; 0 for classes, meetings and small tasks.' },
          repeatDays: { type: 'array', items: { type: 'integer' }, description: 'For weekly classes, meetings or shifts: weekdays 0=Sun … 6=Sat. Otherwise empty.' },
          durationMin: { type: 'integer', description: 'Length of a class, meeting or shift in minutes, else 0.' },
        },
      },
    },
  },
};

function extractSystem(today) {
  return [
    'You turn what someone shares into planner items. It can be anything with dates in it: a syllabus, a class or work timetable, a project plan, a shift roster, an event programme, an email, a photo of a whiteboard or a printed schedule, or a messy list.',
    `Today is ${fmtLong(today)} (${today}).`,
    'Rules:',
    '- One item per exam or test, deadline or deliverable, presentation, reading, recurring class, meeting or shift, appointment, or concrete to-do.',
    '- Leave out topics, holidays and "no class" days unless something is due.',
    '- Resolve relative or partial dates against today. Leave out anything that is already in the past.',
    '- Never invent items, dates or grade weights that the source does not support.',
    '- Recurring classes, meetings and shifts are type "event" with repeatDays, a time and durationMin.',
  ].join('\n');
}

// content is a string or content blocks (a PDF, a photo, a file's text).
async function extract(content, today) {
  let lib = null;
  try {
    lib = await sdk();
    const res = await lib.client.beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      ...FALLBACK,
      output_config: { effort: 'medium', format: { type: 'json_schema', schema: ITEM_SCHEMA } },
      system: extractSystem(today),
      messages: [{ role: 'user', content }],
    });
    if (res.stop_reason === 'refusal') throw new CoachError('Claude declined to read that. Try just the schedule part.');
    if (res.stop_reason === 'max_tokens') throw new CoachError('That was too long to read in one go. Split it in two.');
    const data = JSON.parse(visibleText(res.content));
    return { items: data.items.map(toFields).filter(Boolean), cost: costOf(res.usage) };
  } catch (err) {
    throw explain(err, lib?.Anthropic);
  }
}

export function structureText(text, today) {
  return extract(text, today);
}

export async function structureFile(file, today) {
  if (!getKey()) throw new CoachError('Add your Anthropic API key first (More → Coach).');
  const blocks = await fileBlocks(file);
  return extract([...blocks, { type: 'text', text: 'Turn this into planner items.' }], today);
}

function toFields(x) {
  const date = /^\d{4}-\d{2}-\d{2}$/.test(x.date) ? x.date : null;
  if (!date && x.type !== 'task') return null;
  const days = [...new Set((x.repeatDays || []).filter((d) => d >= 0 && d <= 6))].sort();
  return {
    title: x.title.slice(0, 80),
    type: x.type,
    date,
    time: /^\d{2}:\d{2}$/.test(x.time) ? x.time : null,
    course: x.course || null,
    weightPct: x.weightPct > 0 ? x.weightPct : null,
    effortMin: x.effortHours > 0 ? Math.round(x.effortHours * 60) : null,
    recur: x.type === 'event' && days.length ? { freq: 'weekly', days } : null,
    durationMin: x.type === 'event' && x.durationMin > 0 ? x.durationMin : null,
  };
}

// ------------------------------------------------------------ the coach

const COACH_SYSTEM = `You are the coach inside WilList, a student planner built on Brian Tracy's time-management and goal-setting methods. You coach in the spirit of his teaching; you are not Brian Tracy and never claim to be.

Methods to draw on when they fit:
- ABCDE: A = serious consequences if not done, B = mild, C = none, D = delegate, E = eliminate. Number the A's; never start a B while an A is undone.
- "What is the most valuable use of my time right now?" Do first things first and single-handle a task to completion. Do it now; build a sense of urgency.
- Plan the night before; every minute planning saves 5–15 minutes doing. Work from written lists.
- Sub-deadlines and small rewards. Identify the one biggest obstacle (the rock) and swarm all over it. Ask your way to success: professors, TAs, classmates.
- Study: spaced repetition beats cramming; short sessions with breaks; test yourself; teach what you learn; sleep before exams.
- Worry buster: define the worry in writing, name the worst outcome, accept it, start improving on it. The antidote to worry is purposeful action.
- Fail forward; no blame; "what can I do from here?"; persistence.
- Balance: people, health and rest are the reason for the rest.

How to answer:
- Ground every answer in the student's actual items and dates, which appear below and in later system messages.
- Be concrete and brief: a few short paragraphs or a short list. Plain words, no hype, no motivational filler.
- End with one specific next action they can start in the next ten minutes.
- If they describe distress beyond ordinary school stress, say kindly that talking to someone they trust or campus counselling is a good step, and keep helping with the practical side.`;

export function snapshot(s, today, now = new Date()) {
  const rows = dayRows(s.items, today).filter((r) => 'ABCD'.includes(r.priority));
  const soon = s.items.filter((it) => isOpen(it, today) && it.date && !it.recur && it.type !== 'event' &&
    diffDays(today, it.date) >= 0 && diffDays(today, it.date) <= 21).sort((a, b) => a.date.localeCompare(b.date));
  const missed = missedSessions(s.items, today);
  const line = (it) => [
    it.priority ? `[${it.priority}]` : '[unlettered]', it.title, `(${it.type}`,
    it.date ? `, ${it.date}${it.time ? ` ${it.time}` : ''}` : '', it.course ? `, ${it.course}` : '',
    it.weightPct ? `, ${it.weightPct}% of grade` : '', ')',
  ].join('');
  return [
    `Now: ${fmtLong(today)} ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}.`,
    s.mdp ? `Major definite purpose: ${s.mdp}` : 'No major definite purpose written yet.',
    `Daily study budget: ${Math.round(s.settings.perDayMin / 6) / 10} h. A1-first streak: ${a1Streak(s.meta.firstDone, today)} day(s).`,
    `Today's list, in order: ${rows.length ? rows.map((r) => `${r.label} ${r.item.title}${r.session ? ` (${r.session.label})` : ''}`).join('; ') : 'empty'}.`,
    `Coming up in 3 weeks: ${soon.length ? soon.slice(0, 25).map(line).join('; ') : 'nothing dated'}.`,
    missed.length ? `Behind on: ${missed.map((m) => `${m.item.title} (${m.count} missed session(s))`).join('; ')}.` : 'No missed study sessions.',
    s.goals.length ? `Goals: ${s.goals.map((g) => g.title).join('; ')}.` : 'No written goals yet.',
  ].join('\n');
}

export function newConversation(s, today) {
  return { system: `${COACH_SYSTEM}\n\nThe student's planner when this conversation started:\n${snapshot(s, today)}`, messages: [], lastSnapshot: snapshot(s, today), startedAt: today };
}

// Sends one turn. The conversation is append-only: the system prompt stays fixed and
// changes to the planner arrive as system messages, so earlier turns stay valid.
export async function ask(convo, question, s, today, onText) {
  let lib = null;
  const messages = [...convo.messages, { role: 'user', content: question }];
  const snap = snapshot(s, today);
  const added = [{ role: 'user', content: question }];
  if (snap !== convo.lastSnapshot) {
    const update = { role: 'system', content: `The planner now looks like this:\n${snap}` };
    messages.push(update);
    added.push(update);
  }
  try {
    lib = await sdk();
    const stream = lib.client.beta.messages.stream({
      model: MODEL,
      max_tokens: 8000,
      ...FALLBACK,
      cache_control: { type: 'ephemeral' },
      output_config: { effort: 'medium' },
      system: convo.system,
      messages,
    });
    stream.on('text', (delta) => onText?.(delta));
    const final = await stream.finalMessage();
    if (final.stop_reason === 'refusal') throw new CoachError('The coach could not answer that one. Try asking it differently.');
    return {
      convo: { ...convo, lastSnapshot: snap, messages: [...convo.messages, ...added, { role: 'assistant', content: final.content }] },
      text: visibleText(final.content),
      cost: costOf(final.usage),
    };
  } catch (err) {
    throw explain(err, lib?.Anthropic);
  }
}

