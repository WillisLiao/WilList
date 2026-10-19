import { h, icon, openSheet, field, toast, download } from '../ui.js';
import { fmtShort, diffDays } from '../dates.js';
import { TIPS, PRINCIPLES } from '../coach.js';
import { buildICS } from '../ics.js';
import { isOpen } from '../agenda.js';
import { uid, normalize } from '../store.js';

function worryBuster(ctx, existing) {
  const w = existing ? { ...existing } : { id: uid(), date: ctx.today, worry: '', facts: '', worst: '', accepted: false, actions: '' };
  const ta = (k, rows, ph) => h('textarea', { rows: String(rows), value: w[k] || '', placeholder: ph, oninput: (e) => { w[k] = e.target.value; } });
  let close = null;
  const body = h('div', { class: 'editor' },
    h('p', { class: 'lede' }, TIPS.worry),
    field('1. What exactly are you worried about?', ta('worry', 3, 'e.g. I might fail the Organic Chem midterm'), 'Write it down. Accurate diagnosis is half the cure. If it is a cluster of worries, number them.'),
    field('Get the facts: what could you check or ask?', ta('facts', 2, 'e.g. Ask the TA what is on it; check my grade so far'), 'Most worries evaporate once you get the real facts.'),
    field('2. What is the worst possible outcome?', ta('worst', 2, 'e.g. I fail it and need to retake the course in summer')),
    h('label', { class: 'check-line' },
      h('input', { type: 'checkbox', checked: w.accepted, onchange: (e) => { w.accepted = e.target.checked; } }),
      h('span', null, h('b', null, '3. If it happens, I will accept it. '), 'It would hurt, but it would not break me.')),
    field('4. Start improving on the worst, right now', ta('actions', 4, 'One action per line\nGo to office hours Thursday\nDo 20 practice problems\nForm a study group'), 'The antidote to worry is purposeful action.'),
    h('div', { class: 'btn-row sticky' },
      h('button', { class: 'btn primary', onclick: () => {
        const lines = w.actions.split('\n').map((l) => l.trim()).filter(Boolean);
        ctx.act.saveWorry(w);
        if (lines.length) ctx.act.addMany(lines);
        close();
        toast(lines.length ? `${lines.length} action(s) added. Give them a letter on Today.` : 'Saved.');
      } }, icon('check'), 'Save + turn actions into tasks'),
      h('button', { class: 'btn ghost', onclick: () => close() }, 'Close')),
    ctx.s.worries.length ? h('details', { class: 'history' },
      h('summary', null, `Past worries (${ctx.s.worries.length})`),
      h('ul', { class: 'mini' }, [...ctx.s.worries].reverse().map((x) => h('li', { role: 'button', tabindex: '0', onclick: () => { close(); worryBuster(ctx, x); } },
        h('span', { class: 'chip' }, fmtShort(x.date)), h('span', null, x.worry.split('\n')[0] || '(empty)'))))) : null);
  close = openSheet('Worry Buster', body);
}

function mindStorm(ctx) {
  const st = { id: uid(), date: ctx.today, question: '', ideas: Array(20).fill(''), picked: null };
  let close = null;
  const counter = h('span', { class: 'count' }, '0/20');
  const update = () => { counter.textContent = `${st.ideas.filter((x) => x.trim()).length}/20`; };
  const body = h('div', { class: 'editor' },
    h('p', { class: 'lede' }, TIPS.mindstorm),
    field('Your goal or situation, as a question', h('input', { type: 'text', placeholder: 'What can I do to raise my GPA to 3.7 this semester?', oninput: (e) => { st.question = e.target.value; } })),
    h('div', { class: 'card-head' }, h('h3', null, 'Twenty answers'), counter),
    h('ol', { class: 'ideas' }, st.ideas.map((_, i) => h('li', null,
      h('input', { type: 'radio', name: 'pick', 'aria-label': `Pick idea ${i + 1}`, onchange: () => { st.picked = i; } }),
      h('input', { type: 'text', 'aria-label': `Idea ${i + 1}`, oninput: (e) => { st.ideas[i] = e.target.value; update(); } })))),
    h('div', { class: 'btn-row sticky' },
      h('button', { class: 'btn primary', onclick: () => {
        const pick = st.picked != null ? st.ideas[st.picked].trim() : '';
        if (!pick) { toast('Pick one idea (the circle) to act on now.'); return; }
        ctx.act.saveStorm(st);
        ctx.act.createItem({ title: pick, type: 'task', priority: 'A', notes: st.question });
        close();
        toast('Added as an A. Do it now.');
      } }, icon('play'), 'Act on the picked idea'),
      h('button', { class: 'btn ghost', onclick: () => { if (st.question || st.ideas.some(Boolean)) ctx.act.saveStorm(st); close(); } }, 'Save + close')));
  close = openSheet('20 Ideas', body);
}

