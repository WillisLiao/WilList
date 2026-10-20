import { h, icon, openSheet, field, choice, toast, titleRow, panel } from '../ui.js';
import { fmtInDays, fmtShort, addDays } from '../dates.js';
import { uid } from '../store.js';
import { a1Streak } from '../insights.js';

export const AREAS = [
  ['academic', 'School & career'],
  ['personal', 'People'],
  ['self', 'Health & self'],
];
const AREA_ICON = { academic: 'school', personal: 'people', self: 'self' };
const HORIZONS = [['90d', '90 days'], ['1y', 'This year'], ['3y', '2–3 years']];

// The seven questions from the goal-setting exercise (S15).
const QUESTIONS = [
  'Your five most important values?',
  'Your three most important goals right now?',
  'What would you do with six months to live?',
  'What would you do with a million dollars?',
  'What have you always wanted to do, but been afraid to try?',
  'What makes you feel most alive and important?',
  'What would you dare to dream if you knew you couldn’t fail?',
];

export function openGoalSheet(ctx, id, prefill = {}) {
  const s = ctx.store.state;
  const existing = id ? s.goals.find((g) => g.id === id) : null;
  const g = existing ? { ...existing } : { id: uid(), title: '', area: 'academic', horizon: '90d', deadline: '', why: '', rock: '', knowledge: '', people: '', reward: '', createdAt: ctx.today, ...prefill };
  const text = (k, label, rows = 0, ph = '') => field(label,
    rows ? h('textarea', { rows: String(rows), value: g[k] || '', placeholder: ph, oninput: (e) => { g[k] = e.target.value; } })
      : h('input', { type: 'text', value: g[k] || '', placeholder: ph, oninput: (e) => { g[k] = e.target.value; } }));
  let close = null;
  const areaBox = h('div');
  const horizonBox = h('div');
  const drawChoices = () => {
    areaBox.replaceChildren(choice(AREAS, g.area, (v) => { g.area = v; drawChoices(); }, { ariaLabel: 'Area' }));
    horizonBox.replaceChildren(choice(HORIZONS, g.horizon, (v) => { g.horizon = v; drawChoices(); }, { ariaLabel: 'Horizon' }));
  };
  drawChoices();
  const form = h('form', { class: 'fields', onsubmit: (e) => {
    e.preventDefault();
    if (!g.title.trim()) { toast('Write the goal first.'); return; }
    g.title = g.title.trim();
    ctx.act.saveGoal(g);
    close();
  } },
    text('title', 'Goal', 0, 'I earn an A in Organic Chem'),
    field('By when', h('input', { type: 'date', value: g.deadline || '', onchange: (e) => { g.deadline = e.target.value; } })),
    text('why', 'Why', 2),
    h('details', { class: 'more-fields' },
      h('summary', null, 'More'),
      h('div', { class: 'fields' },
        h('div', { class: 'f' }, h('span', { class: 'lbl' }, 'Area'), areaBox),
        h('div', { class: 'f' }, h('span', { class: 'lbl' }, 'Horizon'), horizonBox),
        text('rock', 'Biggest obstacle', 2),
        text('knowledge', 'What you need to learn', 2),
        text('people', 'Who can help', 2),
        text('reward', 'Reward'))),
    h('div', { class: 'btn-row sticky-actions' },
      h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add goal'),
      existing ? h('button', { type: 'button', class: 'btn danger', onclick: () => { close(); ctx.act.removeGoal(g.id); } }, 'Delete') : null));
  close = openSheet(existing ? 'Goal' : 'New goal', form);
  return close;
}

function openQuestions(ctx) {
  openSheet('7 questions', h('div', { class: 'fields' },
    h('p', { class: 'muted' }, 'First answer that comes to mind. 30 seconds each.'),
    QUESTIONS.map((q, i) => h('label', { class: 'f' },
      h('span', { class: 'lbl' }, `${i + 1}. ${q}`),
      h('textarea', { rows: '2', value: ctx.s.exercise?.[i] || '', onchange: (e) => ctx.act.setExercise(i, e.target.value) })))));
}

