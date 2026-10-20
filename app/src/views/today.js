import { h, icon, rank, tag, sec, fmtMin, band, hand, penArrow, segmented, progress } from '../ui.js';
import { addDays, nowHHMM, minToTime, timeToMin, weekday } from '../dates.js';
import { dayRows, unsorted, scheduleOn, doneOn, missedSessions } from '../agenda.js';
import { planDay } from '../timeline.js';
import { a1Streak } from '../insights.js';
import { TIPS } from '../coach.js';
import { rowEl, sortBanner, timetable, itemMeta, emptyNote, completeRow } from '../components.js';

const WEEKDAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function streak(s, today) {
  const n = a1Streak(s.meta.firstDone, today);
  const fd = s.meta.firstDone || {};
  const week = [];
  for (let k = 6; k >= 0; k--) week.push(h('i', { class: fd[addDays(today, -k)] === 'A' ? 'on' : null }));
  return h('span', { class: 'streak', title: 'Days in a row where the first thing you finished was an A. A habit takes about 21 days.', 'aria-label': `A1-first streak: ${n} day${n === 1 ? '' : 's'}. Goal: 21.` },
    h('span', { class: 'dots', 'aria-hidden': 'true' }, week),
    h('span', { class: 'n' }, n ? `${n}-day A1 streak` : 'A1 first: start a streak'));
}

function heroCard(r, ctx, aLeft) {
  const it = r.item;
  const sub = r.session ? `${r.session.label} · ${fmtMin(r.session.minutes)}` : (it.notes || '').split('\n')[0];
  const sessions = it.sessions || [];
  const done = sessions.filter((x) => x.done).length;
  const card = h('section', { class: 'hero qa1', 'aria-label': 'Your one thing' },
    h('div', { class: 'eyebrow' }, rank(r.label, r.priority), itemMeta(it, ctx.today, r.overdue ? [tag('missed earlier', 'soon')] : [])),
    h('h2', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
      h('span', { class: r.priority === 'A' ? 'hl' : null }, it.title)),
    sub ? h('p', { class: 'what' }, sub) : null,
    sessions.length > 1 ? progress(done, sessions.length, { label: `${done} of ${sessions.length} sessions` }) : null,
    it.priority !== 'A' && !aLeft ? h('p', { class: 'small muted' }, 'No A’s left today. This is your best next move.') : null,
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.focus(r) }, icon('play'), r.session ? `Start · ${fmtMin(r.session.minutes)}` : 'Start now'),
      h('button', { class: 'btn', type: 'button', onclick: () => completeRow(card, r, ctx) }, icon('check'), 'Done')));
  return card;
}

function welcome(ctx) {
  return h('section', { class: 'hero welcome' },
    h('h2', null, 'Get it all out of your head.'),
    h('ol', null,
      h('li', null, h('div', null, h('b', null, 'Write everything down'), h('span', null, 'Type it the way you’d say it: “Chem quiz thu”, “Essay due nov 3 25%”, “Lab every wed 2-5pm”. Or bring in your whole semester at once.'))),
      h('li', null, h('div', null, h('b', null, 'Give each one a letter'), h('span', null, 'A if skipping it has serious consequences, down to E if it doesn’t matter.'))),
      h('li', null, h('div', null, h('b', null, 'Do your A1 first'), h('span', null, 'WilList works out when to start studying for everything else.')))),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.openImport() }, icon('import'), 'Bring in my semester'),
      h('button', { class: 'btn', type: 'button', onclick: ctx.act.loadSample }, 'Try a sample week')));
}

function clearCard(ctx, empty) {
  return h('section', { class: 'hero' },
    h('div', { class: 'margin-note' }, hand(empty ? 'a clean sheet' : 'all clear. nice.')),
    h('h2', null, empty ? 'Nothing written down yet.' : 'Nothing left on today’s list.'),
    h('p', { class: 'what' }, empty ? 'Tap Add and write the first thing on your mind.' : 'See what’s coming, or get ahead on an A while it’s quiet.'),
    h('div', { class: 'btn-row' },
      empty ? h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.quickAdd() }, icon('plus'), 'Write something down')
        : h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.go('radar') }, icon('radar'), 'See what’s coming')));
}

function nextUp(ctx, events, A) {
  const { s, now } = ctx;
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const next = events.find((ev) => ev.time && timeToMin(ev.time) + (ev.durationMin || 60) > nowMin);
  const chips = [];
  if (next) {
    const start = timeToMin(next.time);
    const inMin = start - nowMin;
    const when = inMin <= 0 ? 'now' : inMin < 60 ? `in ${inMin} min` : next.time;
    chips.push(h('button', { class: 'chip', type: 'button', onclick: () => ctx.edit(next.id) }, icon('clock'), `${inMin <= 0 ? 'Now' : 'Next'}: ${next.title} · ${when}`));
  }
  const reward = s.settings.reward?.trim();
  if (reward && A.length) chips.push(h('span', { class: 'chip' }, `After the A’s: ${reward}`));
  return chips.length ? h('div', { class: 'next-up' }, chips) : null;
}