function preGame(ctx) {
  const upcoming = ctx.s.items.filter((it) => (it.type === 'exam' || it.type === 'presentation') && isOpen(it, ctx.today) && it.date && diffDays(ctx.today, it.date) <= 21)
    .sort((a, b) => a.date.localeCompare(b.date));
  const st = { event: upcoming[0]?.title || '' };
  const aff = h('input', { type: 'text', value: 'I am calm, prepared, and I know this material.' });
  const body = h('div', { class: 'editor' },
    h('p', { class: 'lede' }, 'Quick programming for an important one-off event. Top performers live it inside before they live it outside. Use it whenever the event comes to mind, and again just before it starts.'),
    field('For', upcoming.length
      ? h('select', { onchange: (e) => { st.event = e.target.value; } }, upcoming.map((it) => h('option', { value: it.title }, `${it.title} · ${fmtShort(it.date)}`)), h('option', { value: '' }, 'Something else'))
      : h('input', { type: 'text', placeholder: 'e.g. Calc midterm, internship interview', oninput: (e) => { st.event = e.target.value; } })),
    field('1. Recall and relive a past success', h('textarea', { rows: '2', placeholder: 'The last time you nailed an exam or a talk. How did it feel?' }), 'Winners replay their best performances; losers replay their failures.'),
    field('2. Visualize the perfect outcome', h('textarea', { rows: '2', placeholder: 'I read the first question and know exactly how to start. I finish with 10 minutes to check.' })),
    field('3. Affirm it: personal, positive, present tense', aff),
    h('p', { class: 'field-hint' }, '4. Close your eyes and imagine how good it feels when it has already gone perfectly.'),
    h('div', { class: 'btn-row sticky' },
      h('button', { class: 'btn primary', onclick: () => { close(); toast(`Released. ${TIPS.release}`, { ms: 7000 }); } }, icon('spark'), 'Release it')));
  const close = openSheet('Pre-game', body);
}

function principles() {
  const body = h('div', { class: 'principles' },
    h('p', { class: 'lede' }, 'The ideas WilList is built on, from Brian Tracy’s Phoenix Seminar on the Psychology of Achievement (S = session) and his time-management work.'),
    PRINCIPLES.map((g) => h('section', null,
      h('h3', null, g.group),
      g.items.map(([title, idea, how, src]) => h('details', { class: 'pr' },
        h('summary', null, title),
        h('p', null, idea),
        h('p', { class: 'pr-how' }, h('b', null, 'In WilList: '), how),
        h('p', { class: 'pr-src' }, src))))));
  openSheet('Principles', body, { wide: true });
}

function exportCalendar(ctx) {
  let includeSessions = true;
  const body = h('div', { class: 'editor' },
    h('p', null, 'Browsers can only remind you while WilList is open. For reminders you can rely on, add everything to the calendar on your phone. You get classes and meetings (repeating), exams, presentations and deadlines with alarms, plus your study sessions and start days.'),
    h('label', { class: 'check-line' }, h('input', { type: 'checkbox', checked: true, onchange: (e) => { includeSessions = e.target.checked; } }), h('span', null, 'Include study sessions and “Start” days')),
    h('ul', { class: 'help' },
      h('li', null, h('b', null, 'iPhone: '), 'tap Download, then Add All.'),
      h('li', null, h('b', null, 'Google Calendar: '), 'on a computer, Settings → Import & export → Import.'),
      h('li', null, h('b', null, 'Outlook: '), 'open the file or use Add calendar → Upload from file.')),
    h('p', { class: 'field-hint' }, 'It is a snapshot. Export again after big changes.'),
    h('div', { class: 'btn-row sticky' },
      h('button', { class: 'btn primary', onclick: () => {
        const ics = buildICS(ctx.s.items, { today: ctx.today, includeSessions });
        download(`willist-${ctx.today}.ics`, ics, 'text/calendar');
      } }, icon('calendar'), 'Download .ics')));
  openSheet('Add to your calendar', body);
}

function backup(ctx) {
  const file = h('input', { type: 'file', accept: 'application/json,.json', class: 'visually-hidden', onchange: async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    try {
      const data = JSON.parse(await f.text());
      if (!data || !Array.isArray(data.items)) throw new Error('not a WilList backup');
      if (!confirm(`Replace everything on this device with the backup (${data.items.length} items)?`)) return;
      ctx.store.replace(normalize(data));
      close();
      toast('Backup restored.', { action: { label: 'Undo', fn: () => ctx.store.undo() } });
    } catch (err) {
      toast(`Could not read that file: ${err.message}`);
    }
  } });
  const body = h('div', { class: 'editor' },
    h('p', null, 'Your data lives only in this browser on this device. Nothing is uploaded. Download a backup now and then, and use it to move to another device.'),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', onclick: () => download(`willist-backup-${ctx.today}.json`, JSON.stringify(ctx.store.state, null, 2), 'application/json') }, 'Download backup'),
      h('button', { class: 'btn', onclick: () => file.click() }, 'Restore from file'), file),
    h('hr'),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn', onclick: () => { close(); ctx.act.loadSample(); } }, 'Load sample week'),
      h('button', { class: 'btn danger', onclick: () => {
        if (!confirm('Delete everything in WilList on this device?')) return;
        ctx.act.resetAll();
        close();
      } }, icon('trash'), 'Erase everything')));
  const close = openSheet('Backup & data', body);
}

