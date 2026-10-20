// Tiny DOM helpers and the shared pieces of the binder: icons, letter chips, pen marks, sheets.
// User text is always added as text nodes, never as HTML.

export function h(tag, props, ...children) {
  const el = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') {
        for (const [sk, sv] of Object.entries(v)) {
          if (sk.startsWith('--')) el.style.setProperty(sk, sv); else el.style[sk] = sv;
        }
      }
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === 'value') el.value = v;
      else if (k === 'checked' || k === 'selected' || k === 'disabled') el[k] = !!v;
      else el.setAttribute(k, v === true ? '' : v);
    }
  }
  append(el, children);
  return el;
}

// Use this instead of el.replaceChildren(...): the DOM would print null as "null".
export function fill(el, ...children) {
  el.replaceChildren();
  return append(el, children);
}

export function append(el, children) {
  for (const c of children.flat(Infinity)) {
    if (c == null || c === false || c === '') continue;
    el.append(c instanceof Node ? c : String(c));
  }
  return el;
}

const NS = 'http://www.w3.org/2000/svg';
export function svg(tag, attrs, ...kids) {
  const el = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs || {})) el.setAttribute(k, v);
  el.append(...kids);
  return el;
}

// 24px line icons. Each is a list of [element, attributes].
const C = (cx, cy, r) => ['circle', { cx, cy, r }];
const P = (d) => ['path', { d }];
const R = (x, y, w, hgt, rx) => ['rect', { x, y, width: w, height: hgt, rx }];
const ICONS = {
  check: [P('M5 12.5l4.5 4.5L19 7.5')],
  plus: [P('M12 5v14M5 12h14')],
  up: [P('M6 15l6-6 6 6')],
  down: [P('M6 9l6 6 6-6')],
  next: [P('M9 5l7 7-7 7')],
  arrow: [P('M5 12h14M13 6l6 6-6 6')],
  x: [P('M6 6l12 12M18 6L6 18')],
  edit: [P('M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4')],
  today: [C(12, 12, 4), P('M12 2.5v2M12 19.5v2M4.6 4.6L6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4L6 18M18 6l1.4-1.4')],
  radar: [C(12, 12, 9), C(12, 12, 4.5), P('M12 12l5.5-5.5'), ['circle', { cx: 12, cy: 12, r: 1.2, class: 'dot' }]],
  plan: [P('M20 14.5A8.5 8.5 0 1 1 9.5 4a6.8 6.8 0 0 0 10.5 10.5z')],
  goals: [P('M5.5 21V4'), P('M5.5 4.5h12l-2.6 4.3 2.6 4.2h-12')],
  tools: [R(3.5, 3.5, 7, 7, 2), R(13.5, 3.5, 7, 7, 2), R(3.5, 13.5, 7, 7, 2), R(13.5, 13.5, 7, 7, 2)],
  import: [P('M12 3.5v11M7.5 10l4.5 4.5 4.5-4.5M4 15.5v2.5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2.5')],
  coach: [P('M6 4.5h12a2.5 2.5 0 0 1 2.5 2.5v7a2.5 2.5 0 0 1-2.5 2.5h-6.5l-4.5 3.5v-3.5H6A2.5 2.5 0 0 1 3.5 14V7A2.5 2.5 0 0 1 6 4.5z'), P('M8 9.5h8M8 12.5h5')],
  worry: [P('M2.8 12.5a9.2 9.2 0 0 1 18.4 0z'), P('M12 12.5v6a2 2 0 0 1-4 0')],
  ideas: [P('M9 18h6M10 21h4'), P('M12 3a6 6 0 0 0-3.6 10.8c.7.6 1.1 1.3 1.1 2.2h5c0-.9.4-1.6 1.1-2.2A6 6 0 0 0 12 3z')],
  pregame: [C(12, 12, 9), C(12, 12, 5), ['circle', { cx: 12, cy: 12, r: 1.6, class: 'dot' }]],
  principles: [P('M5 5a2 2 0 0 1 2-2h12v15H7a2 2 0 0 0-2 2z'), P('M5 20a2 2 0 0 0 2 2h12v-4')],
  calendar: [R(3.5, 5, 17, 15.5, 2.5), P('M3.5 10h17M8 3v4M16 3v4')],
  backup: [R(3, 4, 18, 4.5, 1.2), P('M5 8.5V19a1.5 1.5 0 0 0 1.5 1.5h11A1.5 1.5 0 0 0 19 19V8.5M10 12.5h4')],
  settings: [P('M4 7h9M17 7h3M4 17h3M11 17h9'), C(15, 7, 2), C(9, 17, 2)],
  alert: [C(12, 12, 9), P('M12 7.5v5.5M12 16.4v.1')],
  clock: [C(12, 12, 9), P('M12 7v5l3.2 2')],
  sort: [P('M4 6h10M4 12h7M4 18h4'), P('M17 4v16M14 17l3 3 3-3')],
  school: [P('M2.5 9.5L12 5l9.5 4.5L12 14z'), P('M6.5 11.5v4.5c0 1.4 2.5 3 5.5 3s5.5-1.6 5.5-3v-4.5')],
  people: [C(9, 8, 3.2), P('M3 19.5c.6-3.3 3-5 6-5s5.4 1.7 6 5'), P('M15.5 5.2a3 3 0 0 1 0 5.6M17.5 14.8c1.8.6 3 2.2 3.4 4.7')],
  self: [P('M12 20.5v-8'), P('M12 12.5c0-4.2-3-6.5-7.5-6.5 0 4.2 3 6.5 7.5 6.5z'), P('M12 12.5c0-3.4 2.6-5.5 6.5-5.5 0 3.4-2.6 5.5-6.5 5.5z')],
  stack: [P('M12 3.5l8.5 4.5-8.5 4.5L3.5 8z'), P('M3.5 12.5L12 17l8.5-4.5M3.5 16.5L12 21l8.5-4.5')],
};

