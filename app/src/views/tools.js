import { h, fill, icon, tag, sec, band, lbl, openSheet, field, toast, download, ask } from '../ui.js';
import { fmtShort, diffDays } from '../dates.js';
import { PRINCIPLES } from '../coach.js';
import { buildICS } from '../ics.js';
import { isOpen } from '../agenda.js';
import { uid, normalize } from '../store.js';
import { openImport } from './importview.js';
import { openCoach } from './coachview.js';

const actions = (...btns) => h('div', { class: 'btn-row sticky-actions' }, btns);

function worryBuster(ctx, existing) {
  const w = existing ? { ...existing } : { id: uid(), date: ctx.today, worry: '', facts: '', worst: '', accepted: false, actions: '' };
  const ta = (k, rows, ph) => h('textarea', { rows: String(rows), value: w[k] || '', placeholder: ph, oninput: (e) => { w[k] = e.target.value; } });
  let close = null;
  const body = h('div', { class: 'fields' },
    field('1. The worry', ta('worry', 2, 'I might fail the midterm')),
    field('2. Worst case', ta('worst', 2, 'I retake it in summer')),
    h('label', { class: 'check-row' },
      h('input', { type: 'checkbox', checked: w.accepted, onchange: (e) => { w.accepted = e.target.checked; } }),
      h('span', null, '3. I can accept that')),
    field('4. What I’ll do now', ta('actions', 3, 'One per line\nGo to office hours\nDo 20 practice problems'), 'Each line becomes a task.'),
    actions(
      h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const lines = w.actions.split('\n').map((l) => l.trim()).filter(Boolean);
        ctx.act.saveWorry(w);
        if (lines.length) ctx.act.addMany(lines);
        close();
        toast(lines.length ? `${lines.length} added.` : 'Saved.');
      } }, 'Save')),
    ctx.s.worries.length ? h('details', null,
      h('summary', { class: 'lbl' }, `Past (${ctx.s.worries.length})`),
      h('ul', { class: 'lines' }, [...ctx.s.worries].reverse().map((x) => h('li', null,
        tag(fmtShort(x.date)),
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => { close(); worryBuster(ctx, x); } }, x.worry.split('\n')[0] || '(empty)'))))) : null);
  close = openSheet('Worry Buster', body);
}

function mindStorm(ctx) {
  const st = { id: uid(), date: ctx.today, question: '', ideas: Array(20).fill(''), picked: null };
  let close = null;
  const counter = h('span', { class: 'count' }, '0/20');
  const list = h('ol', { class: 'ideas' });
  const draw = () => {
    counter.textContent = `${st.ideas.filter((x) => x.trim()).length}/20`;
    list.querySelectorAll('.pickme').forEach((b, i) => b.setAttribute('aria-pressed', String(st.picked === i)));
  };
  fill(list, st.ideas.map((_, i) => h('li', null,
    h('button', { class: 'pickme', type: 'button', 'aria-pressed': 'false', 'aria-label': `Act on idea ${i + 1}`, onclick: () => { st.picked = i; draw(); } }, String(i + 1)),
    h('input', { type: 'text', 'aria-label': `Idea ${i + 1}`, oninput: (e) => { st.ideas[i] = e.target.value; draw(); } }))));
  const body = h('div', { class: 'fields' },
    field('Your question', h('input', { type: 'text', placeholder: 'How can I raise my GPA to 3.7?', oninput: (e) => { st.question = e.target.value; } })),
    h('div', { class: 'sec' }, h('h3', null, '20 answers'), counter, h('span', { class: 'note' }, 'Tap a number to pick one.')),
    list,
    actions(
      h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const pick = st.picked != null ? st.ideas[st.picked].trim() : '';
        if (!pick) { toast('Pick one idea first.'); return; }
        ctx.act.saveStorm(st);
        ctx.act.createItem({ title: pick, type: 'task', priority: 'A', notes: st.question });
        close();
        toast('Added as an A.');
      } }, icon('play'), 'Do it'),
      h('button', { class: 'btn quiet', type: 'button', onclick: () => { if (st.question || st.ideas.some(Boolean)) ctx.act.saveStorm(st); close(); } }, 'Save')));
  close = openSheet('20 Ideas', body);
}

