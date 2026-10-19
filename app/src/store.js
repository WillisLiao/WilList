// App state, persisted to localStorage. All changes go through commit() so the
// UI re-renders once per change and destructive changes can be undone.

import { todayISO, diffDays, localeDateOrder } from './dates.js';
import { buildPlan, suggestEffort, studyLoad, PLANNED_TYPES } from './plan.js';

const KEY = 'willist.v1';
export const SCHEMA = 1;

export const DEFAULT_SETTINGS = {
  perDayMin: 120,
  sessionMin: 50,
  bufferDays: 1,
  planTime: '20:30',
  dateOrder: null, // null = follow the device locale
  tips: true,
  notify: false,
  reward: '',
};

export function emptyState() {
  return {
    v: SCHEMA,
    items: [],
    goals: [],
    mdp: '',
    exercise: {},
    worries: [],
    storms: [],
    settings: { ...DEFAULT_SETTINGS },
    meta: { lastPlanned: null, onboarded: false, doneCount: 0, fired: {} },
  };
}

// Accept anything that looks like a saved state and fill in what is missing.
export function normalize(raw) {
  const base = emptyState();
  if (!raw || typeof raw !== 'object') return base;
  const s = { ...base, ...raw };
  s.settings = { ...DEFAULT_SETTINGS, ...(raw.settings || {}) };
  s.meta = { ...base.meta, ...(raw.meta || {}) };
  for (const k of ['items', 'goals', 'worries', 'storms']) s[k] = Array.isArray(raw[k]) ? raw[k] : [];
  s.items = s.items.filter((it) => it && typeof it.id === 'string' && typeof it.title === 'string');
  s.v = SCHEMA;
  return s;
}

export function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

export function dateOrder(state) {
  return state.settings.dateOrder || localeDateOrder();
}

// New letters land in due-date order; the user can re-rank afterwards.
export function defaultOrder(item) {
  return item.date ? diffDays('2000-01-01', item.date) * 1000 + Math.floor(Math.random() * 900) : 9e9 + Date.now() % 1e6;
}

export function suggestedLetter(type) {
  return type === 'exam' || type === 'presentation' || type === 'deadline' ? 'A' : type === 'reading' ? 'B' : null;
}

export function makeItem(fields, settings, today, items = []) {
  const type = fields.type || 'task';
  const it = {
    id: uid(),
    title: fields.title || 'Untitled',
    type,
    course: fields.course || null,
    date: fields.date || null,
    time: fields.time || null,
    durationMin: type === 'event' ? (fields.durationMin || 60) : null,
    recur: fields.recur || null,
    skips: [],
    priority: fields.priority || null,
    order: 0,
    delegateTo: fields.delegateTo || '',
    notes: fields.notes || '',
    // For planned work a parsed duration ("essay due fri 4h") means effort.
    effortMin: PLANNED_TYPES.includes(type)
      ? (fields.effortMin || fields.durationMin || suggestEffort(type, fields.title))
      : 0,
    sessions: [],
    startBy: null,
    shortfallMin: 0,
    plan: fields.plan || null,
    done: false,
    doneAt: null,
    doneDates: [],
    goalId: fields.goalId || null,
    createdAt: today,
  };
  it.order = defaultOrder(it);
  applyPlan(it, settings, today, items);
  return it;
}

// Plans the work that is left around everything else already booked.
// Delegated and eliminated items get no study time of their own.
export function applyPlan(it, settings, today, items = []) {
  if (!PLANNED_TYPES.includes(it.type) || it.recur || it.priority === 'D' || it.priority === 'E') {
    it.sessions = PLANNED_TYPES.includes(it.type) ? (it.sessions || []).filter((x) => x.done) : [];
    it.startBy = it.date;
    it.shortfallMin = 0;
    return it;
  }
  const r = buildPlan(it, settings, today, studyLoad(items, it.id));
  it.sessions = r.sessions;
  it.startBy = r.startBy;
  it.shortfallMin = r.shortfallMin;
  return it;
}

