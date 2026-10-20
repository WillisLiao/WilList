// Building blocks shared by several screens.

import { h, icon, bubble, tag, codeTag, sec, TYPE_META, fmtMin } from './ui.js';
import { diffDays, relDay, minToTime, timeToMin } from './dates.js';
import { LETTERS } from './agenda.js';
import { TIPS } from './coach.js';
import { suggestedLetter } from './store.js';

const DUE_WORD = { exam: 'Exam', presentation: 'Talk', reading: 'Read by', deadline: 'Due', task: 'Due' };
export const CONSEQUENCE = { A: 'Serious', B: 'Mild', C: 'None', D: 'Someone else can', E: 'Doesn’t matter' };

export function dueTag(item, today) {
  if (!item.date || item.recur || item.type === 'event') return null;
  const n = diffDays(today, item.date);
  if (n < 0) return tag(`Late ${-n}d`, 'late');
  const when = `${relDay(item.date, today)}${item.time ? ` ${item.time}` : ''}`;
  return tag(`${DUE_WORD[item.type] || 'Due'} ${when}`, n <= 2 ? 'soon' : 'due');
}

export function typeTag(type) {
  return tag(TYPE_META[type]?.code || type);
}

export function stakeTag(item) {
  return item.weightPct ? tag(`${item.weightPct}% of grade`, 'stake') : null;
}

export function itemMeta(it, today, extra = []) {
  return h('div', { class: 'meta' }, typeTag(it.type), dueTag(it, today), stakeTag(it), codeTag(it.course), extra);
}

export function rowEl(r, ctx, { dim = false, movable = true, startable = true } = {}) {
  const it = r.item;
  let sub = null;
  const extra = [];
  if (r.session) {
    sub = `${r.session.label} · ${fmtMin(r.session.minutes)}`;
    if (r.extra) extra.push(tag(`+${r.extra} more today`));
    if (r.overdue) extra.push(tag(`Missed ${relDay(r.session.date, ctx.today)}`, 'late'));
  } else {
    const left = (it.sessions || []).filter((s) => !s.done).length;
    if (left) sub = `${left} planned session${left > 1 ? 's' : ''} left`;
    if (it.recur) extra.push(tag('Repeats'));
  }
  if (it.priority === 'D') sub = it.delegateTo ? `Delegated to ${it.delegateTo}. Check in.` : 'Who can do this? Tap to add a name.';
  return h('li', { class: `ans${dim ? ' dim' : ''}${it.priority === 'E' ? ' e' : ''}`, 'data-key': r.key },
    bubble('', { button: true, 'aria-label': `Mark “${it.title}” done`, onclick: () => ctx.act.complete(r) }),
    h('span', { class: 'rank' }, r.label),
    h('div', { class: 'ans-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id),
      onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
      h('div', { class: 'ans-title' }, it.title),
      sub ? h('div', { class: 'ans-sub' }, sub) : null,
      itemMeta(it, ctx.today, extra)),
    h('div', { class: 'ans-act' },
      movable ? h('div', { class: 'mover' },
        h('button', { class: 'tiny', type: 'button', 'aria-label': `Move “${it.title}” up`, onclick: () => ctx.act.move(r.key, -1) }, icon('up')),
        h('button', { class: 'tiny', type: 'button', 'aria-label': `Move “${it.title}” down`, onclick: () => ctx.act.move(r.key, 1) }, icon('down'))) : null,
      startable ? h('button', { class: 'go', type: 'button', 'aria-label': `Start “${it.title}”`, onclick: () => ctx.focus(r) }, icon('play')) : null),
    h('span', { class: 'tm', 'aria-hidden': 'true' }));
}

export function trayEl(items, ctx, { title = 'Unanswered' } = {}) {
  if (!items.length) return null;
  const suggestions = items.filter((it) => suggestedLetter(it.type, it.weightPct));
  return h('section', { class: 'part', 'aria-labelledby': 'tray-h' },
    sec(title, { count: items.length, id: 'tray-h', note: 'Fill in one bubble each' }),
    h('p', null, h('b', null, TIPS.consequences)),
    h('div', { class: 'key' }, LETTERS.map((L) => h('span', null, bubble(L), CONSEQUENCE[L]))),
    suggestions.length > 1 ? h('div', { class: 'btn-row' },
      h('button', { class: 'btn sm', type: 'button', onclick: () => ctx.act.acceptSuggestions(suggestions.map((it) => it.id)) },
        `Ink the ${suggestions.length} pencil marks`),
      h('span', { class: 'small muted' }, 'Grey marks are suggestions from the grade weight or the kind of item.')) : null,
    h('ul', { class: 'rows' }, items.map((it) => {
      const sugg = suggestedLetter(it.type, it.weightPct);
      return h('li', { class: 'ans tray-row' },
        h('div', { class: 'tray-line' },
          h('div', { class: 'ans-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
            h('div', { class: 'ans-title' }, it.title),
            itemMeta(it, ctx.today)),
          h('div', { class: 'bubbles', role: 'group', 'aria-label': `Letter for ${it.title}` },
            LETTERS.map((L) => bubble(L, {
              button: true, ghost: sugg === L,
              title: `${L}: if you skip it, consequences are ${CONSEQUENCE[L].toLowerCase()}`,
              'aria-label': `${L}, ${CONSEQUENCE[L]}${sugg === L ? ' (suggested)' : ''}`,
              onclick: () => ctx.act.letter(it.id, L),
            })))));
    })));
}

export function timetable(events, ctx, { isToday = true } = {}) {
  if (!events.length) return null;
  const nowMin = ctx.now.getHours() * 60 + ctx.now.getMinutes();
  let marked = false;
  return h('ul', { class: 'tt' }, events.map((ev) => {
    const start = timeToMin(ev.time);
    const end = start != null ? start + (ev.durationMin || 60) : null;
    let state = '';
    if (isToday && start != null) {
      if (nowMin >= end) state = 'past';
      else if (nowMin >= start) { state = 'now'; marked = true; } else if (!marked) { state = 'next'; marked = true; }
    }
    return h('li', { class: state, role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('span', { class: 't' }, ev.time ? `${ev.time}–${minToTime(end)}` : 'All day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? 'EXAM: ' : ev.type === 'presentation' ? 'PRESENTING: ' : '', ev.title,
        state === 'now' ? h('span', { class: 'tag soon' }, '  now') : state === 'next' ? h('span', { class: 'tag soon' }, '  next') : null),
      codeTag(ev.course));
  }));
}

export function emptyNote(text) {
  return h('p', { class: 'empty' }, text);
}
