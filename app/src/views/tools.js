import { h, fill, icon, bubble, tag, sec, openSheet, field, toast, download, formLabel } from '../ui.js';
import { fmtShort, diffDays } from '../dates.js';
import { TIPS, PRINCIPLES } from '../coach.js';
import { buildICS } from '../ics.js';
import { isOpen } from '../agenda.js';
import { uid, normalize } from '../store.js';
import { getKey } from '../ai.js';
import { openImport } from './importview.js';
import { openCoach } from './coachview.js';

const actions = (...btns) => h('div', { class: 'btn-row sticky-actions' }, btns);

function worryBuster(ctx, existing) {
  const w = existing ? { ...existing } : { id: uid(), date: ctx.today, worry: '', facts: '', worst: '', accepted: false, actions: '' };
  const ta = (k, rows, ph) => h('textarea', { rows: String(rows), value: w[k] || '', placeholder: ph, oninput: (e) => { w[k] = e.target.value; } });
  let close = null;
  const body = h('div', { class: 'fields' },
    h('p', { class: 'lede' }, TIPS.worry),
    field('1. What exactly are you worried about?', ta('worry', 3, 'I might fail the Organic Chem midterm'), 'Write it down. Accurate diagnosis is half the cure. If it is several worries, number them.'),
    field('Get the facts: what could you check or ask?', ta('facts', 2, 'Ask the TA what is on it; check my grade so far'), 'Most worries shrink once you have the real facts.'),
    field('2. What is the worst possible outcome?', ta('worst', 2, 'I fail it and retake the course in summer')),
    h('label', { class: 'check' },
      h('input', { type: 'checkbox', checked: w.accepted, onchange: (e) => { w.accepted = e.target.checked; } }),
      h('span', null, h('b', null, '3. If it happens, I will accept it. '), 'It would hurt, but it would not break me.')),
    field('4. Start improving on the worst, right now', ta('actions', 4, 'One action per line\nGo to office hours Thursday\nDo 20 practice problems'), 'The antidote to worry is purposeful action. Each line becomes a task.'),
    actions(
      h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const lines = w.actions.split('\n').map((l) => l.trim()).filter(Boolean);
        ctx.act.saveWorry(w);
        if (lines.length) ctx.act.addMany(lines);
        close();
        toast(lines.length ? `${lines.length} action(s) added. Fill in their letters on Today.` : 'Saved.');
      } }, 'Save and add the actions'),
      h('button', { class: 'btn quiet', type: 'button', onclick: () => close() }, 'Close')),
    ctx.s.worries.length ? h('details', null,
      h('summary', { class: 'form' }, `Past worries (${ctx.s.worries.length})`),
      h('ul', { class: 'lines' }, [...ctx.s.worries].reverse().map((x) => h('li', null,
        tag(fmtShort(x.date)),
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => { close(); worryBuster(ctx, x); } }, x.worry.split('\n')[0] || '(empty)'))))) : null);
  close = openSheet('Worry Buster', body);
}

function mindStorm(ctx) {
  const st = { id: uid(), date: ctx.today, question: '', ideas: Array(20).fill(''), picked: null };
  let close = null;
  const counter = h('span', { class: 'count' }, '0/20');
  const list = h('ol', { class: 'rows' });
  const draw = () => {
    counter.textContent = `${st.ideas.filter((x) => x.trim()).length}/20`;
    list.querySelectorAll('.pickme').forEach((b, i) => b.classList.toggle('filled', st.picked === i));
  };
  fill(list, st.ideas.map((_, i) => h('li', { class: 'ans donerow' },
    bubble(String(i + 1), { button: true, cls: 'pickme', 'aria-label': `Act on idea ${i + 1}`, onclick: () => { st.picked = i; draw(); } }),
    h('input', { type: 'text', 'aria-label': `Idea ${i + 1}`, oninput: (e) => { st.ideas[i] = e.target.value; draw(); } }))));
  const body = h('div', { class: 'fields' },
    h('p', { class: 'lede' }, TIPS.mindstorm),
    field('Your goal or situation, as a question', h('input', { type: 'text', placeholder: 'What can I do to raise my GPA to 3.7 this semester?', oninput: (e) => { st.question = e.target.value; } })),
    h('div', { class: 'sec' }, h('h3', { class: 'form' }, 'Twenty answers'), counter),
    list,
    actions(
      h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const pick = st.picked != null ? st.ideas[st.picked].trim() : '';
        if (!pick) { toast('Fill in the bubble of one idea to act on now.'); return; }
        ctx.act.saveStorm(st);
        ctx.act.createItem({ title: pick, type: 'task', priority: 'A', notes: st.question });
        close();
        toast('Added as an A. Do it now.');
      } }, icon('play'), 'Act on the picked idea'),
      h('button', { class: 'btn quiet', type: 'button', onclick: () => { if (st.question || st.ideas.some(Boolean)) ctx.act.saveStorm(st); close(); } }, 'Save and close')));
  close = openSheet('20 Ideas', body);
}

