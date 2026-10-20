import {
  createStore, makeItem, setLetter, completeRow, moveInList, replan, replanAll, applyPlan, applyImport,
  defaultOrder, dateOrder, emptyState, findItem, suggestedLetter,
} from './store.js';
import { quickAdd } from './parse.js';
import { planImport } from './importer.js';
import { dayRows, missedSessions } from './agenda.js';
import { logFocus } from './insights.js';
import { todayISO, fmtRelDay, relDay } from './dates.js';
import { h, fill, icon, rank, tag, meta, mark, toast, openSheet, TYPE_META, fmtMin } from './ui.js';
import { hintFor, doneLine } from './coach.js';
import { renderToday } from './views/today.js';
import { renderRadar } from './views/radar.js';
import { renderGoals, openGoalSheet } from './views/goals.js';
import { renderTools } from './views/tools.js';
import { openEditor } from './views/editor.js';
import { openImport } from './views/importview.js';
import { openFocus } from './focus.js';
import { startReminders } from './reminders.js';
import { sampleData } from './sample.js';

const store = createStore();
const ui = { day: 'today' };
// [label, view, nav icon]
const ROUTES = { today: ['Today', renderToday, 'today'], ahead: ['Ahead', renderRadar, 'radar'], goals: ['Goals', renderGoals, 'goals'], more: ['More', renderTools, 'tools'] };
const OLD = { radar: 'ahead', tools: 'more', plan: 'today' };
const main = document.getElementById('main');
const today = () => todayISO();

function route() {
  const hash = location.hash.slice(1);
  if (hash === 'plan') ui.day = 'tomorrow';
  const r = OLD[hash] || hash;
  return ROUTES[r] ? r : 'today';
}
const go = (r) => { location.hash = r; };

function ctx() {
  const now = new Date();
  return { store, s: store.state, today: todayISO(now), now, ui, go, edit, editGoal, focus, quickAdd: openQuickAdd, openImport: () => openImport(ctx()), refresh: render, act };
}

function edit(id, prefill) { openEditor(ctx(), id, prefill); }
function editGoal(id, prefill) { openGoalSheet(ctx(), id, prefill); }
function focus(row) { openFocus(ctx(), row); }

let lastRendered = null;
function render() {
  const r = route();
  const keepScroll = r === lastRendered;
  const y = window.scrollY;
  if (r !== 'today') ui.day = 'today';
  main.replaceChildren(ROUTES[r][1](ctx()));
  document.getElementById('where').textContent = r === 'today' && ui.day === 'tomorrow' ? 'Tomorrow' : ROUTES[r][0];
  drawNav(r);
  document.body.classList.toggle('no-tips', !store.state.settings.tips);
  document.title = r === 'today' ? 'WilList' : `${ROUTES[r][0]} · WilList`;
  window.scrollTo(0, keepScroll ? y : 0);
  lastRendered = r;
}

function addedMessage(it) {
  const open = (it.sessions || []).filter((s) => !s.done);
  return `${it.title}${open.length ? ` · start ${relDay(open[0].date, today())}` : ''}${it.shortfallMin > 0 ? ' · short on time' : ''}`;
}

function topOrder(s, letter) {
  const orders = s.items.filter((x) => x.priority === letter && !x.done).map((x) => x.order ?? 0);
  return orders.length ? Math.min(...orders) - 1 : 0;
}

const undo = { label: 'Undo', fn: () => store.undo() };