function banners(ctx, missed) {
  const { s, today, now } = ctx;
  const out = [];
  const evening = nowHHMM(now) >= s.settings.planTime;
  const last = s.meta.lastPlanned;
  let plan = null;
  if (evening && last !== today) plan = ['Plan tomorrow tonight', TIPS.planTonight];
  else if (!evening && now.getHours() >= 5 && last && last < addDays(today, -1)) plan = ['Plan today: two minutes', TIPS.planMorning];
  if (plan) {
    out.push(h('button', { class: 'banner night', type: 'button', onclick: () => ctx.go('plan') },
      h('span', { class: 'bi' }, icon('plan')), h('span', null, h('b', null, plan[0]), h('span', null, plan[1])), icon('next')));
  }
  if (missed.length) {
    const n = missed.reduce((a, m) => a + m.count, 0);
    out.push(h('div', { class: 'banner alert' },
      h('span', { class: 'bi' }, icon('alert')),
      h('span', null, h('b', null, `${n} study session${n > 1 ? 's' : ''} slipped`), h('span', null, `${missed.map((m) => m.item.title).join(', ')}. ${TIPS.missed}`)),
      h('button', { class: 'btn sm', type: 'button', onclick: ctx.act.replanMissed }, 'Re-plan')));
  }
  return out;
}

function group(title, rows, ctx, opts = {}) {
  if (!rows.length) return null;
  return h('section', { class: 'part' },
    sec(title, { count: rows.length, note: opts.note }),
    h('ul', { class: 'rows card' }, rows.map((r) => rowEl(r, ctx, opts))));
}

