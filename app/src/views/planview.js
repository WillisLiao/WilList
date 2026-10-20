import { h, icon, bubble, tag, codeTag, sec, fmtMin, formLabel } from '../ui.js';
import { addDays, diffDays, fmtShort, fmtInDays, relDay } from '../dates.js';
import { dayRows, unsorted, scheduleOn, importantNotUrgent, isOpen, occursOn } from '../agenda.js';
import { weekStats, calibrations } from '../insights.js';
import { TIPS } from '../coach.js';
import { rowEl, trayEl, timetable, itemMeta, typeTag, emptyNote } from '../components.js';

function part(n, title, note, ...body) {
  return h('section', { class: 'part' },
    sec(`Part ${n} · ${title}`, { level: 'h3', note }),
    body);
}

function tonight(ctx) {
  const { s, today } = ctx;
  const tomorrow = addDays(today, 1);
  const tray = unsorted(s.items, today);
  const rows = dayRows(s.items, tomorrow, today);
  const events = scheduleOn(s.items, tomorrow);
  const soon = s.items.filter((it) => isOpen(it, today) && it.date && !it.recur && it.type !== 'event' &&
    diffDays(tomorrow, it.date) >= 0 && diffDays(tomorrow, it.date) <= 3)
    .sort((a, b) => a.date.localeCompare(b.date));
  const planned = s.meta.lastPlanned === today;
  const aRows = rows.filter((r) => r.priority === 'A');
  const ta = h('textarea', {
    id: 'dump', class: 'ruled', rows: '4', 'aria-label': 'Everything on your mind, one per line',
    placeholder: 'One thing per line…', value: ctx.ui.dump || '', oninput: (e) => { ctx.ui.dump = e.target.value; },
  });
  return [
    part(1, 'Empty your head', 'Think on paper',
      h('p', { class: 'lede' }, 'Homework, emails, errands, worries. One per line; dates work the same as the box at the top.'),
      ta,
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'button', onclick: () => {
        const lines = (ctx.ui.dump || '').split('\n').map((l) => l.trim()).filter(Boolean);
        if (!lines.length) return;
        ctx.ui.dump = '';
        ctx.act.addMany(lines);
      } }, icon('plus'), 'Add every line'))),
    part(2, 'Fill in a letter', null, tray.length ? trayEl(tray, ctx, { title: 'Unanswered' }) : emptyNote('Every item has a letter.')),
    part(3, `Tomorrow, ${fmtShort(tomorrow)}`, null,
      events.length ? timetable(events, ctx, { isToday: false }) : emptyNote('No classes or meetings tomorrow.'),
      soon.length ? h('ul', { class: 'lines' }, soon.map((it) => h('li', null,
        bubble(it.priority || '', { size: 'sm', filled: !!it.priority }),
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
        itemMeta(it, tomorrow)))) : null),
    part(4, 'Number your A’s', aRows.length > 5 ? TIPS.tooManyA(aRows.length) : 'Worst consequence first',
      rows.length
        ? h('ul', { class: 'rows' }, rows.map((r) => rowEl(r, { ...ctx, today: tomorrow, act: { ...ctx.act, move: (key, dir) => ctx.act.move(key, dir, rows) } }, { startable: false })))
        : emptyNote('Nothing lettered for tomorrow yet.')),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: ctx.act.lockPlan },
        bubble('', { size: 'sm', filled: planned }), planned ? 'Locked in. Sleep on it.' : 'Lock in tomorrow')),
    h('p', { class: 'foot' }, TIPS.planTonight),
  ];
}