const act = {
  letter(id, L) {
    store.commit((s) => setLetter(s, id, L, today()));
    if (L === 'D') toast('Who can do it? Add a name.', { action: { label: 'Add', fn: () => edit(id) } });
  },
  acceptSuggestions(ids) {
    store.commit((s) => {
      for (const id of ids) {
        const it = findItem(s, id);
        if (it && !it.priority) setLetter(s, id, suggestedLetter(it.type, it.weightPct), today());
      }
    }, { undoable: true });
    toast(`${ids.length} letters filled in.`, { action: undo });
  },
  complete(row) {
    const t = today();
    let res = null;
    store.commit((s) => { res = completeRow(s, { itemId: row.item.id, sessionId: row.session?.id, recurring: row.recurring }, t); }, { undoable: true });
    toast(res?.finishedItem && row.session ? 'Done. All sessions finished.' : doneLine(store.state.meta.doneCount), { action: undo });
  },
  move(key, dir, rows) {
    const list = rows || dayRows(store.state.items, today());
    store.commit((s) => moveInList(s, list, key, dir));
  },
  remove(id) {
    const it = findItem(store.state, id);
    store.commit((s) => { s.items = s.items.filter((x) => x.id !== id); }, { undoable: true });
    toast(`Deleted ${it?.title || 'item'}.`, { action: undo });
  },
  createItem(fields) {
    const s = store.state;
    const it = makeItem(fields, s.settings, today(), s.items);
    if (it.priority && fields.rank === 1) it.order = topOrder(s, it.priority);
    store.commit((d) => { d.items.push(it); d.meta.onboarded = true; });
    toast(`Added: ${addedMessage(it)}`, { action: { label: 'Edit', fn: () => edit(it.id) } });
    return it;
  },
  saveItem(draft, { replan: doReplan, priorityChanged }) {
    const t = today();
    store.commit((s) => {
      const i = s.items.findIndex((x) => x.id === draft.id);
      if (i < 0) return;
      const it = structuredClone(draft);
      if (it.type !== 'event') it.durationMin = null;
      if (doReplan || priorityChanged) { it.sessions = (it.sessions || []).filter((x) => x.done); applyPlan(it, s.settings, t, s.items); }
      if (priorityChanged) it.order = defaultOrder(it);
      s.items[i] = it;
    });
    toast('Saved.');
  },
  addMany(lines) {
    const s = store.state;
    const now = new Date();
    const items = [];
    for (const line of lines) {
      const p = quickAdd(line, { now, dateOrder: dateOrder(s) });
      items.push(makeItem(p, s.settings, today(), [...s.items, ...items]));
    }
    store.commit((d) => { d.items.push(...items); d.meta.onboarded = true; }, { undoable: true });
    toast(`${items.length} added.`, { action: undo });
  },
  importItems(incoming) {
    const plan = planImport(store.state.items, incoming);
    store.commit((s) => { applyImport(s, plan, today()); s.meta.onboarded = true; }, { undoable: true });
    go('today');
    toast(`${plan.adds.length} added, ${plan.updates.length} updated.`, { action: undo });
  },
  replanMissed() {
    const t = today();
    store.commit((s) => { for (const m of missedSessions(s.items, t)) replan(s, m.item.id, t); });
    toast('Re-planned from today.');
  },
  balance() {
    let n = 0;
    store.commit((s) => { n = replanAll(s, today()); }, { undoable: true });
    toast(`Re-spread ${n} item${n === 1 ? '' : 's'}, A’s first.`, { action: undo });
  },
  pullForward(id) {
    const t = today();
    store.commit((s) => {
      const it = findItem(s, id);
      const first = it?.sessions?.find((x) => !x.done);
      if (first) { first.date = t; it.sessions.sort((a, b) => a.date.localeCompare(b.date)); }
    });
    toast('One session moved to today.');
  },
  lockPlan() {
    store.commit((s) => { s.meta.lastPlanned = today(); });
    toast('Locked in. Sleep on it.');
  },
  keep(id) { store.commit((s) => { const it = findItem(s, id); if (it) it.createdAt = today(); }); },
  setMdp(v) { store.commit((s) => { s.mdp = v; }); },
  setExercise(i, v) { store.commit((s) => { s.exercise = { ...(s.exercise || {}), [i]: v }; }); },
  setCoach(convo) { store.commit((s) => { s.coach = convo; }); },
  setCalib(type, ratio) {
    store.commit((s) => { s.settings.calib = { ...(s.settings.calib || {}), [type]: ratio }; });
    toast(`Plans now use ${ratio}×.`);
  },
  logFocus(row, minutes, completed) {
    if (minutes < 1) return;
    store.commit((s) => logFocus(s, { itemId: row.item.id, type: row.item.type, title: row.item.title, minutes,
      planned: row.session?.minutes || null, completed, today: today() }));
  },
  saveGoal(g) {
    store.commit((s) => {
      const i = s.goals.findIndex((x) => x.id === g.id);
      if (i >= 0) s.goals[i] = g; else s.goals.push(g);
    });
    toast('Goal saved.');
  },
  removeGoal(id) {
    store.commit((s) => {
      s.goals = s.goals.filter((g) => g.id !== id);
      for (const it of s.items) if (it.goalId === id) it.goalId = null;
    }, { undoable: true });
    toast('Goal deleted.', { action: undo });
  },
  saveWorry(w) {
    store.commit((s) => { const i = s.worries.findIndex((x) => x.id === w.id); if (i >= 0) s.worries[i] = w; else s.worries.push(w); });
  },
  saveStorm(st) {
    store.commit((s) => { const i = s.storms.findIndex((x) => x.id === st.id); if (i >= 0) s.storms[i] = st; else s.storms.push(st); });
  },
  saveSettings(next) {
    const prev = store.state.settings;
    const planChanged = ['perDayMin', 'sessionMin', 'bufferDays'].some((k) => prev[k] !== next[k]);
    store.commit((s) => {
      s.settings = { ...s.settings, ...next };
      if (planChanged) replanAll(s, today());
    });
    toast(planChanged ? 'Saved and re-planned.' : 'Saved.');
  },
  loadSample() {
    store.commit((s) => {
      const d = sampleData(today(), s.settings);
      s.items.push(...d.items);
      s.goals.push(...d.goals);
      if (!s.mdp) s.mdp = d.mdp;
      s.meta.firstDone = { ...d.firstDone, ...s.meta.firstDone };
      s.meta.onboarded = true;
      replanAll(s, today());
    }, { undoable: true });
    go('today');
    toast('Sample loaded.', { action: undo });
  },
  resetAll() {
    store.replace(emptyState());
    toast('Erased.', { action: undo });
  },
};

