// Tiny DOM helpers. User text is always added as text nodes, never as HTML.

export function h(tag, props, ...children) {
  const el = document.createElement(tag);
  if (props) {
    for (const [k, v] of Object.entries(props)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
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

const PATHS = {
  check: 'M5 12.5l4.5 4.5L19 7.5',
  plus: 'M12 5v14M5 12h14',
  up: 'M6 15l6-6 6 6',
  down: 'M6 9l6 6 6-6',
  play: 'M8 5.5v13l11-6.5z',
  x: 'M6 6l12 12M18 6L6 18',
  sun: 'M12 4V2m0 20v-2m8-8h2M2 12h2m13.66-5.66l1.41-1.41M4.93 19.07l1.41-1.41m0-11.32L4.93 4.93m14.14 14.14l-1.41-1.41M12 17a5 5 0 100-10 5 5 0 000 10z',
  radar: 'M12 21a9 9 0 110-18 9 9 0 010 18zm0-4a5 5 0 110-10 5 5 0 010 10zm0-5l6-6',
  plan: 'M8 6h12M8 12h12M8 18h12M3.5 6h.01M3.5 12h.01M3.5 18h.01',
  target: 'M12 21a9 9 0 110-18 9 9 0 010 18zm0-4a5 5 0 110-10 5 5 0 010 10zm0-4a1 1 0 110-2 1 1 0 010 2z',
  tools: 'M14.7 6.3a4 4 0 00-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 005.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z',
  clock: 'M12 21a9 9 0 110-18 9 9 0 010 18zm0-14v5l3 2',
  book: 'M4 5a2 2 0 012-2h13v16H6a2 2 0 00-2 2zm0 0v16M9 7h6',
  exam: 'M9 4h6v3H9zM7 5H5v16h14V5h-2M8.5 12l2 2 4-4M8.5 17h7',
  mic: 'M12 15a3 3 0 003-3V6a3 3 0 10-6 0v6a3 3 0 003 3zm6-3a6 6 0 01-12 0m6 6v3',
  pencil: 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4',
  users: 'M16 19v-1a4 4 0 00-4-4H6a4 4 0 00-4 4v1M9 10a3 3 0 100-6 3 3 0 000 6zm13 9v-1a4 4 0 00-3-3.9M16 4.1a3 3 0 010 5.8',
  dot: 'M12 15a3 3 0 100-6 3 3 0 000 6z',
  undo: 'M9 14L4 9l5-5M4 9h11a5 5 0 010 10h-3',
  trash: 'M4 7h16M10 11v6m4-6v6M6 7l1 13h10l1-13M9 7V4h6v3',
  more: 'M5 12h.01M12 12h.01M19 12h.01',
  calendar: 'M4 6h16v15H4zM4 10h16M9 3v4m6-4v4',
  spark: 'M12 3l2.2 6.8L21 12l-6.8 2.2L12 21l-2.2-6.8L3 12l6.8-2.2z',
  alert: 'M12 9v4m0 4h.01M10.3 3.9L2.4 18a2 2 0 001.7 3h15.8a2 2 0 001.7-3L13.7 3.9a2 2 0 00-3.4 0z',
  pause: 'M8 5v14M16 5v14',
};

export function icon(name, cls = '') {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('aria-hidden', 'true');
  svg.setAttribute('class', `ic ${cls}`.trim());
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  p.setAttribute('d', PATHS[name] || PATHS.dot);
  svg.append(p);
  return svg;
}

export const TYPE_META = {
  task: { label: 'Task', icon: 'check' },
  deadline: { label: 'Homework / due', icon: 'pencil' },
  exam: { label: 'Exam / test', icon: 'exam' },
  presentation: { label: 'Presentation', icon: 'mic' },
  reading: { label: 'Reading', icon: 'book' },
  event: { label: 'Class / meeting', icon: 'users' },
};

export function fmtMin(min) {
  if (!min) return '0m';
  const hh = Math.floor(min / 60);
  const mm = min % 60;
  return hh ? (mm ? `${hh}h ${mm}m` : `${hh}h`) : `${mm}m`;
}

// Stable pastel per course tag.
export function courseChip(course) {
  if (!course) return null;
  let hash = 0;
  for (const ch of course) hash = (hash * 31 + ch.codePointAt(0)) >>> 0;
  return h('span', { class: 'chip course', style: { '--hue': String(hash % 360) } }, course);
}

let toastTimer = null;
export function toast(message, { action, ms = 4500 } = {}) {
  const host = document.getElementById('toast');
  clearTimeout(toastTimer);
  fill(host,
    h('span', null, message),
    action ? h('button', { class: 'toast-btn', onclick: () => { host.classList.remove('show'); action.fn(); } }, action.label) : null,
  );
  host.classList.add('show');
  toastTimer = setTimeout(() => host.classList.remove('show'), ms);
}

// Bottom sheet built on <dialog> for free focus trapping and Esc-to-close.
export function openSheet(title, body, { onClose, wide = false } = {}) {
  const dlg = h('dialog', { class: `sheet${wide ? ' wide' : ''}`, 'aria-label': title });
  const close = () => { if (dlg.open) dlg.close(); };
  dlg.append(
    h('div', { class: 'sheet-head' },
      h('h2', null, title),
      h('button', { class: 'icon-btn', 'aria-label': 'Close', onclick: close }, icon('x'))),
    h('div', { class: 'sheet-body' }, body),
  );
  dlg.addEventListener('close', () => { dlg.remove(); onClose?.(); });
  dlg.addEventListener('click', (e) => { if (e.target === dlg) close(); });
  document.body.append(dlg);
  dlg.showModal();
  return close;
}

export function field(label, control, hint) {
  return h('label', { class: 'field' },
    h('span', { class: 'field-label' }, label),
    control,
    hint ? h('span', { class: 'field-hint' }, hint) : null);
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
