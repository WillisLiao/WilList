import { h, icon, rank, tag, meta, fmtMin, titleRow, panel, segmented } from '../ui.js';
import { addDays, nowHHMM, minToTime, timeToMin, weekday, diffDays } from '../dates.js';
import { dayRows, unsorted, scheduleOn, doneOn, missedSessions, vitalFew } from '../agenda.js';
import { planDay } from '../timeline.js';
import { a1Streak } from '../insights.js';
import { rowEl, dueTag, completeRow, openSorter } from '../components.js';
import { TIPS } from '../coach.js';

// Today answers one question: what do I do next, and does the rest of the day fit?
// The day runs down the page in time order: classes are fixed blocks, your work is
// fitted into the gaps (A's first), a line marks now, what you finished sits above
// it, and whatever doesn't fit by the end of the day hangs below that line.

const WEEKDAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const GAP_MIN = 20;

function dayPlan(ctx, day, live) {
  const { s, now } = ctx;
  const rows = dayRows(s.items, day, ctx.today);
  const events = scheduleOn(s.items, day);
  const nowMin = live ? now.getHours() * 60 + now.getMinutes() : null;
  const plan = planDay({ events, rows, dayStart: s.settings.dayStart, dayEnd: s.settings.dayEnd, nowMin, taskMin: s.settings.taskMin });
  const overMin = plan.unplaced.reduce((a, u) => a + u.minutes, 0);
  return { rows, events, plan, nowMin, overMin, start: timeToMin(s.settings.dayStart), end: timeToMin(s.settings.dayEnd) };
}

// "1 h 40 m" with the units set smaller, for the count tiles.
function dur(min) {
  const hh = Math.floor(min / 60);
  const mm = min % 60;
  return [hh ? [String(hh), h('small', null, ' h ')] : null, !hh || mm ? [String(mm), h('small', null, ' m')] : null];
}

function tile(label, value, caption, cls = '') {
  return h('div', { class: `tile ${cls}`.trim() },
    h('span', { class: 'tile-label' }, label),
    h('span', { class: 'tile-value num' }, value),
    caption ? h('span', { class: 'tile-cap' }, caption) : null);
}

function heroCard(r, ctx) {
  const it = r.item;
  const card = h('section', { class: 'hero qa1', 'aria-label': 'Do this first' },
    meta(rank(r.label, r.priority), dueTag(it, ctx.today), r.session ? tag(fmtMin(r.session.minutes)) : null, it.course ? tag(it.course, 'code') : null),
    h('h2', { role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } }, it.title),
    r.session ? h('p', { class: 'what' }, r.session.label) : null,
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.focus(r) }, icon('play'), 'Start'),
      h('button', { class: 'btn', type: 'button', onclick: () => completeRow(card, r, ctx) }, icon('check'), 'Done')));
  return card;
}

const timeCell = (text) => h('span', { class: 't num' }, text);
const slot = (cls, time, minutes, ...card) =>
  h('li', { class: `slot ${cls}`.trim(), style: minutes ? { '--m': String(minutes) } : null }, timeCell(time), card);

function eventCard(ev, end, ctx) {
  return h('div', { class: 'item ev', role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(ev.id); } },
    h('div', { class: 'item-main' },
      h('div', { class: 'item-title' }, ev.type === 'exam' ? `Exam: ${ev.title}` : ev.type === 'presentation' ? `Present: ${ev.title}` : ev.title),
      meta(end ? tag(`until ${end}`) : null, ev.course ? tag(ev.course, 'code') : null)));
}