function settings(ctx) {
  const st = { ...ctx.s.settings };
  const num = (k, label, hint, { min, step, scale = 1 }) => field(label, h('input', { type: 'number', min, step, value: String(st[k] / scale),
    oninput: (e) => { st[k] = Math.round(Number(e.target.value || 0) * scale); } }), hint);
  let close = null;
  const body = h('form', { class: 'editor', onsubmit: (e) => {
    e.preventDefault();
    ctx.act.saveSettings(st);
    close();
  } },
    h('div', { class: 'two' },
      num('perDayMin', 'Study budget per day (hours)', 'How much planned study fits in a normal day.', { min: '0.5', step: '0.5', scale: 60 }),
      num('sessionMin', 'Session length (minutes)', 'Short sessions with breaks help you remember.', { min: '15', step: '5' })),
    h('div', { class: 'two' },
      num('bufferDays', 'Finish deadlines early by (days)', null, { min: '0', step: '1' }),
      field('Plan-tomorrow time', h('input', { type: 'time', value: st.planTime, onchange: (e) => { st.planTime = e.target.value || '20:30'; } }))),
    field('Reward for finishing your A’s', h('input', { type: 'text', value: st.reward || '', placeholder: 'e.g. an episode of my show', oninput: (e) => { st.reward = e.target.value; } }), 'Small rewards along the way keep you going.'),
    field('Dates typed like 3/4 mean', h('select', { onchange: (e) => { st.dateOrder = e.target.value || null; } },
      h('option', { value: '', selected: !st.dateOrder }, 'Follow my device'),
      h('option', { value: 'mdy', selected: st.dateOrder === 'mdy' }, 'Month/day (Mar 4)'),
      h('option', { value: 'dmy', selected: st.dateOrder === 'dmy' }, 'Day/month (3 Apr)'))),
    h('label', { class: 'check-line' }, h('input', { type: 'checkbox', checked: st.tips, onchange: (e) => { st.tips = e.target.checked; } }), h('span', null, 'Show coaching tips')),
    h('label', { class: 'check-line' }, h('input', { type: 'checkbox', checked: st.notify, onchange: async (e) => {
      st.notify = e.target.checked;
      if (st.notify && 'Notification' in window && Notification.permission !== 'granted') {
        const p = await Notification.requestPermission();
        if (p !== 'granted') { st.notify = false; e.target.checked = false; toast('Notifications are blocked in this browser.'); }
      }
    } }), h('span', null, 'Remind me while WilList is open (classes, plan time, start days)')),
    h('div', { class: 'btn-row sticky' }, h('button', { type: 'submit', class: 'btn primary' }, 'Save'), h('button', { type: 'button', class: 'btn ghost', onclick: () => close() }, 'Cancel')));
  close = openSheet('Settings', body);
}

const TOOLS = [
  ['spark', 'Worry Buster', 'Stressed about an exam or a deadline? Four steps from worry to action.', worryBuster],
  ['plan', '20 Ideas', 'Stuck? Ask a question, write 20 answers, act on one.', mindStorm],
  ['target', 'Pre-game', 'Two minutes of mental rehearsal before an exam or presentation.', preGame],
  ['book', 'Principles', 'The Brian Tracy ideas behind WilList, and where each one lives in the app.', principles],
  ['calendar', 'Add to calendar', 'Export everything as .ics for real phone reminders.', exportCalendar],
  ['undo', 'Backup & data', 'Download, restore, sample data.', backup],
  ['tools', 'Settings', 'Study budget, session length, plan time, reminders.', settings],
];

export function renderTools(ctx) {
  const total = ctx.s.items.filter((it) => !it.done).length;
  return h('div', { class: 'view tools' },
    h('header', { class: 'view-head' }, h('h1', null, 'Tools')),
    h('ul', { class: 'tool-grid' }, TOOLS.map(([ic, title, desc, fn]) => h('li', null,
      h('button', { class: 'tool', onclick: () => fn(ctx) }, h('span', { class: 'tool-ic' }, icon(ic)), h('b', null, title), h('span', null, desc))))),
    h('p', { class: 'foot-tip center' }, `${total} open item${total === 1 ? '' : 's'} · ${ctx.s.goals.length} goal${ctx.s.goals.length === 1 ? '' : 's'} · data stays on this device · `,
      h('button', { class: 'link', onclick: () => backup(ctx) }, 'back up')));
}