// ---- quick add: a sheet that stays open so you can empty your head in one go ----
const REPEAT = { daily: 'Daily', weekdays: 'Weekdays', weekly: 'Weekly', biweekly: 'Every 2 weeks', monthly: 'Monthly' };
const EXAMPLES = ['Chem quiz thu 2pm', 'Essay due nov 3 25% #HIST', 'Lab every wed 2-5pm', 'Email TA about regrade'];

function openQuickAdd(initial = '') {
  if (document.getElementById('qa')) { document.getElementById('qa-input').focus(); return; }
  const input = h('input', { id: 'qa-input', class: 'qa-input', type: 'text', enterkeyhint: 'done', spellcheck: 'false', autocomplete: 'off',
    placeholder: 'Chem quiz thu 2pm', value: initial, 'aria-label': 'Write it down' });
  const preview = h('div', { id: 'qa-preview', class: 'qa-preview', 'aria-live': 'polite' });
  const added = h('ul', { class: 'qa-added', 'aria-live': 'polite' });
  const parseInput = () => quickAdd(input.value, { now: new Date(), dateOrder: dateOrder(store.state) });
  const renderPreview = () => {
    if (!input.value.trim()) { fill(preview); preview.classList.remove('show'); return; }
    const p = parseInput();
    const t = today();
    const hint = store.state.settings.tips ? hintFor(p.hints) : null;
    fill(preview,
      p.priority ? rank(p.rank ? `${p.priority}${p.rank}` : p.priority, p.priority) : null,
      h('span', { class: 'qa-title' }, p.title),
      meta(
        tag(TYPE_META[p.type].word),
        p.date ? tag(`${p.recur ? 'from ' : ''}${fmtRelDay(p.date, t)}${p.time ? ` ${p.time}` : ''}`) : null,
        p.recur ? tag(REPEAT[p.recur.freq]) : null,
        p.durationMin ? tag(fmtMin(p.durationMin)) : null,
        p.weightPct ? tag(`${p.weightPct}% of grade`, 'stake') : null,
        p.course ? tag(p.course, 'code') : null),
      hint ? h('span', { class: 'qa-hint' }, hint) : null);
    preview.classList.add('show');
  };
  input.addEventListener('input', renderPreview);
  let close = null;
  const examples = store.state.items.length < 5
    ? h('div', { class: 'examples', 'aria-label': 'Examples' }, EXAMPLES.map((ex) => h('button', { type: 'button', onclick: () => { input.value = ex; renderPreview(); input.focus(); } }, ex)))
    : h('span');
  const form = h('form', { id: 'qa', class: 'qa', autocomplete: 'off', onsubmit: (e) => {
    e.preventDefault();
    if (!input.value.trim()) { input.focus(); return; }
    const it = act.createItem(parseInput());
    added.prepend(h('li', null, icon('check'), h('span', null, addedMessage(it))));
    examples.remove();
    input.value = '';
    renderPreview();
    input.focus();
  } },
    input,
    preview,
    h('div', { class: 'btn-row' },
      h('button', { type: 'submit', class: 'btn primary' }, icon('plus'), 'Add'),
      h('button', { type: 'button', id: 'qa-more', class: 'btn', onclick: () => {
        const prefill = input.value.trim() ? parseInput() : {};
        close();
        edit(null, prefill);
      } }, 'Details')),
    examples,
    added);
  close = openSheet('Add', form, { cls: 'qa-sheet' });
  renderPreview();
  setTimeout(() => input.focus(), 30);
}

const fab = document.getElementById('fab');
fab.prepend(icon('plus'));
fab.addEventListener('click', () => openQuickAdd());
document.addEventListener('keydown', (e) => {
  const tagName = document.activeElement?.tagName;
  if ((e.key === '/' || e.key === 'n') && !e.metaKey && !e.ctrlKey && !['INPUT', 'TEXTAREA', 'SELECT'].includes(tagName) && !document.querySelector('dialog[open]')) {
    e.preventDefault();
    openQuickAdd();
  }
});

// ---- nav: a sidebar on desktop, a tab bar on phones ----
const nav = document.getElementById('nav');
document.querySelector('.brand .mark').replaceWith(mark());
function drawNav(current) {
  fill(nav, Object.entries(ROUTES).map(([key, [label, , ic]]) => h('a', { href: `#${key}`, 'aria-current': key === current ? 'page' : null },
    icon(ic), h('span', null, label))));
}

store.subscribe(render);
window.addEventListener('hashchange', render);
render();
startReminders(store);

// Keep "today" and the Now marker fresh without fighting the user's typing.
let lastDay = today();
setInterval(() => {
  const busy = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement?.tagName) || document.querySelector('dialog[open]');
  if (busy) return;
  if (today() !== lastDay || route() === 'today' || route() === 'ahead') { lastDay = today(); render(); }
}, 60000);
document.addEventListener('visibilitychange', () => { if (!document.hidden && !document.querySelector('dialog[open]')) render(); });

// Offline support belongs to the installable site (the page that links the manifest),
// not to embedded previews, where service workers aren't available.
if ('serviceWorker' in navigator && location.protocol !== 'file:' && document.querySelector('link[rel="manifest"]')) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
