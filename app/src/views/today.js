import { h, icon, fmtMin, courseChip } from '../ui.js';
import { fmtLong, addDays, nowHHMM } from '../dates.js';
import { dayRows, unsorted, scheduleOn, doneOn, missedSessions } from '../agenda.js';
import { TIPS } from '../coach.js';
import { rowEl, trayEl, scheduleEl, dueChip, typeIcon } from '../components.js';

function welcome(ctx) {
  return h('section', { class: 'card welcome' },
    h('h2', null, 'Get a grip on everything, in three moves'),
    h('ol', { class: 'steps' },
      h('li', null, h('b', null, 'Dump it all in.'), ' Type into the box above the way you’d say it: “Chem quiz thu”, “Essay due nov 3”, “Lab every wed 2-5pm”.'),
      h('li', null, h('b', null, 'Give each one a letter.'), ' A = serious consequences if you skip it … E = drop it.'),
      h('li', null, h('b', null, 'Do your A1 first.'), ' WilList works out when to start studying, and puts that on today’s list.')),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', onclick: ctx.act.loadSample }, 'Try it with a sample week'),
      h('button', { class: 'btn', onclick: () => document.getElementById('qa-input')?.focus() }, 'Start empty')));
}

function planPrompt(ctx) {
  const { s, today, now } = ctx;
  const evening = nowHHMM(now) >= s.settings.planTime;
  const plannedLast = s.meta.lastPlanned;
  if (evening && plannedLast !== today) {
    return h('button', { class: 'card prompt', onclick: () => ctx.go('plan') },
      icon('plan'), h('span', null, h('b', null, 'Plan tomorrow (2 min). '), TIPS.planTonight));
  }
  const yesterday = addDays(today, -1);
  if (!evening && now.getHours() >= 5 && plannedLast && plannedLast < yesterday) {
    return h('button', { class: 'card prompt', onclick: () => ctx.go('plan') },
      icon('plan'), h('span', null, h('b', null, 'Plan today. '), TIPS.planMorning));
  }
  return null;
}

function hero(r, ctx, aLeft) {
  const it = r.item;
  const sub = r.session ? `${r.session.label} · ${fmtMin(r.session.minutes)}` : (it.notes || '').split('\n')[0];
  return h('section', { class: `hero l-${it.priority}` },
    h('p', { class: 'hero-q' }, TIPS.a1),
    h('div', { class: 'hero-label' },
      h('span', { class: `badge l-${it.priority}` }, r.label),
      it.priority === 'A' ? 'Do this first' : aLeft === 0 ? 'No A’s left. Next up' : 'Next up'),
    h('h2', { class: 'hero-title', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, it.title),
    sub ? h('p', { class: 'hero-sub' }, sub) : null,
    h('div', { class: 'hero-meta' }, typeIcon(it.type), dueChip(it, ctx.today), courseChip(it.course),
      r.overdue ? h('span', { class: 'chip overdue' }, 'Missed earlier') : null),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary big', onclick: () => ctx.focus(r) }, icon('play'), 'Start now'),
      h('button', { class: 'btn big', onclick: () => ctx.act.complete(r) }, icon('check'), 'Done')));
}

function group(title, rows, ctx, opts = {}) {
  if (!rows.length) return null;
  return h('section', { class: `group${opts.cls ? ` ${opts.cls}` : ''}` },
    h('div', { class: 'group-head' }, h('h3', null, title), opts.note ? h('p', { class: 'group-note' }, opts.note) : null),
    h('ul', { class: 'rows' }, rows.map((r) => rowEl(r, ctx, opts))));
}

export function renderToday(ctx) {
  const { s, today } = ctx;
  const rows = dayRows(s.items, today);
  const tray = unsorted(s.items, today);
  const events = scheduleOn(s.items, today);
  const missed = missedSessions(s.items, today);
  const done = doneOn(s.items, today);
  const byL = (L) => rows.filter((r) => r.priority === L);
  const [A, B, C, D, E] = ['A', 'B', 'C', 'D', 'E'].map(byL);
  const top = A[0] || B[0] || null;
  const rest = (list) => list.filter((r) => r !== top);
  const nothing = !s.items.length;

  const aDoneToday = done.filter((d) => d.item.priority === 'A').length;
  const reward = s.settings.reward?.trim();
  let rewardEl = null;
  if (reward && (A.length || aDoneToday)) {
    rewardEl = A.length
      ? h('p', { class: 'reward' }, icon('spark'), `Finish today’s A’s, then: ${reward}`)
      : h('p', { class: 'reward earned' }, icon('spark'), `All A’s done. You earned it: ${reward}`);
  }

  return h('div', { class: 'view today' },
    h('header', { class: 'view-head' },
      h('h1', null, fmtLong(today)),
      s.mdp ? h('button', { class: 'mdp', onclick: () => ctx.go('goals') }, icon('target'), h('span', null, s.mdp)) : null),
    nothing && !s.meta.onboarded ? welcome(ctx) : null,
    planPrompt(ctx),
    missed.length ? h('section', { class: 'card warn' },
      h('p', null, icon('alert'), h('b', null, `${missed.reduce((a, m) => a + m.count, 0)} missed study session(s). `), TIPS.missed),
      h('button', { class: 'btn', onclick: ctx.act.replanMissed }, 'Re-plan from today')) : null,
    trayEl(tray, ctx),
    top ? hero(top, ctx, A.length) : (!nothing && !tray.length ? h('section', { class: 'card calm' },
      h('h2', null, 'Nothing left on today’s list.'),
      h('p', null, 'Check Radar for what’s coming, or work ahead on an A.')) : null),
    rewardEl,
    scheduleEl(events, ctx, { title: 'Today’s schedule' }),
    group('A · Must do', rest(A), ctx, { note: A.length > 5 ? TIPS.tooManyA(A.length) : null }),
    group('B · Should do', rest(B), ctx, { muted: A.length > 0, note: A.length ? TIPS.bBeforeA : null }),
    group('C · Nice to do', C, ctx, { muted: A.length + B.length > 0 }),
    group('D · Delegated', D, ctx, { startable: false, note: TIPS.delegate }),
    E.length ? h('details', { class: 'group elim' },
      h('summary', null, `E · Eliminate? (${E.length})`),
      h('p', { class: 'group-note' }, TIPS.eliminate),
      h('ul', { class: 'rows' }, E.map((r) => h('li', { class: 'row l-E' },
        h('div', { class: 'row-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) }, h('span', { class: 'row-text' }, r.item.title)),
        h('button', { class: 'btn sm', onclick: () => ctx.act.remove(r.item.id) }, icon('trash'), 'Let it go'))))) : null,
    done.length ? h('details', { class: 'group done' },
      h('summary', null, `Done today · ${done.length}`),
      h('ul', { class: 'rows' }, done.map((d) => h('li', { class: 'row is-done' },
        h('span', { class: 'check on' }, icon('check')),
        h('span', { class: 'row-text' }, d.item.title, d.session ? h('span', { class: 'row-sub inline' }, ` · ${d.session.label}`) : null))))) : null,
    !nothing ? h('p', { class: 'foot-tip' }, TIPS.focus) : null,
  );
}

