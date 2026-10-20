import { h, svg, icon, rank, tag, meta, fmtMin, band, hand, segmented } from '../ui.js';
import { addDays, nowHHMM, minToTime, weekday } from '../dates.js';
import { dayRows, unsorted, scheduleOn, doneOn, missedSessions } from '../agenda.js';
import { planDay } from '../timeline.js';
import { a1Streak } from '../insights.js';
import { rowEl, timetable, dueTag, completeRow, openSorter } from '../components.js';
import { TIPS } from '../coach.js';

const WEEKDAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function moon() {
  return svg('svg', { class: 'moon', viewBox: '0 0 56 56', 'aria-hidden': 'true' },
    svg('path', { d: 'M41 37.5A18.5 18.5 0 1 1 21.5 8.5a14.5 14.5 0 0 0 19.5 29z' }));
}

function heroCard(r, ctx) {
  const it = r.item;
  const card = h('section', { class: 'hero qa1', 'aria-label': 'Do this first' },
    meta(rank(r.label, r.priority), dueTag(it, ctx.today), r.session ? tag(fmtMin(r.session.minutes)) : null),
    h('h2', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
      h('span', { class: r.priority === 'A' ? 'hl' : null }, it.title)),
    r.session ? h('p', { class: 'what' }, r.session.label) : null,
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.focus(r) }, icon('play'), 'Start'),
      h('button', { class: 'btn', type: 'button', onclick: () => completeRow(card, r, ctx) }, icon('check'), 'Done')));
  return card;
}

function welcome(ctx) {
  return h('section', { class: 'hero welcome' },
    h('h2', null, 'Write it all down.'),
    h('ol', null, h('li', null, h('b', null, 'Add everything')), h('li', null, h('b', null, 'Give each a letter, A to E')), h('li', null, h('b', null, 'Do A1 first'))),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.openImport() }, icon('import'), 'Import semester'),
      h('button', { class: 'btn', type: 'button', onclick: ctx.act.loadSample }, 'Try a sample')));
}

// A one-line nudge: icon, a few words, one button.
function nudge(cls, ic, text, label, onclick) {
  return h('div', { class: `banner ${cls}` },
    h('span', { class: 'bi' }, icon(ic)), h('b', null, text),
    h('button', { class: 'btn sm primary', type: 'button', onclick }, label));
}

