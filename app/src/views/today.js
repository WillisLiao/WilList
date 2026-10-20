import { h, icon, bubble, pips, tag, codeTag, sec, fmtMin, formLabel } from '../ui.js';
import { addDays, nowHHMM, minToTime, weekday } from '../dates.js';
import { dayRows, unsorted, scheduleOn, doneOn, missedSessions } from '../agenda.js';
import { planDay } from '../timeline.js';
import { a1Streak } from '../insights.js';
import { TIPS } from '../coach.js';
import { rowEl, trayEl, timetable, itemMeta, emptyNote } from '../components.js';

const WEEKDAY = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

function welcome(ctx) {
  return h('section', { class: 'box callout' },
    formLabel('How this sheet works', 'span', { class: 'form box-label' }),
    h('ol', { class: 'steps' },
      h('li', null, h('b', null, 'Write it all down. '), 'Type into the box at the top the way you’d say it: “Chem quiz thu”, “Essay due nov 3 25%”, “Lab every wed 2-5pm”. Or bring in your whole semester from Canvas, Moodle, Google Calendar or a syllabus.'),
      h('li', null, h('b', null, 'Fill in one bubble for each. '), 'A if skipping it has serious consequences, down to E if it doesn’t matter.'),
      h('li', null, h('b', null, 'Answer the question. '), 'Your A1 is the most valuable use of your time right now. WilList works out when to start studying for everything else.')),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.openImport() }, 'Bring in my semester'),
      h('button', { class: 'btn', type: 'button', onclick: ctx.act.loadSample }, 'Try a sample week')));
}

function planPrompt(ctx) {
  const { s, today, now } = ctx;
  const evening = nowHHMM(now) >= s.settings.planTime;
  const last = s.meta.lastPlanned;
  let text = null;
  if (evening && last !== today) text = ['Plan tomorrow. ', TIPS.planTonight];
  else if (!evening && now.getHours() >= 5 && last && last < addDays(today, -1)) text = ['Plan today. ', TIPS.planMorning];
  if (!text) return null;
  return h('button', { class: 'box callout callout-btn', type: 'button', onclick: () => ctx.go('plan') },
    h('span', { class: 'form box-label' }, 'Two minutes'),
    h('span', null, h('b', null, text[0]), text[1]));
}

function streakLine(s, today) {
  const n = a1Streak(s.meta.firstDone, today);
  return h('div', { class: 'streak' },
    formLabel('A1 first'),
    pips(21, Math.min(n, 21), { label: `${n} of 21 days in a row starting with an A` }),
    h('span', { class: 'mono muted' }, `${n}/21 days`));
}

function answerCard(r, ctx, aLeft) {
  const it = r.item;
  const sub = r.session ? `${r.session.label} · ${fmtMin(r.session.minutes)}` : (it.notes || '').split('\n')[0];
  return h('section', { class: 'qa1', 'aria-label': 'Your next task' },
    h('p', { class: 'form q' }, `Q. ${TIPS.a1}`),
    h('div', { class: 'a' },
      h('span', { class: 'a-label' }, r.label),
      h('div', { class: 'a-body' },
        h('h2', { class: 'display', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) }, h('span', null, it.title)),
        sub ? h('p', { class: 'ans-sub' }, sub) : null,
        itemMeta(it, ctx.today, r.overdue ? [tag('Missed earlier', 'late')] : []),
        it.priority !== 'A' ? h('p', { class: 'small muted' }, aLeft ? '' : 'No A’s left today. This is your best next move.') : null,
        h('div', { class: 'btn-row' },
          h('button', { class: 'btn primary', type: 'button', onclick: () => ctx.focus(r) }, icon('play'), 'Start now'),
          h('button', { class: 'btn', type: 'button', onclick: () => ctx.act.complete(r) }, bubble('', { size: 'sm' }), 'Done')))));
}

function group(title, rows, ctx, opts = {}) {
  if (!rows.length) return null;
  return h('section', { class: 'part' },
    sec(title, { count: rows.length, note: opts.note }),
    h('ul', { class: 'rows' }, rows.map((r) => rowEl(r, ctx, opts))));
}

