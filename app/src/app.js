import {
  createStore, makeItem, setLetter, completeRow, moveInList, replan, replanAll, applyPlan, applyImport,
  defaultOrder, dateOrder, emptyState, findItem, suggestedLetter,
} from './store.js';
import { quickAdd } from './parse.js';
import { planImport } from './importer.js';
import { dayRows, missedSessions } from './agenda.js';
import { logFocus } from './insights.js';
import { todayISO, fmtRelDay, relDay } from './dates.js';
import { h, fill, bubble, tag, toast, TYPE_META, fmtMin, formLabel } from './ui.js';
import { hintFor, doneLine } from './coach.js';
import { renderToday } from './views/today.js';
import { renderRadar } from './views/radar.js';
import { renderPlan } from './views/planview.js';
import { renderGoals, openGoalSheet } from './views/goals.js';
import { renderTools } from './views/tools.js';
import { openEditor } from './views/editor.js';
import { openImport } from './views/importview.js';
import { openFocus } from './focus.js';
import { startReminders } from './reminders.js';
import { sampleData } from './sample.js';

const store = createStore();
const ui = { radarDays: 14, planTab: 'tonight', dump: '' };
const ROUTES = { today: ['Today', renderToday], radar: ['Radar', renderRadar], plan: ['Plan', renderPlan], goals: ['Goals', renderGoals], tools: ['Tools', renderTools] };
const main = document.getElementById('main');
const today = () => todayISO();

const route = () => (ROUTES[location.hash.slice(1)] ? location.hash.slice(1) : 'today');
const go = (r) => { location.hash = r; };

function ctx() {
  const now = new Date();
  return { store, s: store.state, today: todayISO(now), now, ui, go, edit, editGoal, focus, openImport: () => openImport(ctx()), refresh: render, act };
}

function edit(id, prefill) { openEditor(ctx(), id, prefill); }
function editGoal(id, prefill) { openGoalSheet(ctx(), id, prefill); }
function focus(row) { openFocus(ctx(), row); }

let lastRendered = null;
function render() {
  const r = route();
  const keepScroll = r === lastRendered;
  const y = window.scrollY;
  main.replaceChildren(ROUTES[r][1](ctx()));
  drawNav(r);
  document.body.classList.toggle('no-tips', !store.state.settings.tips);
  document.title = r === 'today' ? 'WilList' : `${ROUTES[r][0]} · WilList`;
  window.scrollTo(0, keepScroll ? y : 0);
  lastRendered = r;
}

function addedMessage(it) {
  if (it.type === 'event') return `Added to your timetable${it.recur ? ', repeating' : ''}: ${it.title}.`;
  const parts = [`Added “${it.title}”.`];
  const open = (it.sessions || []).filter((s) => !s.done);
  if (open.length) parts.push(`Start ${relDay(open[0].date, today())}, ${open.length} session${open.length > 1 ? 's' : ''}.`);
  if (it.shortfallMin > 0) parts.push('Not enough time left at your study budget.');
  if (!it.priority) parts.push('Fill in its letter.');
  return parts.join(' ');
}

function topOrder(s, letter) {
  const orders = s.items.filter((x) => x.priority === letter && !x.done).map((x) => x.order ?? 0);
  return orders.length ? Math.min(...orders) - 1 : 0;
}

const undo = { label: 'Undo', fn: () => store.undo() };