export function icon(name) {
  if (name === 'play') {
    return svg('svg', { viewBox: '0 0 24 24', 'aria-hidden': 'true', class: 'ic solid' }, svg('path', { d: 'M7 4.5l13 7.5-13 7.5z' }));
  }
  const parts = (ICONS[name] || ICONS.next).map(([tag, attrs]) => svg(tag, attrs));
  return svg('svg', { viewBox: '0 0 24 24', 'aria-hidden': 'true', class: `ic i-${name}` }, ...parts);
}

export const TYPE_META = {
  task: { label: 'Task', word: 'Task' },
  deadline: { label: 'Homework / due', word: 'Homework' },
  exam: { label: 'Exam / test', word: 'Exam' },
  presentation: { label: 'Presentation', word: 'Presentation' },
  reading: { label: 'Reading', word: 'Reading' },
  event: { label: 'Class / meeting', word: 'Class' },
};

export function fmtMin(min) {
  if (!min) return '0 min';
  const hh = Math.floor(min / 60);
  const mm = min % 60;
  return hh ? (mm ? `${hh}h ${mm}m` : `${hh}h`) : `${mm} min`;
}

// ---- the student's marks ----

// The letter you filled in: "A1", "B", … A's wear the highlighter.
export function rank(text, letter = text?.[0], cls = '') {
  return h('span', { class: `rank r-${letter} ${cls}`.trim() }, text);
}

export function hand(text, cls = '') {
  return h('span', { class: `hand ${cls}`.trim() }, text);
}

// A loose pen circle drawn around whatever it sits in (the parent needs position: relative).
export function penMark() {
  return svg('svg', { class: 'pen-mark', viewBox: '0 0 60 40', preserveAspectRatio: 'none', 'aria-hidden': 'true' },
    svg('path', { d: 'M33 4.5C19 2.5 5.5 9 4.5 19.5 3.5 30 17 36.5 32 35.5 46 34.5 56 27 55 17.5 54 9 42 3.5 27 5.5', 'vector-effect': 'non-scaling-stroke' }));
}

// A small hand-drawn arrow for margin notes.
export function penArrow(dir = 'down') {
  const d = dir === 'right' ? 'M3 13c6-6 15-8 26-4M24 4l5 5-6 3' : 'M4 4c8 1 16 5 20 14M18 15l6 4 2-7';
  return svg('svg', { viewBox: '0 0 34 22', 'aria-hidden': 'true' }, svg('path', { d }));
}

export function meta(...parts) {
  return h('div', { class: 'meta' }, parts);
}

// A piece of meta text; cls is one of soon / late / stake / code.
export function tag(text, cls = '') {
  return text ? h('span', { class: cls || null }, text) : null;
}

export function lbl(text, tagName = 'span', extra = {}) {
  return h(tagName, { class: 'lbl', ...extra }, text);
}

