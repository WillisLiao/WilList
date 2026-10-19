import { h, icon, openSheet, field, toast } from '../ui.js';
import { fmtInDays, fmtShort } from '../dates.js';
import { TIPS } from '../coach.js';
import { uid } from '../store.js';

export const AREAS = [
  ['academic', 'School & career', 'The “what”: grades, skills, internships, the career you want.'],
  ['personal', 'People & personal life', 'The “why”: family, friends, relationships, fun.'],
  ['self', 'Self-improvement & health', 'The “means”: sleep, fitness, reading, habits.'],
];
const HORIZONS = [['90d', '90 days'], ['1y', 'This year'], ['3y', '2–3 years']];

// The seven questions from the goal-setting exercise (S15).
const QUESTIONS = [
  'What are your five most important values, in order?',
  'What are your three most important goals in life right now?',
  'What would you do if you had only six months to live?',
  'What would you do if you won a million dollars tomorrow?',
  'What have you always wanted to do, but been afraid to attempt?',
  'What activities give you your greatest feeling of importance and happiness?',
  'What one great thing would you dare to dream if you knew you could not fail?',
];

export function openGoalSheet(ctx, id, prefill = {}) {
  const s = ctx.store.state;
  const existing = id ? s.goals.find((g) => g.id === id) : null;
  const g = existing ? { ...existing } : { id: uid(), title: '', area: 'academic', horizon: '90d', deadline: '', why: '', rock: '', knowledge: '', people: '', reward: '', createdAt: ctx.today, ...prefill };
  const text = (k, label, hint, rows = 0, ph = '') => field(label,
    rows ? h('textarea', { rows: String(rows), value: g[k] || '', placeholder: ph, oninput: (e) => { g[k] = e.target.value; } })
      : h('input', { type: 'text', value: g[k] || '', placeholder: ph, oninput: (e) => { g[k] = e.target.value; } }), hint);
  let close = null;
  const form = h('form', { class: 'editor', onsubmit: (e) => {
    e.preventDefault();
    if (!g.title.trim()) { toast('Write the goal first.'); return; }
    g.title = g.title.trim();
    ctx.act.saveGoal(g);
    close();
  } },
    text('title', 'Goal', 'Write it as if it is already true, in the present tense: “I earn an A in Organic Chemistry.”', 0, 'I …'),
    h('div', { class: 'two' },
      field('Area', h('select', { onchange: (e) => { g.area = e.target.value; } }, AREAS.map(([v, l]) => h('option', { value: v, selected: v === g.area }, l)))),
      field('Horizon', h('select', { onchange: (e) => { g.horizon = e.target.value; } }, HORIZONS.map(([v, l]) => h('option', { value: v, selected: v === g.horizon }, l))))),
    field('Deadline', h('input', { type: 'date', value: g.deadline || '', onchange: (e) => { g.deadline = e.target.value; } }), 'A goal without a deadline is just a wish.'),
    text('why', 'Why do you want it?', 'List every reason. Reasons are the fuel in the furnace of achievement.', 3),
    text('rock', 'The rock: the one biggest obstacle', 'Find the single obstacle that matters most and swarm all over it.', 2),
    text('knowledge', 'Knowledge or skill you need', 'What is the number one thing you need to learn?', 2),
    text('people', 'Whose help do you need?', 'Professor, TA, advisor, teammates, family. Ask your way to success.', 2),
    text('reward', 'Reward when you get there', null, 0, 'e.g. weekend trip'),
    h('p', { class: 'field-hint' }, TIPS.goal5050),
    h('div', { class: 'btn-row sticky' },
      h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add goal'),
      existing ? h('button', { type: 'button', class: 'btn danger', onclick: () => { close(); ctx.act.removeGoal(g.id); } }, icon('trash'), 'Delete') : null,
      h('button', { type: 'button', class: 'btn ghost', onclick: () => close() }, 'Cancel')));
  close = openSheet(existing ? 'Edit goal' : 'New goal', form);
  return close;
}

function goalCard(g, ctx) {
  const steps = ctx.s.items.filter((it) => it.goalId === g.id);
  const open = steps.filter((it) => !it.done);
  const done = steps.length - open.length;
  return h('li', { class: 'goal' },
    h('div', { class: 'goal-main', role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id) },
      h('h4', null, g.title),
      h('div', { class: 'row-sub' },
        h('span', { class: 'chip' }, (HORIZONS.find(([v]) => v === g.horizon) || [0, ''])[1]),
        g.deadline ? h('span', { class: 'chip' }, `${fmtShort(g.deadline)} · ${fmtInDays(g.deadline, ctx.today)}`) : h('span', { class: 'chip soon' }, 'No deadline'),
        done ? h('span', { class: 'chip ok' }, `${done} step${done > 1 ? 's' : ''} done`) : null),
      g.why ? h('p', { class: 'goal-why' }, g.why.split('\n')[0]) : null,
      g.rock ? h('p', { class: 'goal-rock' }, h('b', null, 'Rock: '), g.rock) : null),
    h('div', { class: 'goal-next' },
      open.length ? h('button', { class: 'chip-btn', onclick: () => ctx.edit(open[0].id) }, icon('play'), `Next: ${open[0].title}`)
        : h('button', { class: 'chip-btn', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, icon('plus'), 'Add the next step')));
}

export function renderGoals(ctx) {
  const { s } = ctx;
  const mdpInput = h('input', { type: 'text', value: s.mdp || '', placeholder: 'e.g. I finish this semester with a 3.7 GPA',
    'aria-label': 'Major definite purpose', onchange: (e) => ctx.act.setMdp(e.target.value.trim()) });
  return h('div', { class: 'view goals' },
    h('header', { class: 'view-head' },
      h('h1', null, 'Goals'),
      h('p', { class: 'lede' }, 'Success is goals; all else is commentary. Only about 3% of people write theirs down.')),
    h('section', { class: 'card mdp-card' },
      h('div', { class: 'card-head' }, icon('target'), h('h3', null, 'Major definite purpose')),
      h('p', { class: 'group-note' }, 'The one measurable goal that matters more than any other right now. If someone woke you at 3am, you could say it. It shows at the top of Today.'),
      mdpInput),
    s.goals.length > 15 ? h('p', { class: 'lede warn-text' }, TIPS.goalsMany) : null,
    AREAS.map(([key, label, hint]) => {
      const list = s.goals.filter((g) => g.area === key);
      return h('section', { class: 'group' },
        h('div', { class: 'group-head' }, h('h3', null, label), h('p', { class: 'group-note' }, hint)),
        list.length ? h('ul', { class: 'goal-list' }, list.map((g) => goalCard(g, ctx))) : null,
        h('button', { class: 'btn ghost add', onclick: () => ctx.editGoal(null, { area: key }) }, icon('plus'), list.length ? 'Add another' : 'Add a goal'));
    }),
    s.goals.length && AREAS.some(([k]) => !s.goals.some((g) => g.area === k)) ? h('p', { class: 'foot-tip' }, TIPS.goalsBalance) : null,
    h('details', { class: 'card exercise', open: !s.goals.length },
      h('summary', null, h('b', null, 'Not sure what your goals are?'), ' Answer seven quick questions'),
      h('p', { class: 'group-note' }, 'Write the first thing that comes to mind, about 30 seconds each. Repeat it every month until the answers come easily.'),
      QUESTIONS.map((q, i) => field(`${i + 1}. ${q}`, h('textarea', { rows: '2', value: s.exercise?.[i] || '',
        onchange: (e) => ctx.act.setExercise(i, e.target.value) })))),
    h('p', { class: 'foot-tip' }, TIPS.confidential));
}
