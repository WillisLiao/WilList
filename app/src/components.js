// Building blocks shared by several screens.

import { h, fill, icon, rank, tag, meta, hand, penMark, openSheet, TYPE_META, fmtMin } from './ui.js';
import { diffDays, relDay, minToTime, timeToMin } from './dates.js';
import { LETTERS, unsorted } from './agenda.js';
import { TIPS, LETTER_HELP } from './coach.js';
import { suggestedLetter } from './store.js';

const DUE_WORD = { exam: 'Exam', presentation: 'Presenting', reading: 'Read by', deadline: 'Due', task: 'Due' };
const WHY_TYPE = { exam: 'it’s an exam', presentation: 'it’s a presentation', deadline: 'it’s graded work', reading: 'assigned reading', task: 'a task' };
export const CONSEQUENCE = { A: 'Serious consequences', B: 'Mild consequences', C: 'No real consequences', D: 'Someone else can do it', E: 'It doesn’t matter' };

export function dueTag(item, today) {
  if (!item.date || item.recur || item.type === 'event') return null;
  const n = diffDays(today, item.date);
  if (n < 0) return tag(`${-n}d late`, 'late');
  const when = `${relDay(item.date, today)}${item.time ? ` ${item.time}` : ''}`;
  return tag(`${DUE_WORD[item.type] || 'Due'} ${when}`, n <= 2 ? 'soon' : '');
}

export function stakeTag(item) {
  return item.weightPct ? tag(`${item.weightPct}% of grade`, 'stake') : null;
}

export function itemMeta(it, today, extra = []) {
  return meta(tag(TYPE_META[it.type]?.word || it.type), dueTag(it, today), stakeTag(it), it.course ? tag(it.course, 'code') : null, extra);
}

// Tick the circle, let the row slide away, then record it.
export function completeRow(li, r, ctx) {
  if (!li || li.classList.contains('completing') || window.matchMedia('(prefers-reduced-motion: reduce)').matches) { ctx.act.complete(r); return; }
  li.classList.add('completing');
  setTimeout(() => ctx.act.complete(r), 480);
}

export function rowEl(r, ctx, { dim = false, movable = true, startable = true } = {}) {
  const it = r.item;
  let sub = null;
  const extra = [];
  if (r.session) {
    sub = `${r.session.label} · ${fmtMin(r.session.minutes)}`;
    if (r.extra) extra.push(tag(`+${r.extra} more today`));
    if (r.overdue) extra.push(tag(`missed ${relDay(r.session.date, ctx.today)}`, 'soon'));
  } else {
    const left = (it.sessions || []).filter((s) => !s.done).length;
    if (left) sub = `${left} study session${left > 1 ? 's' : ''} left`;
    if (it.recur) extra.push(tag('Repeats'));
  }
  if (it.priority === 'D') sub = it.delegateTo ? `With ${it.delegateTo}. Check in on it.` : 'Who can do this? Tap to add a name.';
  const li = h('li', { class: `item${dim ? ' dim' : ''}${it.priority === 'E' ? ' e' : ''}`, 'data-key': r.key },
    h('button', { class: 'check', type: 'button', 'aria-label': `Mark “${it.title}” done`, onclick: () => completeRow(li, r, ctx) }, icon('check')),
    h('div', { class: 'item-main', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id),
      onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
      h('div', { class: 'item-title' }, rank(r.label, r.priority), it.title),
      sub ? h('div', { class: 'item-sub' }, sub) : null,
      itemMeta(it, ctx.today, extra)),
    h('div', { class: 'item-act' },
      movable ? h('div', { class: 'mover' },
        h('button', { class: 'tiny', type: 'button', 'aria-label': `Move “${it.title}” up`, onclick: () => ctx.act.move(r.key, -1) }, icon('up')),
        h('button', { class: 'tiny', type: 'button', 'aria-label': `Move “${it.title}” down`, onclick: () => ctx.act.move(r.key, 1) }, icon('down'))) : null,
      startable ? h('button', { class: 'go', type: 'button', 'aria-label': `Start “${it.title}”`, onclick: () => ctx.focus(r) }, icon('play')) : null));
  return li;
}