function week(ctx) {
  const { s, today } = ctx;
  const stats = weekStats(s, today);
  const cal = calibrations(s.log, s.settings.calib);
  const end = addDays(today, 7);
  let classes = 0;
  for (let k = 0; k < 7; k++) classes += s.items.filter((it) => it.type === 'event' && occursOn(it, addDays(today, k))).length;
  const big = s.items.filter((it) => isOpen(it, today) && !it.recur && it.type !== 'event' && it.date &&
    diffDays(today, it.date) >= 0 && diffDays(it.date, end) > 0).sort((a, b) => a.date.localeCompare(b.date));
  const inu = importantNotUrgent(s.items, today);
  const stale = s.items.filter((it) => ['C', 'D', 'E'].includes(it.priority) && !it.done && it.type !== 'event' &&
    it.createdAt && diffDays(it.createdAt, today) >= 14);
  return [
    h('section', { class: 'part' },
      sec('The last 7 days'),
      h('div', { class: 'stats' },
        h('div', { class: 'stat' }, formLabel('Focused'), h('b', null, fmtMin(stats.focusMin))),
        h('div', { class: 'stat' }, formLabel('A’s done'), h('b', null, String(stats.aDone))),
        h('div', { class: 'stat' }, formLabel('Days A first'), h('b', null, `${stats.aFirstDays}/${stats.activeDays || 0}`)),
        h('div', { class: 'stat' }, formLabel('All done'), h('b', null, String(stats.done)))),
      cal.length ? h('div', { class: 'box callout' },
        h('span', { class: 'form box-label' }, 'Your real pace'),
        h('ul', { class: 'lines' }, cal.map((c) => h('li', null,
          h('span', { class: 'grow' }, `${c.label} takes you about ${c.ratio}× the plan (${c.n} focus sessions).`),
          h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.setCalib(c.type, c.ratio) }, `Plan ${c.ratio}× from now on`)))))
        : h('p', { class: 'foot' }, 'Use Start (focus mode) on study sessions. After three finished sessions of a kind, WilList shows how long they really take compared with the plan.')),
    h('section', { class: 'part' },
      sec('The next 7 days', { note: `${classes} classes & meetings` }),
      big.length ? h('ul', { class: 'lines' }, big.map((it) => h('li', null,
        bubble(it.priority || '', { size: 'sm', filled: !!it.priority }),
        h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
        typeTag(it.type), tag(`${relDay(it.date, today)}${it.time ? ` ${it.time}` : ''}`), codeTag(it.course)))) : emptyNote('Nothing dated this week.')),
    h('section', { class: 'part' },
      sec('Important, not urgent', { note: 'A’s 4–30 days out' }),
      h('p', { class: 'lede' }, 'Urgent things are seldom important; important things are seldom urgent. Get ahead on these now.'),
      inu.length ? h('ul', { class: 'lines' }, inu.map((it) => {
        const first = (it.sessions || []).find((x) => !x.done);
        const canPull = first && diffDays(today, first.date) > 0;
        return h('li', null,
          h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
          tag(fmtInDays(it.date, today)),
          canPull ? h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.pullForward(it.id) }, 'Do a session today') : null);
      })) : emptyNote('Nothing important is waiting quietly.')),
    h('section', { class: 'part' },
      sec('Goals', { count: s.goals.length }),
      s.goals.length ? h('ul', { class: 'lines' }, s.goals.map((g) => {
        const next = s.items.find((it) => it.goalId === g.id && !it.done);
        return h('li', null,
          h('span', { class: 'grow', role: 'button', tabindex: '0', onclick: () => ctx.editGoal(g.id) }, g.title),
          next ? tag(`Next: ${next.title}`) : h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.edit(null, { goalId: g.id, type: 'task', priority: 'A' }) }, 'Add next step'));
      })) : h('p', { class: 'empty' }, 'No written goals yet. ', h('button', { class: 'link', type: 'button', onclick: () => ctx.go('goals') }, 'Write your first one.'))),
    stale.length ? h('section', { class: 'part' },
      sec('Still worth it?', { count: stale.length }),
      h('p', { class: 'lede' }, `${TIPS.eliminate} These C, D and E items have waited two weeks or more.`),
      h('ul', { class: 'lines' }, stale.map((it) => h('li', null,
        bubble(it.priority, { size: 'sm' }), h('span', { class: 'grow' }, it.title),
        h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.keep(it.id) }, 'Keep'),
        h('button', { class: 'btn sm ink', type: 'button', onclick: () => ctx.act.remove(it.id) }, 'Drop'))))) : null,
    h('section', { class: 'box callout' },
      h('span', { class: 'form box-label' }, 'Balance'),
      h('p', null, 'When will you see the people you care about this week, sleep enough, and move? Personal goals are the reason for everything else.')),
  ];
}

export function renderPlan(ctx) {
  const tab = ctx.ui.planTab || 'tonight';
  const set = (t) => { ctx.ui.planTab = t; ctx.refresh(); };
  return h('div', { class: 'view plan' },
    h('header', { class: 'dayhead' },
      h('h1', { class: 'display page-title' }, 'Plan'),
      h('p', { class: 'lede' }, 'Failing to plan is planning to fail. Two minutes tonight, ten on Sunday.')),
    h('div', { class: 'tabs', role: 'tablist' },
      [['tonight', 'Plan tomorrow'], ['week', 'Weekly review']].map(([k, label]) => h('button', {
        type: 'button', role: 'tab', 'aria-selected': String(tab === k), onclick: () => set(k),
      }, bubble('', { filled: tab === k }), formLabel(label)))),
    tab === 'tonight' ? tonight(ctx) : week(ctx));
}