function ribbon(ctx, d, { top = null, live = false, movable = false, aCount = 0 } = {}) {
  const out = [];
  const seen = new Set();
  const dim = (r) => r.priority === 'B' && aCount > 0;
  const placed = new Set(d.plan.slots.filter((x) => x.kind === 'work').map((x) => x.row.key));
  const work = (r, time, minutes, opts = {}) => {
    seen.add(r.key);
    return slot(opts.cls || '', time, minutes, rowEl(r, ctx, { dim: dim(r), movable, startable: live, tagName: 'div', ...opts }));
  };
  const hero = (time) => { seen.add(top.key); return slot('hero-slot', time, 0, heroCard(top, ctx)); };

  for (const ev of d.events.filter((e) => !e.time)) out.push(slot('fixed', 'All day', 0, eventCard(ev, null, ctx)));

  let cursor = d.start;
  if (live) {
    // Behind you: classes that already ended, and everything you finished today.
    for (const x of d.plan.slots) if (x.kind === 'event' && x.end <= d.nowMin) out.push(slot('fixed past', minToTime(x.start), 0, eventCard(x.event, minToTime(x.end), ctx)));
    for (const dn of doneOn(ctx.s.items, ctx.today)) {
      out.push(slot('done', '', 0, h('div', { class: 'item done', role: 'button', tabindex: '0', onclick: () => ctx.edit(dn.item.id) },
        h('span', { class: 'check', 'aria-hidden': 'true' }, icon('check')),
        h('div', { class: 'item-main' }, h('div', { class: 'item-title' }, dn.item.title)))));
    }
    out.push(h('li', { class: 'slot now' }, timeCell(minToTime(d.nowMin)), h('span', { class: 'line' }, h('span', { class: 'visually-hidden' }, 'Now'))));
    cursor = Math.max(d.start, d.nowMin);
    if (top && !placed.has(top.key)) out.push(hero(''));
  }

  for (const x of d.plan.slots) {
    if (live && x.kind === 'event' && x.end <= d.nowMin) continue;
    if (x.start - cursor >= GAP_MIN) out.push(h('li', { class: 'slot gap', style: { '--m': String(x.start - cursor) } }, timeCell(''), h('span', null, `${fmtMin(x.start - cursor)} free`)));
    cursor = Math.max(cursor, x.end);
    if (x.kind === 'event') { out.push(slot(`fixed${live && x.start <= d.nowMin ? ' live' : ''}`, minToTime(x.start), x.end - x.start, eventCard(x.event, minToTime(x.end), ctx))); continue; }
    if (seen.has(x.row.key)) continue;
    if (top && x.row.key === top.key) { out.push(hero(minToTime(x.start))); continue; }
    out.push(work(x.row, minToTime(x.start), x.end - x.start));
  }
  if (d.end - cursor >= GAP_MIN) out.push(h('li', { class: 'slot gap', style: { '--m': String(d.end - cursor) } }, timeCell(''), h('span', null, `${fmtMin(d.end - cursor)} free`)));
  out.push(h('li', { class: 'slot end' }, timeCell(minToTime(d.end)), h('span', { class: 'line' }, 'End of day')));

  // Past the end of the day: what doesn't fit, then what someone else is doing.
  for (const u of d.plan.unplaced) if (!seen.has(u.row.key)) out.push(work(u.row, '', u.minutes, { cls: 'spill' }));
  for (const r of d.rows.filter((x) => x.priority === 'D')) out.push(work(r, '', 0, { movable: false, startable: false, cls: 'handed' }));
  return h('ul', { class: `ribbon${live ? ' live' : ''}`, 'aria-label': live ? 'Your day, in time order' : 'Tomorrow, in time order' }, out);
}

function welcome(ctx) {
  return h('div', { class: 'welcome' },
    h('ol', null, h('li', null, 'Add everything: classes, exams, homework'), h('li', null, 'Give each a letter, A to E'), h('li', null, 'Do A1 first')),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.openImport() }, icon('import'), 'Import semester'),
      h('button', { class: 'btn', type: 'button', onclick: ctx.act.loadSample }, 'Try a sample')));
}

// One line per thing that needs you: a few words and one button.
function notice(text, label, onclick, cls = '') {
  return h('div', { class: `notice ${cls}`.trim() }, h('span', null, text), h('button', { class: 'btn sm', type: 'button', onclick }, label));
}