function preGame(ctx) {
  const upcoming = ctx.s.items.filter((it) => (it.type === 'exam' || it.type === 'presentation') && isOpen(it, ctx.today) && it.date && diffDays(ctx.today, it.date) <= 21)
    .sort((a, b) => a.date.localeCompare(b.date));
  let close = null;
  const body = h('div', { class: 'fields' },
    h('p', { class: 'lede' }, 'Quick programming for an important one-off event. Top performers live it inside before they live it outside. Use it whenever the event comes to mind, and again right before it starts.'),
    field('For', upcoming.length
      ? h('select', null, upcoming.map((it) => h('option', null, `${it.title} · ${fmtShort(it.date)}`)), h('option', null, 'Something else'))
      : h('input', { type: 'text', placeholder: 'Calc midterm, internship interview…' })),
    field('1. Recall a past success', h('textarea', { rows: '2', placeholder: 'The last time an exam or a talk went really well. How did it feel?' }), 'Winners replay their best performances; losers replay their failures.'),
    field('2. See the perfect outcome', h('textarea', { rows: '2', placeholder: 'I read the first question and know exactly how to start. I finish with ten minutes to check.' })),
    field('3. Affirm it: personal, positive, present tense', h('input', { type: 'text', value: 'I am calm, prepared, and I know this material.' })),
    h('p', null, '4. Close your eyes and imagine how good it feels once it has already gone well.'),
    actions(h('button', { class: 'btn primary', type: 'button', onclick: () => { close(); toast(`Released. ${TIPS.release}`, { ms: 7000 }); } }, 'Release it')));
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
          h('p', null, formLabel('In WilList'), ' ', how),
          h('p', { class: 'mono muted' }, src)))))));
  openSheet('Principles', body);
}