function preGame(ctx) {
  const upcoming = ctx.s.items.filter((it) => (it.type === 'exam' || it.type === 'presentation') && isOpen(it, ctx.today) && it.date && diffDays(ctx.today, it.date) <= 21)
    .sort((a, b) => a.date.localeCompare(b.date));
  let close = null;
  const body = h('div', { class: 'fields' },
    field('For', upcoming.length
      ? h('select', null, upcoming.map((it) => h('option', null, `${it.title} · ${fmtShort(it.date)}`)), h('option', null, 'Something else'))
      : h('input', { type: 'text', placeholder: 'Calc midterm, internship interview…' })),
    field('1. A time it went well', h('textarea', { rows: '2' })),
    field('2. Picture it going perfectly', h('textarea', { rows: '2' })),
    field('3. Say it', h('input', { type: 'text', value: 'I am calm and prepared.' })),
    h('p', null, '4. Close your eyes. Feel it done.'),
    actions(h('button', { class: 'btn primary', type: 'button', onclick: () => { close(); toast('Now let it go.'); } }, 'Done')));
  close = openSheet('Pre-game', body);
}

function principles() {
  const body = h('div', { class: 'fields' },
    h('p', { class: 'lede' }, 'The ideas WilList is built on, from Brian Tracy’s Phoenix Seminar on the Psychology of Achievement (S = session) and his time-management work.'),
    PRINCIPLES.map((g) => h('section', { class: 'part' },
      sec(g.group, { level: 'h3', count: g.items.length }),
      g.items.map(([title, idea, how, src]) => h('details', null,
        h('summary', null, h('b', null, title)),
        h('div', { class: 'fields' },
          h('p', null, idea),
          h('p', null, lbl('In WilList: '), how),
          h('p', { class: 'mono muted' }, src)))))));
  openSheet('Principles', body);
}

function exportCalendar(ctx) {
  let includeSessions = true;
  const body = h('div', { class: 'fields' },
    h('p', null, 'Reminders in your phone’s calendar.'),
    h('label', { class: 'check-row' }, h('input', { type: 'checkbox', checked: true, onchange: (e) => { includeSessions = e.target.checked; } }), h('span', null, 'Include study sessions')),
    actions(h('button', { class: 'btn primary', type: 'button', onclick: () => {
      download(`willist-${ctx.today}.ics`, buildICS(ctx.s.items, { today: ctx.today, includeSessions }), 'text/calendar');
    } }, 'Download .ics')));
  openSheet('Add to calendar', body);
}

function backup(ctx) {
  let close = null;
  const file = h('input', { type: 'file', accept: 'application/json,.json', class: 'visually-hidden', onchange: async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    try {
      const data = JSON.parse(await f.text());
      if (!data || !Array.isArray(data.items)) throw new Error('this is not a WilList backup');
      if (!(await ask('Restore this backup?', `Replaces everything here (${data.items.length} items).`, 'Restore', { danger: true }))) return;
      ctx.store.replace(normalize(data));
      close();
      toast('Backup restored.', { action: { label: 'Undo', fn: () => ctx.store.undo() } });
    } catch (err) {
      toast(`Could not read that file: ${err.message}.`);
    }
  } });
  const body = h('div', { class: 'fields' },
    h('p', null, 'Everything stays on this device. Back it up now and then.'),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => download(`willist-backup-${ctx.today}.json`, JSON.stringify(ctx.store.state, null, 2), 'application/json') }, 'Download backup'),
      h('button', { class: 'btn', type: 'button', onclick: () => file.click() }, 'Restore'), file),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn', type: 'button', onclick: () => { close(); ctx.act.loadSample(); } }, 'Load sample'),
      h('button', { class: 'btn danger', type: 'button', onclick: async () => {
        if (!(await ask('Erase everything?', 'All items, goals and settings on this device.', 'Yes, erase everything', { danger: true }))) return;
        ctx.act.resetAll();
        close();
      } }, 'Erase everything')));
  close = openSheet('Backup & data', body);
}