function dayView(ctx, rows, events) {
  const { s, now } = ctx;
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const plan = planDay({ events, rows, dayStart: s.settings.dayStart, dayEnd: s.settings.dayEnd, nowMin, taskMin: s.settings.taskMin });
  const items = [];
  let nowPlaced = false;
  const nowLine = () => h('li', { class: 'nowline' }, h('span', { class: 't' }, minToTime(nowMin)), h('span', { class: 'spine' }, h('i')), h('div', { class: 'body' }), h('span'));
  for (const slot of plan.slots) {
    if (!nowPlaced && slot.start >= nowMin) { items.push(nowLine()); nowPlaced = true; }
    if (slot.kind === 'event') {
      const ev = slot.event;
      items.push(h('li', { class: `fixed${slot.end <= nowMin ? ' past' : ''}` },
        h('span', { class: 't' }, minToTime(slot.start)),
        h('span', { class: 'spine' }, h('i')),
        h('div', { class: 'body', role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
          h('b', null, ev.type === 'exam' ? `Exam: ${ev.title}` : ev.type === 'presentation' ? `Presenting: ${ev.title}` : ev.title),
          h('div', { class: 'meta' }, h('span', null, `${minToTime(slot.start)}–${minToTime(slot.end)}`), ev.course ? h('span', { class: 'code' }, ev.course) : null)),
        h('span', { class: 'end' })));
    } else {
      const r = slot.row;
      items.push(h('li', { class: r.priority === 'A' ? 'is-a' : null },
        h('span', { class: 't' }, minToTime(slot.start)),
        h('span', { class: 'spine' }, h('i')),
        h('div', { class: 'body', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) },
          h('span', null, rank(r.label, r.priority), h('b', null, r.item.title), slot.part ? ` (part ${slot.part})` : ''),
          h('div', { class: 'meta' }, h('span', null, `${fmtMin(slot.end - slot.start)} · until ${minToTime(slot.end)}`), r.session ? h('span', null, r.session.label) : null)),
        h('span', { class: 'end' }, h('button', { class: 'go', type: 'button', 'aria-label': `Start “${r.item.title}”`, onclick: () => ctx.focus(r) }, icon('play')))));
    }
  }
  if (!nowPlaced) items.push(nowLine());
  return [
    h('section', { class: 'part' },
      sec('Your day', { note: `${s.settings.dayStart}–${s.settings.dayEnd} · A’s first, breaks between` }),
      items.length > 1 ? h('ul', { class: 'timeline' }, items) : emptyNote('Nothing scheduled and nothing on the list.')),
    plan.unplaced.length ? h('div', { class: 'card pad' },
      sec('Doesn’t fit today', { level: 'h3', count: plan.unplaced.length }),
      h('ul', { class: 'lines' }, plan.unplaced.map((u) => h('li', null, rank(u.row.label, u.row.priority), h('span', { class: 'grow' }, u.row.item.title), h('span', { class: 'muted small' }, fmtMin(u.minutes))))),
      h('p', { class: 'small muted' }, 'Move something to tomorrow, delegate it (D), or ask for help early. Balance on Radar re-spreads study sessions.')) : null,
    h('p', { class: 'foot' }, `Free time left after this plan: ${fmtMin(plan.freeMin)}. Change your day’s hours in Settings.`),
  ];
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
  const top = A[0] || B[0] || C[0] || null;
  const rest = (list) => list.filter((r) => r !== top);
  const nothing = !s.items.length;
  const mode = s.settings.todayMode === 'day' ? 'day' : 'list';
  const dueToday = rows.filter((r) => !r.session && r.item.date === today).length;
  const date = new Date(`${today}T12:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'long' });
  const counts = nothing ? null : [`${A.length} A${A.length === 1 ? '' : '’s'}`, `${events.length} class${events.length === 1 ? '' : 'es'}`, `${dueToday} due`].join(' · ');

  let hero;
  if (nothing && !s.meta.onboarded) hero = welcome(ctx);
  else if (top) hero = heroCard(top, ctx, A.length);
  else if (!tray.length) hero = clearCard(ctx, nothing);
  else hero = h('section', { class: 'hero' },
    h('div', { class: 'margin-note' }, hand('first, give these a letter'), penArrow()),
    h('h2', null, `${tray.length} thing${tray.length > 1 ? 's' : ''} without a letter.`),
    h('p', { class: 'what' }, 'Your A1 appears here once you’ve said what matters.'));

  return h('div', { class: 'view today' },
    band('Today',
      h('div', { class: 'band-top' },
        h('div', { class: 'min0' },
          h('h1', { class: 'display' }, WEEKDAY[weekday(today)]),
          h('p', { class: 'sub' }, date, counts ? ` · ${counts}` : '')),
        nothing ? null : streak(s, today)),
      h('button', { class: 'band-link', type: 'button', onclick: () => ctx.go('goals') },
        s.mdp ? ['Toward', h('b', null, s.mdp)] : h('b', null, 'Write the one goal that matters most →')),
      top ? h('div', { class: 'margin-note' }, hand('the most valuable use of my time right now'), penArrow()) : null,
      hero,
      nothing ? null : nextUp(ctx, events, A)),
    h('div', { class: 'col page' },
      banners(ctx, missed),
      sortBanner(tray, ctx),
      !nothing ? segmented([['list', 'The list'], ['day', 'My day']], mode, (m) => ctx.act.setTodayMode(m), { ariaLabel: 'View' }) : null,
      mode === 'day' && !nothing ? dayView(ctx, rows, events) : [
        events.length ? h('section', { class: 'part' }, sec('Classes & meetings', { count: events.length }), h('div', { class: 'card' }, timetable(events, ctx))) : null,
        groupWithDim([...rest(A), ...rest(B)], A.length, ctx),
        group('Later', rest(C), ctx, { dim: A.length + B.length > 0, movable: false, note: 'Nice to do' }),
        group('Delegated', D, ctx, { startable: false, movable: false, note: 'Inspect what you expect' }),
        E.length ? h('details', { class: 'part' },
          h('summary', { class: 'sec' }, h('h2', null, `Let go (${E.length})`)),
          h('ul', { class: 'rows card' }, E.map((r) => h('li', { class: 'item e plain' },
            h('div', { class: 'item-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) }, h('div', { class: 'item-title' }, r.item.title)),
            h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.remove(r.item.id) }, 'Delete'))))) : null,
      ],
      done.length ? h('details', { class: 'part' },
        h('summary', { class: 'sec' }, h('h2', null, `Done today (${done.length})`)),
        h('ul', { class: 'rows card' }, done.map((d) => h('li', { class: 'item done' },
          h('span', { class: 'check' }, icon('check')),
          h('div', { class: 'item-main' }, h('div', { class: 'item-title' }, d.item.title), d.session ? h('div', { class: 'item-sub' }, d.session.label) : null),
          h('span'))))) : null));
}

// "Then": the A's in order, then the B's, which stay dimmed while any A is open.
function groupWithDim(rows, aCount, ctx) {
  if (!rows.length) return null;
  return h('section', { class: 'part' },
    sec('Then', { count: rows.length, note: aCount > 5 ? TIPS.tooManyA(aCount) : rows.some((r) => r.priority === 'B') && aCount ? 'B’s wait until every A is done' : null }),
    h('ul', { class: 'rows card' }, rows.map((r) => rowEl(r, ctx, { dim: r.priority === 'B' && aCount > 0, movable: false }))));
}