// One line that says how many things are waiting for a letter, and opens the sorter.
export function sortBanner(items, ctx) {
  if (!items.length) return null;
  const n = items.length;
  return h('button', { class: 'banner sort', type: 'button', onclick: () => openSorter(ctx) },
    h('span', { class: 'bi' }, icon('sort')),
    h('span', null, h('b', null, `${n} new thing${n > 1 ? 's' : ''} need${n > 1 ? '' : 's'} a letter`), h('span', null, 'One question each. About ten seconds.')),
    h('span', { class: 'btn sm primary' }, 'Sort'));
}

// The sorter: one item at a time, one question, five answers.
export function openSorter(ctx) {
  const today = ctx.today;
  const queue = unsorted(ctx.store.state.items, today).map((it) => it.id);
  const total = queue.length;
  if (!total) return;
  let i = 0;
  const body = h('div', { class: 'sorter' });
  let close = null;

  const draw = () => {
    const items = ctx.store.state.items;
    while (i < queue.length && items.find((x) => x.id === queue[i])?.priority) i++;
    const it = items.find((x) => x.id === queue[i]);
    if (!it) { close?.(); return; }
    const sugg = suggestedLetter(it.type, it.weightPct);
    const why = sugg && it.weightPct ? `${it.weightPct}% of your grade` : sugg ? WHY_TYPE[it.type] : null;
    const rest = queue.slice(i).filter((id) => { const x = items.find((y) => y.id === id); return x && !x.priority && suggestedLetter(x.type, x.weightPct); });
    fill(body,
      h('div', { class: 'count-line' },
        h('span', null, `${i + 1} of ${total}`),
        total <= 12 ? h('span', { class: 'dots', 'aria-hidden': 'true' }, queue.map((_, k) => h('i', { class: k <= i ? 'on' : null }))) : null),
      h('div', { class: 'part' },
        h('h3', { id: 'sort-title' }, it.title),
        itemMeta(it, today)),
      h('p', { class: 'q' }, TIPS.consequences),
      h('div', { class: 'options', role: 'group', 'aria-labelledby': 'sort-title' }, LETTERS.map((L) => h('button', {
        class: `option${sugg === L ? ' suggested' : ''}`, type: 'button', 'data-letter': L,
        'aria-label': `${L}: ${CONSEQUENCE[L]}, ${LETTER_HELP[L].name}${sugg === L ? ' (suggested)' : ''}`,
        onclick: () => { ctx.act.letter(it.id, L); i++; draw(); },
      },
        h('span', { class: `rank big r-${L}` }, L, sugg === L ? penMark() : null),
        h('span', null, h('b', null, CONSEQUENCE[L]), h('span', { class: 'd' }, LETTER_HELP[L].name)),
        sugg === L && why ? hand(`← ${why}`) : null))),
      h('div', { class: 'btn-row' },
        h('button', { class: 'btn quiet', type: 'button', onclick: () => { i++; draw(); } }, 'Skip for now'),
        rest.length > 1 ? h('button', { class: 'btn sm', type: 'button', onclick: () => { ctx.act.acceptSuggestions(rest); close(); } }, `Use the ${rest.length} suggestions`) : null));
  };
  draw();
  close = openSheet('Fill in a letter', body, { cls: 'sort-sheet' });
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
    return h('li', { class: state || null, role: 'button', tabindex: '0', onclick: () => ctx.edit(ev.id) },
      h('span', { class: 't' }, ev.time ? `${ev.time}–${minToTime(end)}` : 'All day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? 'Exam: ' : ev.type === 'presentation' ? 'Presenting: ' : '', ev.title,
        state === 'now' ? h('small', null, 'now') : state === 'next' ? h('small', null, 'next') : null),
      ev.course ? h('span', { class: 'code' }, ev.course) : h('span'));
  }));
}

export function emptyNote(text) {
  return h('p', { class: 'empty' }, text);
}