export function createStore(storage = globalThis.localStorage) {
  let state = emptyState();
  let undoSnap = null;
  const subs = new Set();
  try {
    const raw = storage?.getItem(KEY);
    if (raw) state = normalize(JSON.parse(raw));
  } catch {
    state = emptyState();
  }

  const persist = () => {
    try { storage?.setItem(KEY, JSON.stringify(state)); } catch { /* storage full or blocked */ }
  };

  const store = {
    get state() { return state; },
    today: () => todayISO(),
    subscribe(fn) { subs.add(fn); return () => subs.delete(fn); },
    commit(mutator, { undoable = false } = {}) {
      const before = JSON.stringify(state);
      const draft = JSON.parse(before);
      mutator(draft);
      state = normalize(draft);
      undoSnap = undoable ? before : undoSnap;
      persist();
      subs.forEach((fn) => fn(state));
    },
    canUndo: () => !!undoSnap,
    undo() {
      if (!undoSnap) return;
      state = normalize(JSON.parse(undoSnap));
      undoSnap = null;
      persist();
      subs.forEach((fn) => fn(state));
    },
    replace(next) {
      undoSnap = JSON.stringify(state);
      state = normalize(next);
      persist();
      subs.forEach((fn) => fn(state));
    },
  };
  return store;
}

// ---- item actions (pure: they mutate the draft handed to commit) ----

export function findItem(s, id) {
  return s.items.find((it) => it.id === id);
}

export function setLetter(s, id, letter, today) {
  const it = findItem(s, id);
  if (!it) return;
  const wasIdle = it.priority === 'D' || it.priority === 'E';
  it.priority = letter;
  it.order = defaultOrder(it);
  if (today && (letter === 'D' || letter === 'E' || wasIdle)) replan(s, id, today);
}

export function completeRow(s, { itemId, sessionId, recurring }, today) {
  const it = findItem(s, itemId);
  if (!it) return { finishedItem: false };
  s.meta.doneCount = (s.meta.doneCount || 0) + 1;
  if (recurring) {
    it.doneDates = [...new Set([...(it.doneDates || []), today])];
    return { finishedItem: false };
  }
  if (sessionId) {
    const sess = it.sessions.find((x) => x.id === sessionId);
    if (sess) { sess.done = true; sess.doneAt = today; }
    const anyLeft = it.sessions.some((x) => !x.done);
    if (!anyLeft && (it.type === 'deadline' || it.type === 'reading')) {
      it.done = true;
      it.doneAt = today;
      return { finishedItem: true };
    }
    return { finishedItem: false };
  }
  it.done = true;
  it.doneAt = today;
  for (const x of it.sessions || []) if (!x.done) { x.done = true; x.doneAt = today; }
  return { finishedItem: true };
}

// Swap rank with the neighbouring item in the same letter group.
export function moveInList(s, rows, key, dir) {
  const idx = rows.findIndex((r) => r.key === key);
  if (idx < 0) return;
  const me = rows[idx];
  let j = idx + dir;
  while (j >= 0 && j < rows.length && rows[j].item.id === me.item.id) j += dir;
  const other = rows[j];
  if (!other || other.priority !== me.priority) return;
  const a = findItem(s, me.item.id);
  const b = findItem(s, other.item.id);
  if (!a || !b) return;
  if (a.order === b.order) b.order += dir;
  [a.order, b.order] = [b.order, a.order];
}

export function replan(s, id, today) {
  const it = findItem(s, id);
  if (!it) return;
  // Keep finished sessions; everything left (missed or not) is re-spread from today.
  it.sessions = (it.sessions || []).filter((x) => x.done);
  applyPlan(it, s.settings, today, s.items);
}

const FIRST_CLAIM = { A: 0, B: 1, C: 2 };

// Re-spreads all upcoming work. A's get first claim on each day's study budget,
// then B's, then the rest; within a letter, the earliest deadline goes first.
export function replanAll(s, today) {
  const todo = s.items.filter((it) => !it.done && PLANNED_TYPES.includes(it.type) && !it.recur &&
    it.date && diffDays(today, it.date) >= 0);
  for (const it of todo) it.sessions = (it.sessions || []).filter((x) => x.done);
  todo.sort((a, b) => (FIRST_CLAIM[a.priority] ?? 3) - (FIRST_CLAIM[b.priority] ?? 3) || a.date.localeCompare(b.date));
  for (const it of todo) applyPlan(it, s.settings, today, s.items);
  return todo.length;
}