function eventRow(ev, slot, ctx) {
  return h('li', { class: 'item ev' },
    h('span', { class: 'ev-dot', 'aria-hidden': 'true' }),
    h('div', { class: 'item-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('div', { class: 'item-title' }, ev.type === 'exam' ? `Exam: ${ev.title}` : ev.type === 'presentation' ? `Present: ${ev.title}` : ev.title),
      meta(tag(`${minToTime(slot.start)}–${minToTime(slot.end)}`), ev.course ? tag(ev.course, 'code') : null)),
    h('span'));
}

// Today as one list in time order: work fitted into the gaps between classes, A's first.
function todayList(ctx, rows, events, top, aCount) {
  const { s, now } = ctx;
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const plan = planDay({ events, rows, dayStart: s.settings.dayStart, dayEnd: s.settings.dayEnd, nowMin, taskMin: s.settings.taskMin });
  const seen = new Set(top ? [top.key] : []);
  const out = [];
  for (const slot of plan.slots) {
    if (slot.kind === 'event') {
      if (slot.end > nowMin) out.push(eventRow(slot.event, slot, ctx));
    } else if (!seen.has(slot.row.key)) {
      seen.add(slot.row.key);
      out.push(rowEl(slot.row, ctx, { dim: slot.row.priority === 'B' && aCount > 0, movable: false, at: minToTime(slot.start) }));
    }
  }
  for (const u of plan.unplaced) {
    if (seen.has(u.row.key)) continue;
    seen.add(u.row.key);
    out.push(rowEl(u.row, ctx, { dim: true, movable: false, at: 'no time left' }));
  }
  for (const r of rows.filter((x) => x.priority === 'D')) out.push(rowEl(r, ctx, { movable: false, startable: false }));
  for (const ev of events.filter((e) => !e.time)) out.push(eventRow(ev, { start: 0, end: 0 }, ctx));
  return out.length ? h('ul', { class: 'rows' }, out) : null;
}

function tomorrowView(ctx) {
  const { s, today } = ctx;
  const tomorrow = addDays(today, 1);
  const rows = dayRows(s.items, tomorrow, today).filter((r) => r.priority !== 'E');
  const events = scheduleOn(s.items, tomorrow);
  const planned = s.meta.lastPlanned === today;
  const tctx = { ...ctx, today: tomorrow, act: { ...ctx.act, move: (key, dir) => ctx.act.move(key, dir, rows) } };
  return [
    events.length ? h('div', { class: 'card' }, timetable(events, ctx, { isToday: false })) : null,
    rows.length ? h('ul', { class: 'rows' }, rows.map((r) => rowEl(r, tctx, { startable: false }))) : h('p', { class: 'empty' }, 'Nothing for tomorrow yet. Tap + to add.'),
    planned
      ? h('div', { class: 'locked' }, moon(), h('div', null, h('b', null, 'Locked in.'), h('div', null, hand('sleep on it'))))
      : h('button', { class: 'btn primary lock-btn', type: 'button', onclick: ctx.act.lockPlan }, icon('plan'), 'Lock in tomorrow'),
  ];
}

export function renderToday(ctx) {
  const { s, today, now } = ctx;
  const tomorrow = ctx.ui.day === 'tomorrow';
  const rows = dayRows(s.items, today);
  const tray = unsorted(s.items, today);
  const events = scheduleOn(s.items, today);
  const missed = missedSessions(s.items, today);
  const done = doneOn(s.items, today);
  const A = rows.filter((r) => r.priority === 'A');
  const top = A[0] || rows.find((r) => r.priority === 'B' || r.priority === 'C') || null;
  const nothing = !s.items.length;
  const streak = a1Streak(s.meta.firstDone, today);
  const date = new Date(`${tomorrow ? addDays(today, 1) : today}T12:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'long' });
  const evening = nowHHMM(now) >= s.settings.planTime && s.meta.lastPlanned !== today;
  const E = rows.filter((r) => r.priority === 'E');
  document.body.dataset.section = tomorrow ? 'plan' : 'today';

  let hero = null;
  if (!tomorrow) {
    if (nothing && !s.meta.onboarded) hero = welcome(ctx);
    else if (top) hero = heroCard(top, ctx);
    else if (!tray.length) hero = h('section', { class: 'hero' }, hand(nothing ? 'a clean page' : 'all done. nice.'),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.quickAdd() }, icon('plus'), 'Add something')));
  }

  return h('div', { class: 'view today' },
    band(tomorrow ? 'Tomorrow' : 'Today',
      h('div', { class: 'band-top' },
        h('div', { class: 'min0' },
          h('h1', { class: 'display' }, WEEKDAY[weekday(tomorrow ? addDays(today, 1) : today)]),
          h('p', { class: 'sub' }, date, !tomorrow && streak ? ` · ${streak}-day streak` : '')),
        nothing ? null : segmented([['today', 'Today'], ['tomorrow', 'Tomorrow']], tomorrow ? 'tomorrow' : 'today',
          (v) => { ctx.ui.day = v; ctx.refresh(); }, { ariaLabel: 'Day' })),
      hero && top && !tomorrow ? h('div', { class: 'margin-note' }, hand('do this first'), icon('down')) : null,
      hero),
    h('div', { class: 'col page' },
      tray.length ? nudge('sort', 'sort', `${tray.length} need${tray.length === 1 ? 's' : ''} a letter`, 'Sort', () => openSorter(ctx)) : null,
      !tomorrow && missed.length ? nudge('alert', 'alert', `${missed.reduce((a, m) => a + m.count, 0)} sessions slipped`, 'Re-plan', ctx.act.replanMissed) : null,
      !tomorrow && evening && !nothing ? nudge('night', 'plan', 'Plan tomorrow', 'Open', () => { ctx.ui.day = 'tomorrow'; ctx.refresh(); }) : null,
      tomorrow ? tomorrowView(ctx) : [
        A.length > 5 ? h('p', { class: 'foot' }, TIPS.tooManyA(A.length)) : null,
        todayList(ctx, rows, events, top, A.length),
        E.length ? h('details', { class: 'fold' },
          h('summary', null, `Drop (${E.length})`),
          h('ul', { class: 'rows' }, E.map((r) => h('li', { class: 'item e plain' },
            h('div', { class: 'item-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) }, h('div', { class: 'item-title' }, r.item.title)),
            h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.remove(r.item.id) }, 'Delete'))))) : null,
        done.length ? h('details', { class: 'fold' },
          h('summary', null, `Done (${done.length})`),
          h('ul', { class: 'rows' }, done.map((d) => h('li', { class: 'item done' },
            h('span', { class: 'check' }, icon('check')),
            h('div', { class: 'item-main' }, h('div', { class: 'item-title' }, d.item.title)),
            h('span'))))) : null,
      ]));
}