function settings(ctx) {
  const st = { ...ctx.s.settings, calib: { ...(ctx.s.settings.calib || {}) } };
  const num = (k, label, hint, { min, step, scale = 1 }) => field(label, h('input', { type: 'number', min, step, value: String(st[k] / scale),
    oninput: (e) => { st[k] = Math.round(Number(e.target.value || 0) * scale); } }), hint);
  const time = (k, label) => field(label, h('input', { type: 'time', value: st[k], onchange: (e) => { if (e.target.value) st[k] = e.target.value; } }));
  let close = null;
  const pace = Object.entries(st.calib).filter(([, v]) => v && v !== 1);
  const body = h('form', { class: 'fields', onsubmit: (e) => { e.preventDefault(); ctx.act.saveSettings(st); close(); } },
    h('div', { class: 'two' },
      num('perDayMin', 'Study hours a day', null, { min: '0.5', step: '0.5', scale: 60 }),
      num('sessionMin', 'Session minutes', null, { min: '15', step: '5' })),
    h('div', { class: 'two' },
      num('bufferDays', 'Finish early by (days)', null, { min: '0', step: '1' }),
      num('taskMin', 'Quick task minutes', null, { min: '5', step: '5' })),
    pace.length ? h('div', { class: 'f' }, lbl('Your pace'),
      h('p', null, pace.map(([t, v]) => `${t} ${v}×`).join(' · '), ' ',
        h('button', { class: 'link', type: 'button', onclick: () => { st.calib = {}; toast('Pace reset. Save to apply.'); } }, 'Reset'))) : null,
    h('div', { class: 'two' }, time('dayStart', 'Day starts'), time('dayEnd', 'Day ends')),
    time('planTime', 'Plan tomorrow at'),
    field('Dates like 3/4 mean', h('select', { onchange: (e) => { st.dateOrder = e.target.value || null; } },
      h('option', { value: '', selected: !st.dateOrder }, 'Follow my device'),
      h('option', { value: 'mdy', selected: st.dateOrder === 'mdy' }, 'Month/day (March 4)'),
      h('option', { value: 'dmy', selected: st.dateOrder === 'dmy' }, 'Day/month (3 April)'))),
    h('label', { class: 'check-row' }, h('input', { type: 'checkbox', checked: st.tips, onchange: (e) => { st.tips = e.target.checked; } }), h('span', null, 'Coaching tips while typing')),
    h('label', { class: 'check-row' }, h('input', { type: 'checkbox', checked: st.notify, onchange: async (e) => {
      st.notify = e.target.checked;
      if (st.notify && 'Notification' in window && Notification.permission !== 'granted') {
        const p = await Notification.requestPermission();
        if (p !== 'granted') { st.notify = false; e.target.checked = false; toast('Notifications are blocked in this browser.'); }
      }
    } }), h('span', null, 'Reminders while open')),
    actions(h('button', { type: 'submit', class: 'btn primary' }, 'Save'), h('button', { type: 'button', class: 'btn quiet', onclick: () => close() }, 'Cancel')));
  close = openSheet('Settings', body);
}

// [label, icon, colour (a divider), open]
const TOOLS = [
  ['Import semester', 'import', 'today', (ctx) => openImport(ctx)],
  ['Coach', 'coach', 'plan', (ctx) => openCoach(ctx)],
  ['Worry Buster', 'worry', 'ahead', worryBuster],
  ['20 Ideas', 'ideas', 'today', mindStorm],
  ['Pre-game', 'pregame', 'goals', preGame],
  ['Principles', 'principles', 'more', () => principles()],
  ['Add to calendar', 'calendar', 'ahead', exportCalendar],
  ['Backup', 'backup', 'goals', backup],
  ['Settings', 'settings', null, settings],
];

export function renderTools(ctx) {
  return h('div', { class: 'view tools' },
    band('More', h('h1', { class: 'display' }, 'More')),
    h('div', { class: 'col page' },
      h('ul', { class: 'menu' }, TOOLS.map(([label, ic, s, fn]) => h('li', null,
        h('button', { type: 'button', 'data-s': s, onclick: () => fn(ctx) },
          h('span', { class: 'ti' }, icon(ic)), h('b', null, label), icon('next')))))));
}
