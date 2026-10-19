// Building blocks shared by several screens.

import { h, icon, TYPE_META, fmtMin, courseChip } from './ui.js';
import { diffDays, relDay, fmtTime, timeToMin } from './dates.js';
import { LETTERS } from './agenda.js';
import { LETTER_HELP, TIPS } from './coach.js';
import { suggestedLetter } from './store.js';

const DUE_WORD = { exam: 'Exam', presentation: 'Presenting', reading: 'Read by', deadline: 'Due', task: 'Due' };

export function dueChip(item, today) {
  if (!item.date || item.recur || item.type === 'event') return null;
  const n = diffDays(today, item.date);
  const when = `${relDay(item.date, today)}${item.time ? ` ${fmtTime(item.time)}` : ''}`;
  if (n < 0) return h('span', { class: 'chip overdue' }, `Overdue ${-n}d`);
  const cls = n === 0 ? 'chip due-today' : n <= 2 ? 'chip soon' : 'chip';
  return h('span', { class: cls }, `${DUE_WORD[item.type] || 'Due'} ${when}`);
}

export function typeIcon(type) {
  return h('span', { class: `type-ic t-${type}`, title: TYPE_META[type]?.label }, icon(TYPE_META[type]?.icon || 'dot'));
}

export function rowEl(r, ctx, { muted = false, movable = true, startable = true } = {}) {
  const it = r.item;
  const subs = [];
  if (r.session) {
    subs.push(h('span', { class: 'sub-main' }, typeIcon(it.type), `${r.session.label} · ${fmtMin(r.session.minutes)}`));
    if (r.extra) subs.push(h('span', { class: 'chip' }, `+${r.extra} more`));
    if (r.overdue) subs.push(h('span', { class: 'chip overdue' }, `Missed ${relDay(r.session.date, ctx.today)}`));
  } else {
    subs.push(typeIcon(it.type));
    const left = (it.sessions || []).filter((s) => !s.done).length;
    if (left) subs.push(h('span', null, `${left} planned session${left > 1 ? 's' : ''} left`));
    if (it.recur) subs.push(h('span', null, 'Repeats'));
  }
  if (it.priority === 'D') subs.push(h('span', { class: 'deleg' }, it.delegateTo ? `Delegated to ${it.delegateTo} · follow up` : 'Who can do this? Tap to add'));
  return h('li', { class: `row l-${it.priority}${muted ? ' muted' : ''}`, 'data-key': r.key },
    h('button', { class: 'check', 'aria-label': `Mark “${it.title}” done`, onclick: () => ctx.act.complete(r) }, icon('check')),
    h('div', { class: 'row-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id),
      onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
      h('div', { class: 'row-title' },
        h('span', { class: `badge l-${it.priority}` }, r.label),
        h('span', { class: 'row-text' }, it.title)),
      h('div', { class: 'row-sub' }, subs, dueChip(it, ctx.today), courseChip(it.course))),
    h('div', { class: 'row-actions' },
      movable ? h('div', { class: 'mover' },
        h('button', { class: 'icon-btn xs', 'aria-label': `Move “${it.title}” up`, onclick: () => ctx.act.move(r.key, -1) }, icon('up')),
        h('button', { class: 'icon-btn xs', 'aria-label': `Move “${it.title}” down`, onclick: () => ctx.act.move(r.key, 1) }, icon('down'))) : null,
      startable ? h('button', { class: 'icon-btn sm start', 'aria-label': `Start “${it.title}”`, onclick: () => ctx.focus(r) }, icon('play')) : null));
}

export function trayEl(items, ctx) {
  if (!items.length) return null;
  return h('section', { class: 'card tray', 'aria-labelledby': 'tray-h' },
    h('div', { class: 'card-head' },
      h('h3', { id: 'tray-h' }, 'Give these a letter'),
      h('span', { class: 'count' }, String(items.length))),
    h('p', { class: 'tray-q' }, TIPS.consequences),
    h('div', { class: 'legend' }, LETTERS.map((L) =>
      h('span', { class: 'lg' }, h('b', { class: `badge l-${L}` }, L), LETTER_HELP[L].name))),
    h('ul', { class: 'tray-list' }, items.map((it) => {
      const sugg = suggestedLetter(it.type);
      return h('li', null,
        h('div', { class: 'tray-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id) },
          typeIcon(it.type),
          h('span', { class: 'row-text' }, it.title),
          dueChip(it, ctx.today), courseChip(it.course)),
        h('div', { class: 'letters', role: 'group', 'aria-label': `Letter for ${it.title}` },
          LETTERS.map((L) => h('button', {
            class: `letter l-${L}${sugg === L ? ' suggest' : ''}`,
            title: `${LETTER_HELP[L].name}: ${LETTER_HELP[L].hint}`,
            'aria-label': `${L}, ${LETTER_HELP[L].name}`,
            onclick: () => ctx.act.letter(it.id, L),
          }, L))));
    })));
}

export function scheduleEl(events, ctx, { title = 'Schedule', isToday = true } = {}) {
  if (!events.length) return null;
  const nowMin = ctx.now.getHours() * 60 + ctx.now.getMinutes();
  let nextMarked = false;
  return h('section', { class: 'card schedule' },
    h('div', { class: 'card-head' }, h('h3', null, title)),
    h('ul', { class: 'sched-list' }, events.map((ev) => {
      const start = timeToMin(ev.time);
      const end = start != null ? start + (ev.durationMin || 60) : null;
      let state = '';
      if (isToday && start != null) {
        if (nowMin >= end) state = 'past';
        else if (nowMin >= start) state = 'now';
        else if (!nextMarked) { state = 'next'; nextMarked = true; }
      }
      if (state === 'now') nextMarked = true;
      return h('li', { class: `sched ${state} t-${ev.type}`, role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
        h('span', { class: 'sched-time' }, ev.time ? fmtTime(ev.time) : 'All day'),
        h('span', { class: 'sched-title' },
          ev.type !== 'event' ? h('span', { class: `pill t-${ev.type}` }, ev.type === 'exam' ? 'Exam' : 'Presenting') : null,
          ev.title),
        state === 'now' ? h('span', { class: 'chip due-today' }, 'Now') : state === 'next' ? h('span', { class: 'chip soon' }, 'Next') : null,
        courseChip(ev.course));
    })));
}

export function emptyNote(text) {
  return h('p', { class: 'empty-note' }, text);
}