function dayView(ctx, rows, events) {
  const { s, now } = ctx;
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const plan = planDay({ events, rows, dayStart: s.settings.dayStart, dayEnd: s.settings.dayEnd, nowMin, taskMin: s.settings.taskMin });
  const items = [];
  let nowPlaced = false;
  const nowLine = () => h('li', { class: 'nowline' }, h('span', { class: 't' }, minToTime(nowMin)), h('span', { class: 'spine' }), h('div', { class: 'body' }), h('span', null));
  for (const slot of plan.slots) {
    if (!nowPlaced && slot.start >= nowMin) { items.push(nowLine()); nowPlaced = true; }
    if (slot.kind === 'event') {
      const ev = slot.event;
      items.push(h('li', { class: `fixed${slot.end <= nowMin ? ' past' : ''}` },
        h('span', { class: 't' }, minToTime(slot.start)),
        h('span', { class: 'spine' }, bubble('', { size: 'sm', filled: true })),
        h('div', { class: 'body', role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
          h('b', null, ev.type === 'exam' ? `Exam: ${ev.title}` : ev.type === 'presentation' ? `Presenting: ${ev.title}` : ev.title),
          h('div', { class: 'meta' }, tag(`${minToTime(slot.start)}–${minToTime(slot.end)}`), codeTag(ev.course))),
        h('span', { class: 'end' })));
    } else {
      const r = slot.row;
      items.push(h('li', null,
        h('span', { class: 't' }, minToTime(slot.start)),
        h('span', { class: 'spine' }, bubble('', { size: 'sm' })),
        h('div', { class: 'body', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) },
          h('span', null, h('b', null, `${r.label} `), r.item.title, slot.part ? ` (part ${slot.part})` : ''),
          h('div', { class: 'meta' }, tag(`${fmtMin(slot.end - slot.start)} · until ${minToTime(slot.end)}`), r.session ? tag(r.session.label) : null)),
        h('span', { class: 'end' }, h('button', { class: 'go', type: 'button', 'aria-label': `Start “${r.item.title}”`, onclick: () => ctx.focus(r) }, icon('play')))));
    }
  }
  if (!nowPlaced) items.push(nowLine());
  return [
    sec('Your day', { note: `${s.settings.dayStart}–${s.settings.dayEnd}, A’s first, breaks between` }),
    items.length > 1 ? h('ul', { class: 'timeline' }, items) : emptyNote('Nothing scheduled and nothing on the list.'),
    plan.unplaced.length ? h('div', { class: 'box callout alert' },
      h('span', { class: 'form box-label' }, 'Doesn’t fit today'),
      h('ul', { class: 'lines' }, plan.unplaced.map((u) => h('li', null, h('b', null, u.row.label), h('span', { class: 'grow' }, u.row.item.title), tag(fmtMin(u.minutes))))),
      h('p', { class: 'small' }, 'Move something to tomorrow, delegate it (D), or ask for help early. Balance on Radar re-spreads study sessions.')) : null,
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

  const reward = s.settings.reward?.trim();
  const aDoneToday = done.filter((d) => d.item.priority === 'A').length;
  const rewardEl = reward && (A.length || aDoneToday)
    ? h('p', { class: 'small' }, formLabel(A.length ? 'Reward after the A’s' : 'Earned'), ' ', reward)
    : null;

  return h('div', { class: 'view today' },
    h('header', { class: 'dayhead' },
      h('h1', { class: 'display page-title' }, WEEKDAY[weekday(today)]),
      h('div', { class: 'dayline' },
        h('span', { class: 'mono' }, new Date(`${today}T12:00`).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }).toUpperCase()),
        h('span', { class: 'mono muted' }, `${A.length} A · ${events.length} class${events.length === 1 ? '' : 'es'} · ${dueToday} due`)),
      h('button', { class: 'formline', type: 'button', onclick: () => ctx.go('goals') },
        formLabel('Major definite purpose'),
        h('span', { class: 'val' }, s.mdp || h('span', { class: 'muted' }, 'Write the one goal that matters most →'))),
      nothing ? null : streakLine(s, today)),
    nothing && !s.meta.onboarded ? welcome(ctx) : null,
    planPrompt(ctx),
    missed.length ? h('div', { class: 'box callout alert' },
      h('span', { class: 'form box-label' }, 'Behind'),
      h('p', null, `${missed.reduce((a, m) => a + m.count, 0)} study session(s) slipped: ${missed.map((m) => m.item.title).join(', ')}. ${TIPS.missed}`),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn sm', type: 'button', onclick: ctx.act.replanMissed }, 'Re-plan from today'))) : null,
    trayEl(tray, ctx),
    top ? answerCard(top, ctx, A.length) : (!nothing && !tray.length ? h('section', { class: 'box callout' },
      h('span', { class: 'form box-label' }, 'All answered'),
      h('p', null, 'Nothing left on today’s list. Check Radar for what’s coming, or work ahead on an A.')) : null),
    rewardEl,
    !nothing ? h('div', { class: 'seg', role: 'radiogroup', 'aria-label': 'View' },
      ['list', 'day'].map((m) => h('button', { type: 'button', role: 'radio', 'aria-checked': String(mode === m), onclick: () => ctx.act.setTodayMode(m) },
        bubble('', { filled: mode === m }), formLabel(m === 'list' ? 'The list' : 'My day')))) : null,
    mode === 'day' && !nothing ? dayView(ctx, rows, events) : [
      events.length ? h('section', { class: 'part' }, sec('Classes & meetings', { count: events.length }), timetable(events, ctx)) : null,
      group('A · Must do', rest(A), ctx, { note: A.length > 5 ? TIPS.tooManyA(A.length) : null }),
      group('B · Should do', rest(B), ctx, { dim: A.length > 0, note: A.length ? 'After every A' : null }),
      group('C · Nice to do', rest(C), ctx, { dim: A.length + B.length > 0 }),
      group('D · Delegated', D, ctx, { startable: false, note: 'Inspect what you expect' }),
      E.length ? h('details', { class: 'part' },
        h('summary', { class: 'form' }, `E · Eliminate (${E.length})`),
        h('ul', { class: 'rows' }, E.map((r) => h('li', { class: 'ans e plain' },
          h('div', { class: 'ans-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(r.item.id) }, h('div', { class: 'ans-title' }, r.item.title)),
          h('button', { class: 'btn sm ink', type: 'button', onclick: () => ctx.act.remove(r.item.id) }, 'Let it go'))))) : null,
    ],
    done.length ? h('details', { class: 'part' },
      h('summary', { class: 'form' }, `Done today (${done.length})`),
      h('ul', { class: 'rows' }, done.map((d) => h('li', { class: 'ans done donerow' },
        bubble('', { filled: true }),
        h('div', { class: 'ans-main' }, h('div', { class: 'ans-title' }, d.item.title), d.session ? h('div', { class: 'ans-sub' }, d.session.label) : null))))) : null,
  );
}