const act = {
  letter(id, L) {
    store.commit((s) => setLetter(s, id, L, today()));
    if (L === 'D') {
      const it = findItem(store.state, id);
      toast(`Who can do “${it?.title}” instead? Add their name.`, { action: { label: 'Add', fn: () => edit(id) } });
    }
  },
  acceptSuggestions(ids) {
    store.commit((s) => {
      for (const id of ids) {
        const it = findItem(s, id);
        if (it && !it.priority) setLetter(s, id, suggestedLetter(it.type, it.weightPct), today());
      }
    }, { undoable: true });
    toast(`${ids.length} letters filled in. Change any of them by opening the item.`, { action: undo });
  },
  complete(row) {
    const t = today();
    let res = null;
    store.commit((s) => { res = completeRow(s, { itemId: row.item.id, sessionId: row.session?.id, recurring: row.recurring }, t); }, { undoable: true });
    const extra = res?.finishedItem && row.session ? ' That was the last session, so it is complete.' : '';
    toast(`${doneLine(store.state.meta.doneCount)}${extra}`, { action: undo });
  },
  move(key, dir, rows) {
    const list = rows || dayRows(store.state.items, today());
    store.commit((s) => moveInList(s, list, key, dir));
  },
  remove(id) {
    const it = findItem(store.state, id);
    store.commit((s) => { s.items = s.items.filter((x) => x.id !== id); }, { undoable: true });
    toast(`Deleted “${it?.title || 'item'}”.`, { action: undo });
  },
  createItem(fields) {
    const s = store.state;
    const it = makeItem(fields, s.settings, today(), s.items);
    if (it.priority && fields.rank === 1) it.order = topOrder(s, it.priority);
    store.commit((d) => { d.items.push(it); d.meta.onboarded = true; });
    toast(addedMessage(it), { action: { label: 'Edit', fn: () => edit(it.id) } });
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
    const unl = items.filter((x) => !x.priority && x.type !== 'event').length;
    toast(`${items.length} added.${unl ? ' Fill in their letters.' : ''}`, { action: undo });
  },
  importItems(incoming) {
    const plan = planImport(store.state.items, incoming);
    store.commit((s) => { applyImport(s, plan, today()); s.meta.onboarded = true; }, { undoable: true });
    go('today');
    toast(`${plan.adds.length} added, ${plan.updates.length} updated${plan.same ? `, ${plan.same} already there` : ''}. Fill in their letters on Today.`, { action: undo, ms: 7000 });
  },
  replanMissed() {
    const t = today();
    store.commit((s) => { for (const m of missedSessions(s.items, t)) replan(s, m.item.id, t); });
    toast('Re-planned from today. No blame, just the next step.');
  },
  balance() {
    let n = 0;
    store.commit((s) => { n = replanAll(s, today()); }, { undoable: true });
    toast(`Re-spread ${n} item${n === 1 ? '' : 's'} around your daily budget, A’s first.`, { action: undo });
  },
  pullForward(id) {
    const t = today();
    store.commit((s) => {
      const it = findItem(s, id);
      const first = it?.sessions?.find((x) => !x.done);
      if (first) { first.date = t; it.sessions.sort((a, b) => a.date.localeCompare(b.date)); }
    });
    toast('One session moved to today. It is on your list.');
  },
  lockPlan() {
    store.commit((s) => { s.meta.lastPlanned = today(); });
    toast('Locked in. Your subconscious works on it while you sleep.');
  },
  setTodayMode(m) { store.commit((s) => { s.settings.todayMode = m; }); },
  keep(id) { store.commit((s) => { const it = findItem(s, id); if (it) it.createdAt = today(); }); },
  setMdp(v) { store.commit((s) => { s.mdp = v; }); toast(v ? 'Major definite purpose saved.' : 'Cleared.'); },
  setExercise(i, v) { store.commit((s) => { s.exercise = { ...(s.exercise || {}), [i]: v }; }); },
  setCoach(convo) { store.commit((s) => { s.coach = convo; }); },
  setCalib(type, ratio) {
    store.commit((s) => { s.settings.calib = { ...(s.settings.calib || {}), [type]: ratio }; });
    toast(`New ${type === 'deadline' ? 'homework' : type} plans will use ${ratio}× the usual estimate.`);
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
    toast('Goal saved. Now give it a next step.');
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
    toast(planChanged ? 'Saved. Upcoming work is re-planned with the new settings.' : 'Settings saved.');
  },
  loadSample() {
    store.commit((s) => {
      const d = sampleData(today(), s.settings);
      s.items.push(...d.items);
      s.goals.push(...d.goals);
      if (!s.mdp) s.mdp = d.mdp;
      s.meta.onboarded = true;
      replanAll(s, today());
    }, { undoable: true });
    go('today');
    toast('Sample week loaded. Change or delete anything.', { action: undo });
  },
  resetAll() {
    store.replace(emptyState());
    toast('Everything erased.', { action: undo });
  },
};

// ---- quick add ----
const form = document.getElementById('qa');
const input = document.getElementById('qa-input');
const preview = document.getElementById('qa-preview');
const REPEAT = { daily: 'Daily', weekdays: 'Weekdays', weekly: 'Weekly', biweekly: 'Every 2 weeks', monthly: 'Monthly' };

function parseInput() {
  return quickAdd(input.value, { now: new Date(), dateOrder: dateOrder(store.state) });
}

function renderPreview() {
  if (!input.value.trim()) { fill(preview); preview.classList.remove('show'); return; }
  const p = parseInput();
  const t = today();
  const hint = store.state.settings.tips ? hintFor(p.hints) : null;
  fill(preview,
    formLabel('Reads as'),
    h('span', { class: 'qa-title' }, p.title),
    tag(TYPE_META[p.type].code),
    p.date ? tag(`${p.recur ? 'from ' : ''}${fmtRelDay(p.date, t)}${p.time ? ` ${p.time}` : ''}`) : null,
    p.recur ? tag(REPEAT[p.recur.freq]) : null,
    p.durationMin ? tag(fmtMin(p.durationMin)) : null,
    p.weightPct ? tag(`${p.weightPct}% of grade`, 'stake') : null,
    p.course ? tag(p.course, 'code') : null,
    p.priority ? bubble(p.priority, { filled: false }) : null,
    hint ? h('span', { class: 'qa-hint' }, hint) : null);
  preview.classList.add('show');
}

input.addEventListener('input', renderPreview);
form.addEventListener('submit', (e) => {
  e.preventDefault();
  if (!input.value.trim()) { input.focus(); return; }
  act.createItem(parseInput());
  input.value = '';
  renderPreview();
});
document.getElementById('qa-more').addEventListener('click', () => {
  const prefill = input.value.trim() ? parseInput() : {};
  input.value = '';
  renderPreview();
  edit(null, prefill);
});
document.addEventListener('keydown', (e) => {
  const tagName = document.activeElement?.tagName;
  if (e.key === '/' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(tagName) && !document.querySelector('dialog[open]')) {
    e.preventDefault();
    input.focus();
  }
  if (e.key === 'Escape' && document.activeElement === input) { input.value = ''; renderPreview(); input.blur(); }
});

// ---- header date + nav ----
const stamp = document.getElementById('formdate');
if (stamp) stamp.textContent = `Form A–E · ${today().slice(5).replace('-', '/')}/${today().slice(2, 4)}`;
const nav = document.getElementById('nav');
function drawNav(current) {
  fill(nav, Object.entries(ROUTES).map(([key, [label]]) => h('a', { href: `#${key}`, 'aria-current': key === current ? 'page' : null },
    bubble('', { filled: key === current }), formLabel(label))));
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
  if (today() !== lastDay || route() === 'today' || route() === 'radar') { lastDay = today(); render(); }
}, 60000);
document.addEventListener('visibilitychange', () => { if (!document.hidden && !document.querySelector('dialog[open]')) render(); });

// Offline support belongs to the installable site (the page that links the manifest),
// not to embedded previews, where service workers aren't available.
if ('serviceWorker' in navigator && location.protocol !== 'file:' && document.querySelector('link[rel="manifest"]')) {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