export function progress(done, total, { warn = false, label } = {}) {
  const p = total ? Math.round((done / total) * 100) : 0;
  return h('div', { class: 'progress' },
    h('div', { class: `bar${warn ? ' warn' : ''}`, role: 'progressbar', 'aria-valuemin': '0', 'aria-valuemax': String(total), 'aria-valuenow': String(done), 'aria-label': label || null, style: { '--p': String(p) } }, h('i')),
    h('span', null, label || `${done} of ${total}`));
}

export function sec(title, { count = null, note = null, level = 'h2', id = null } = {}) {
  return h('div', { class: 'sec' },
    h(level, { id }, title),
    note ? h('span', { class: 'note' }, note) : null,
    count != null ? h('span', { class: 'count' }, String(count)) : null);
}

// The coloured divider at the top of every page: a tab at this section's position, then its band.
export function band(tabLabel, ...children) {
  return h('header', { class: 'band' },
    h('div', { class: 'col' }, h('span', { class: 'tab', 'aria-hidden': 'true' }, tabLabel), children));
}

let toastTimer = null;
export function toast(message, { action, ms = 4500 } = {}) {
  const host = document.getElementById('toast');
  clearTimeout(toastTimer);
  fill(host,
    h('span', null, message),
    action ? h('button', { class: 'toast-btn', onclick: () => { host.classList.remove('show'); action.fn(); } }, action.label) : null);
  host.classList.add('show');
  toastTimer = setTimeout(() => host.classList.remove('show'), ms);
}

// A bottom sheet built on <dialog> for focus trapping and Esc-to-close.
export function openSheet(title, body, { onClose, cls = '' } = {}) {
  const dlg = h('dialog', { class: `slip ${cls}`.trim(), 'aria-label': title });
  const close = () => { if (dlg.open) dlg.close(); };
  dlg.append(
    h('div', { class: 'slip-head' },
      h('h2', null, title),
      h('button', { class: 'x', type: 'button', 'aria-label': 'Close', onclick: close }, icon('x'))),
    h('div', { class: 'slip-body' }, body),
  );
  dlg.addEventListener('close', () => { dlg.remove(); onClose?.(); });
  dlg.addEventListener('click', (e) => { if (e.target === dlg) close(); });
  document.body.append(dlg);
  dlg.showModal();
  return close;
}

// An in-page "are you sure?" that resolves true or false. Native confirm() is
// blocked in some installed-app and embedded views, so the app never uses it.
export function ask(title, message, yes, { no = 'Cancel', danger = false } = {}) {
  return new Promise((resolve) => {
    let answer = false;
    let close = null;
    const pick = (v) => { answer = v; close(); };
    const body = h('div', { class: 'fields' },
      h('p', null, message),
      h('div', { class: 'btn-row' },
        h('button', { class: `btn ${danger ? 'danger' : 'primary'}`, type: 'button', onclick: () => pick(true) }, yes),
        h('button', { class: 'btn quiet', type: 'button', onclick: () => pick(false) }, no)));
    close = openSheet(title, body, { cls: 'confirm', onClose: () => resolve(answer) });
  });
}

export function field(label, control, hint) {
  return h('label', { class: 'f' },
    h('span', { class: 'lbl' }, label),
    control,
    hint ? h('span', { class: 'hint' }, hint) : null);
}

// Pill radios: options [[value, label]], current value, onPick(value).
export function choice(options, current, onPick, { ariaLabel } = {}) {
  return h('div', { class: 'choice', role: 'radiogroup', 'aria-label': ariaLabel || null },
    options.map(([v, label]) => h('button', {
      type: 'button', role: 'radio', 'aria-checked': String(v === current), onclick: () => onPick(v),
    }, label)));
}

// Two or three views of the same thing.
export function segmented(options, current, onPick, { ariaLabel, tabs = false } = {}) {
  return h('div', { class: 'seg', role: tabs ? 'tablist' : 'radiogroup', 'aria-label': ariaLabel || null },
    options.map(([v, label]) => h('button', {
      type: 'button', role: tabs ? 'tab' : 'radio', [tabs ? 'aria-selected' : 'aria-checked']: String(v === current), onclick: () => onPick(v),
    }, label)));
}

export function download(filename, text, type) {
  const blob = new Blob([text], { type });
  const url = URL.createObjectURL(blob);
  const a = h('a', { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