function exportCalendar(ctx) {
  let includeSessions = true;
  const body = h('div', { class: 'fields' },
    h('p', null, 'A browser can only remind you while WilList is open. For reminders you can count on, put everything in your phone’s calendar: repeating classes, exams, presentations and deadlines with alarms, plus your study sessions and start days.'),
    h('label', { class: 'check' }, h('input', { type: 'checkbox', checked: true, onchange: (e) => { includeSessions = e.target.checked; } }), h('span', null, 'Include study sessions and start days')),
    h('ul', { class: 'lines' },
      h('li', null, formLabel('iPhone'), h('span', { class: 'grow' }, 'Download, then tap Add All.')),
      h('li', null, formLabel('Google'), h('span', { class: 'grow' }, 'On a computer: Settings → Import & export → Import.')),
      h('li', null, formLabel('Outlook'), h('span', { class: 'grow' }, 'Open the file, or Add calendar → Upload from file.'))),
    h('p', { class: 'small muted' }, 'It is a snapshot. Export again after big changes.'),
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
      if (!confirm(`Replace everything on this device with the backup (${data.items.length} items)?`)) return;
      ctx.store.replace(normalize(data));
      close();
      toast('Backup restored.', { action: { label: 'Undo', fn: () => ctx.store.undo() } });
    } catch (err) {
      toast(`Could not read that file: ${err.message}.`);
    }
  } });
  const body = h('div', { class: 'fields' },
    h('p', null, 'Your planner lives only in this browser on this device. There is no account and nothing is uploaded. Download a backup now and then, and use it to move to another device. Your coach key is never included.'),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => download(`willist-backup-${ctx.today}.json`, JSON.stringify(ctx.store.state, null, 2), 'application/json') }, 'Download backup'),
      h('button', { class: 'btn', type: 'button', onclick: () => file.click() }, 'Restore from file'), file),
    sec('Other'),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn', type: 'button', onclick: () => { close(); ctx.act.loadSample(); } }, 'Load a sample week'),
      h('button', { class: 'btn ink', type: 'button', onclick: () => {
        if (!confirm('Erase everything in WilList on this device?')) return;
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
    sec('Study plan'),
    h('div', { class: 'two' },
      num('perDayMin', 'Study budget a day (hours)', 'How much planned study fits in a normal day.', { min: '0.5', step: '0.5', scale: 60 }),
      num('sessionMin', 'Session length (minutes)', 'Short sessions with breaks help you remember.', { min: '15', step: '5' })),
    h('div', { class: 'two' },
      num('bufferDays', 'Finish deadlines early by (days)', null, { min: '0', step: '1' }),
      num('taskMin', 'A quick task takes (minutes)', 'Used to place tasks in My day.', { min: '5', step: '5' })),
    pace.length ? h('div', { class: 'f' }, formLabel('Your pace'),
      h('p', null, pace.map(([t, v]) => `${t} ${v}×`).join(' · '), ' ',
        h('button', { class: 'link', type: 'button', onclick: () => { st.calib = {}; toast('Pace reset. Save to apply.'); } }, 'Reset'))) : null,
    sec('My day'),
    h('div', { class: 'two' }, time('dayStart', 'Day starts'), time('dayEnd', 'Day ends')),
    time('planTime', 'Plan-tomorrow reminder'),
    field('Reward for finishing your A’s', h('input', { type: 'text', value: st.reward || '', placeholder: 'An episode of my show', oninput: (e) => { st.reward = e.target.value; } }), 'Small rewards along the way keep you going.'),
    sec('Other'),
    field('Dates typed like 3/4 mean', h('select', { onchange: (e) => { st.dateOrder = e.target.value || null; } },
      h('option', { value: '', selected: !st.dateOrder }, 'Follow my device'),
      h('option', { value: 'mdy', selected: st.dateOrder === 'mdy' }, 'Month/day (March 4)'),
      h('option', { value: 'dmy', selected: st.dateOrder === 'dmy' }, 'Day/month (3 April)'))),
    h('label', { class: 'check' }, h('input', { type: 'checkbox', checked: st.tips, onchange: (e) => { st.tips = e.target.checked; } }), h('span', null, 'Show coaching tips while typing')),
    h('label', { class: 'check' }, h('input', { type: 'checkbox', checked: st.notify, onchange: async (e) => {
      st.notify = e.target.checked;
      if (st.notify && 'Notification' in window && Notification.permission !== 'granted') {
        const p = await Notification.requestPermission();
        if (p !== 'granted') { st.notify = false; e.target.checked = false; toast('Notifications are blocked in this browser.'); }
      }
    } }), h('span', null, 'Remind me while WilList is open: classes, plan time, my A1')),
    actions(h('button', { type: 'submit', class: 'btn primary' }, 'Save'), h('button', { type: 'button', class: 'btn quiet', onclick: () => close() }, 'Cancel')));
  close = openSheet('Settings', body);
}

const TOOLS = [
  ['Bring in your semester', 'Calendar files from Canvas, Moodle, Blackboard or Google, or a pasted syllabus.', (ctx) => openImport(ctx)],
  ['Coach', 'Ask for help planning, or let the coach read a syllabus for you. Optional, uses your own Anthropic key.', (ctx) => openCoach(ctx)],
  ['Worry Buster', 'Stressed about an exam or a deadline? Four steps from worry to action.', worryBuster],
  ['20 Ideas', 'Stuck? Ask a question, write 20 answers, act on one.', mindStorm],
  ['Pre-game', 'Two minutes of mental rehearsal before an exam or presentation.', preGame],
  ['Principles', 'The Brian Tracy ideas behind WilList, and where each one lives.', () => principles()],
  ['Add to calendar', 'Export everything as .ics for reminders on your phone.', exportCalendar],
  ['Backup & data', 'Download, restore, sample data, erase.', backup],
  ['Settings', 'Study budget, session length, your day’s hours, reminders.', settings],
];

export function renderTools(ctx) {
  const open = ctx.s.items.filter((it) => !it.done).length;
  return h('div', { class: 'view tools' },
    h('header', { class: 'dayhead' },
      h('h1', { class: 'display page-title' }, 'Tools'),
      h('span', { class: 'mono muted' }, `${open} open · ${ctx.s.goals.length} goals · coach ${getKey() ? 'on' : 'off'}`)),
    h('ul', { class: 'index' }, TOOLS.map(([title, desc, fn]) => h('li', null,
      h('button', { type: 'button', onclick: () => fn(ctx) },
        h('b', null, title),
        icon('next'),
        h('span', { class: 'd' }, desc))))),
    h('p', { class: 'foot' }, 'Your planner stays on this device. ', h('button', { class: 'link', type: 'button', onclick: () => backup(ctx) }, 'Back it up.')));
}