function goalRow(g, ctx) {
  const next = ctx.s.items.find((it) => it.goalId === g.id && !it.done);
  return h('li', { class: 'goal' },
    icon(AREA_ICON[g.area] || 'goals'),
    h('div', { class: 'min0' },
      h('h3', { role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.editGoal(g.id); } }, g.title),
      next ? h('button', { class: 'linkish strong', type: 'button', onclick: () => ctx.edit(next.id) }, icon('arrow'), next.title)
        : h('button', { class: 'linkish strong', type: 'button', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, icon('plus'), 'Next step')),
    g.deadline ? h('span', { class: 'when num' }, fmtShort(g.deadline), h('small', null, fmtInDays(g.deadline, ctx.today))) : h('span', { class: 'when dash' }, '–'));
}

// Tracy: a habit takes about 21 days. One square per day: filled when the first thing
// you finished that day was an A.
function habit(ctx) {
  const fd = ctx.s.meta.firstDone || {};
  const days = Array.from({ length: 21 }, (_, i) => addDays(ctx.today, i - 20));
  const hits = days.filter((d) => fd[d] === 'A').length;
  return h('div', { class: 'habit' },
    h('div', { class: 'habit-grid', role: 'img', 'aria-label': `The first thing done was an A on ${hits} of the last 21 days` },
      days.map((d) => h('i', { class: fd[d] === 'A' ? 'a' : fd[d] ? 'other' : d === ctx.today ? 'today' : null }))),
    h('div', { class: 'habit-figs' },
      h('p', null, h('b', { class: 'num' }, String(hits)), h('span', null, 'of 21 days started with an A')),
      h('p', null, h('b', { class: 'num' }, String(a1Streak(fd, ctx.today))), h('span', null, 'days in a row now'))));
}

export function renderGoals(ctx) {
  const { s } = ctx;
  const editing = !s.mdp || ctx.ui.editMdp;
  const input = h('input', { id: 'mdp', type: 'text', value: s.mdp || '', placeholder: 'I finish this semester with a 3.7 GPA', 'aria-label': 'Main goal',
    onchange: (e) => { ctx.ui.editMdp = false; ctx.act.setMdp(e.target.value.trim()); },
    onkeydown: (e) => { if (e.key === 'Escape') { ctx.ui.editMdp = false; ctx.refresh(); } } });
  if (ctx.ui.editMdp) setTimeout(() => input.focus(), 30);
  const dated = s.goals.filter((g) => g.deadline).sort((a, b) => a.deadline.localeCompare(b.deadline));
  return h('div', { class: 'view goals' },
    titleRow(h('h1', null, 'Goals'),
      dated.length ? `Next: ${dated[0].title}, ${fmtInDays(dated[0].deadline, ctx.today)}.` : 'Written down, with a date and a next step.',
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.editGoal(null) }, icon('plus'), 'Add goal')),
    h('div', { class: 'grid' },
      panel('The one that matters most', { cls: 'span-12 mdp', id: 'mdp-h' },
        editing ? input : h('button', { class: 'mdp-text', type: 'button', onclick: () => { ctx.ui.editMdp = true; ctx.refresh(); } }, s.mdp)),
      panel('Your goals', { cls: 'span-8', id: 'goals-h', aside: h('button', { class: 'card-link', type: 'button', onclick: () => openQuestions(ctx) }, 'Not sure? 7 questions') },
        s.goals.length ? h('ul', { class: 'goal-list' }, s.goals.map((g) => goalRow(g, ctx)))
          : h('p', { class: 'empty' }, 'No goals yet. Add one with a date.')),
      panel('A1 first', { cls: 'span-4 stretch', id: 'habit-h' }, habit(ctx))));
}
