import { h, icon, tag, sec, openSheet, field, choice, toast, formLabel } from '../ui.js';
import { fmtInDays, fmtShort } from '../dates.js';
import { TIPS } from '../coach.js';
import { uid } from '../store.js';

export const AREAS = [
  ['academic', 'School & career', 'The what: grades, skills, internships, the career you want.'],
  ['personal', 'People & personal life', 'The why: family, friends, relationships, fun.'],
  ['self', 'Self-improvement & health', 'The means: sleep, fitness, reading, habits.'],
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
  const areaBox = h('div');
  const horizonBox = h('div');
  const drawChoices = () => {
    areaBox.replaceChildren(choice(AREAS.map(([v, l]) => [v, l]), g.area, (v) => { g.area = v; drawChoices(); }, { ariaLabel: 'Area' }));
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
    text('title', 'Goal', 'Write it as if it is already true: “I earn an A in Organic Chemistry.”', 0, 'I …'),
    h('div', { class: 'f' }, formLabel('Area'), areaBox),
    h('div', { class: 'f' }, formLabel('Horizon'), horizonBox),
    field('Deadline', h('input', { type: 'date', value: g.deadline || '', onchange: (e) => { g.deadline = e.target.value; } }), 'A goal without a deadline is just a wish.'),
    text('why', 'Why you want it', 'List every reason. Reasons are the fuel in the furnace of achievement.', 3),
    text('rock', 'The rock', 'The one obstacle that matters most. Swarm all over it.', 2),
    text('knowledge', 'What you need to learn', 'The number one skill or piece of knowledge.', 2),
    text('people', 'Whose help you need', 'Professor, TA, advisor, teammates, family. Ask your way to success.', 2),
    text('reward', 'Reward when you get there', null, 0, 'e.g. a weekend trip'),
    h('p', { class: 'small muted' }, TIPS.goal5050),
    h('div', { class: 'btn-row sticky-actions' },
      h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add goal'),
      existing ? h('button', { type: 'button', class: 'btn ink', onclick: () => { close(); ctx.act.removeGoal(g.id); } }, 'Delete') : null,
      h('button', { type: 'button', class: 'btn quiet', onclick: () => close() }, 'Cancel')));
  close = openSheet(existing ? 'Edit goal' : 'New goal', form);
  return close;
}

function goalRow(g, ctx) {
  const steps = ctx.s.items.filter((it) => it.goalId === g.id);
  const open = steps.filter((it) => !it.done);
  const done = steps.length - open.length;
  return h('li', { class: 'goal' },
    h('h4', { role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id) }, g.title),
    h('div', { class: 'meta' },
      tag((HORIZONS.find(([v]) => v === g.horizon) || [0, ''])[1]),
      g.deadline ? tag(`${fmtShort(g.deadline)} · ${fmtInDays(g.deadline, ctx.today)}`) : tag('No deadline', 'soon'),
      done ? tag(`${done} step${done > 1 ? 's' : ''} done`) : null),
    g.why ? h('p', null, g.why.split('\n')[0]) : null,
    g.rock ? h('p', null, formLabel('Rock'), ' ', g.rock) : null,
    h('div', { class: 'btn-row' },
      open.length ? h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.edit(open[0].id) }, `Next: ${open[0].title}`)
        : h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, icon('plus'), 'Add the next step')));
}

export function renderGoals(ctx) {
  const { s } = ctx;
  return h('div', { class: 'view goals' },
    h('header', { class: 'dayhead' },
      h('h1', { class: 'display page-title' }, 'Goals'),
      h('p', { class: 'lede' }, 'Success is goals; all else is commentary. About 3% of people write theirs down.')),
    h('section', { class: 'box' },
      h('label', { class: 'form box-label', for: 'mdp' }, 'Major definite purpose'),
      h('div', { class: 'fields' },
        h('input', { id: 'mdp', type: 'text', value: s.mdp || '', placeholder: 'I finish this semester with a 3.7 GPA',
          onchange: (e) => ctx.act.setMdp(e.target.value.trim()) }),
        h('p', { class: 'small muted' }, 'The one measurable goal that matters more than any other. If someone woke you at 3am, you could say it. It sits at the top of Today.'))),
    s.goals.length > 15 ? h('p', { class: 'lede' }, TIPS.goalsMany) : null,
    AREAS.map(([key, label, hint]) => {
      const list = s.goals.filter((g) => g.area === key);
      return h('section', { class: 'part' },
        sec(label, { count: list.length, note: hint }),
        list.length ? h('ul', { class: 'rows' }, list.map((g) => goalRow(g, ctx))) : null,
        h('div', { class: 'btn-row' }, h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.editGoal(null, { area: key }) }, icon('plus'), list.length ? 'Add another' : 'Add a goal')));
    }),
    s.goals.length && AREAS.some(([k]) => !s.goals.some((g) => g.area === k)) ? h('p', { class: 'foot' }, TIPS.goalsBalance) : null,
    h('details', { class: 'part', open: !s.goals.length },
      h('summary', { class: 'form' }, 'Not sure what your goals are? Seven questions'),
      h('p', { class: 'lede' }, 'Write the first thing that comes to mind, about 30 seconds each. Repeat it every month until the answers come easily.'),
      h('div', { class: 'fields' }, QUESTIONS.map((q, i) => h('label', { class: 'f' },
        h('span', null, h('span', { class: 'mono' }, `${i + 1}. `), q),
        h('textarea', { class: 'ruled', rows: '2', value: s.exercise?.[i] || '', onchange: (e) => ctx.act.setExercise(i, e.target.value) }))))),
    h('p', { class: 'foot' }, TIPS.confidential));
}