export function renderToday(ctx) {
  const { s, today, now } = ctx;
  const tomorrow = ctx.ui.day === 'tomorrow';
  const live = !tomorrow;
  const day = tomorrow ? addDays(today, 1) : today;
  const d = dayPlan(ctx, day, live);
  const tray = unsorted(s.items, today);
  const missed = missedSessions(s.items, today);
  const A = d.rows.filter((r) => r.priority === 'A');
  const top = live ? A[0] || d.rows.find((r) => r.priority === 'B' || r.priority === 'C') || null : null;
  const nothing = !s.items.length;
  const firstRun = nothing && !s.meta.onboarded;
  const done = live ? doneOn(s.items, today) : [];
  const streak = a1Streak(s.meta.firstDone, today);
  const date = new Date(`${day}T12:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'long' });
  const evening = nowHHMM(now) >= s.settings.planTime && s.meta.lastPlanned !== today;
  const E = d.rows.filter((r) => r.priority === 'E');
  const planned = s.meta.lastPlanned === today;
  const left = d.plan.slots.some((x) => x.kind === 'work' || (x.kind === 'event' && (!live || x.end > d.nowMin))) || d.plan.unplaced.length;
  const wd = WEEKDAY[weekday(day)];
  const coming = vitalFew(s.items, today).slice(0, 3);
  const nextEv = live ? d.plan.slots.find((x) => x.kind === 'event' && x.start >= d.nowMin) : null;

  // The greeting carries the day's one fact.
  let greeting = `${wd}. It all fits.`;
  if (firstRun) greeting = 'Write it all down.';
  else if (tomorrow) greeting = `${wd}. ${planned ? 'Locked in.' : 'Plan it tonight.'}`;
  else if (d.overMin > 0) greeting = `${wd}. ${fmtMin(d.overMin)} too much.`;
  else if (!left) greeting = `${wd}. ${done.length ? 'All done.' : 'A clean page.'}`;
  const sub = firstRun ? 'Everything you have to do, in one place, in the right order.'
    : live && d.overMin > 0 ? `${date}. Move a B or C to tomorrow.` : date;

  // Tomorrow's list is numbered here: moving a row re-ranks it and refits the day.
  const tctx = tomorrow ? { ...ctx, today: day, act: { ...ctx.act, move: (key, dir) => ctx.act.move(key, dir, d.rows) } } : ctx;
  const hasDay = d.rows.some((r) => r.priority !== 'E') || d.events.length;

  const needs = [
    tray.length ? notice(`${tray.length} need${tray.length === 1 ? 's' : ''} a letter`, 'Sort', () => openSorter(ctx), 'sort') : null,
    live && missed.length ? notice(`${missed.reduce((a, m) => a + m.count, 0)} study sessions slipped`, 'Re-plan', ctx.act.replanMissed, 'bad') : null,
    live && evening && !nothing ? notice('Plan tomorrow', 'Open', () => { ctx.ui.day = 'tomorrow'; ctx.refresh(); }) : null,
    A.length > 5 ? h('p', { class: 'foot' }, TIPS.tooManyA(A.length)) : null,
  ].filter(Boolean);

  return h('div', { class: 'view today' },
    titleRow(h('h1', { class: 'greet' }, greeting), sub,
      nothing ? null : segmented([['today', 'Today'], ['tomorrow', 'Tomorrow']], tomorrow ? 'tomorrow' : 'today',
        (v) => { ctx.ui.day = v; ctx.refresh(); }, { ariaLabel: 'Day' })),
    live && !firstRun ? h('div', { class: 'tiles' },
      tile('Free today', dur(Math.max(0, d.plan.freeMin)), d.overMin > 0 ? `${fmtMin(d.overMin)} won’t fit` : `until ${minToTime(d.end)}`, d.overMin > 0 ? 'bad' : ''),
      tile('A’s left', String(A.length), A.length ? 'A1 first, always' : 'Every A is done'),
      tile('Done today', String(done.length), streak ? `${streak}-day A1-first streak` : 'Start with an A'),
      tile('Next class', nextEv ? minToTime(nextEv.start) : h('span', { class: 'dash' }, '–'), nextEv ? nextEv.event.title : 'No more today')) : null,
    h('div', { class: 'grid' },
      panel(tomorrow ? 'Tomorrow' : 'Your day', { cls: `day ${firstRun ? 'span-12' : 'span-8'}`, id: 'day-h', aside: hasDay ? h('span', { class: 'meta' }, `${minToTime(d.start)}–${minToTime(d.end)}`) : null },
        firstRun ? welcome(ctx)
          : hasDay ? ribbon(tctx, d, { top, live, movable: tomorrow, aCount: A.length })
            : h('div', { class: 'empty' }, tomorrow ? 'Nothing for tomorrow yet.' : 'Nothing left today.',
              h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.quickAdd() }, icon('plus'), 'Add something')),
        tomorrow ? (planned
          ? h('p', { class: 'locked' }, icon('check'), 'Locked in. Sleep on it.')
          : h('button', { class: 'btn primary lock-btn', type: 'button', onclick: ctx.act.lockPlan }, icon('plan'), 'Lock in tomorrow')) : null),
      firstRun ? null : h('div', { class: 'side-col span-4' },
        needs.length ? h('div', { class: 'needs' }, needs) : null,
        coming.length ? panel('Coming up', { id: 'coming-h', aside: h('a', { class: 'card-link', href: '#ahead' }, 'Ahead') },
          h('ul', { class: 'mini' }, coming.map((v) => h('li', null,
            h('button', { class: 'linkish', type: 'button', onclick: () => ctx.edit(v.item.id) }, rank(v.item.priority), v.item.title,
              v.total ? h('small', null, `${v.done} of ${v.total} sessions`) : null),
            h('span', { class: `days num${diffDays(today, v.item.date) <= 2 ? ' soon' : ''}` }, String(diffDays(today, v.item.date)), h('small', null, ' d')))))) : null,
        E.length && live ? panel('Dropped', { id: 'drop-h', aside: h('span', { class: 'meta num' }, String(E.length)) },
          h('ul', { class: 'mini' }, E.map((r) => h('li', null,
            h('button', { class: 'linkish', type: 'button', onclick: () => ctx.edit(r.item.id) }, r.item.title),
            h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.remove(r.item.id) }, 'Delete'))))) : null)));
}
