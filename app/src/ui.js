// Tiny DOM helpers and the answer-sheet primitives (bubbles, tags, slips).
// User text is always added as text nodes, never as HTML.

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
  next: 'M9 5l7 7-7 7',
  x: 'M6 6l12 12M18 6L6 18',
  edit: 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4',
};

export function icon(name) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('aria-hidden', 'true');
  if (name === 'play') {
    svg.setAttribute('class', 'ic solid');
    const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    p.setAttribute('d', 'M6 4l15 8-15 8z');
    svg.append(p);
    return svg;
  }
  svg.setAttribute('class', 'ic');
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  p.setAttribute('d', PATHS[name] || PATHS.next);
  svg.append(p);
  return svg;
}

export const TYPE_META = {
  task: { label: 'Task', code: 'Task' },
  deadline: { label: 'Homework / due', code: 'HW' },
  exam: { label: 'Exam / test', code: 'Exam' },
  presentation: { label: 'Presentation', code: 'Talk' },
  reading: { label: 'Reading', code: 'Read' },
  event: { label: 'Class / meeting', code: 'Class' },
};

export function fmtMin(min) {
  if (!min) return '0 min';
  const hh = Math.floor(min / 60);
  const mm = min % 60;
  return hh ? (mm ? `${hh}h ${mm}m` : `${hh}h`) : `${mm} min`;
}

// ---- answer-sheet primitives ----

export function bubble(letter = '', { filled = false, ghost = false, size = '', button = false, cls = '', ...rest } = {}) {
  const classes = ['bubble', size, filled && 'filled', ghost && 'ghost', cls].filter(Boolean).join(' ');
  return h(button ? 'button' : 'span', { class: classes, type: button ? 'button' : null, 'aria-hidden': button ? null : 'true', ...rest }, letter);
}

// A row of small bubbles: n total, the first `done` filled, the next `bad` drawn as late.
export function pips(total, done, { bad = 0, size = 'sm', label } = {}) {
  const out = [];
  for (let i = 0; i < total; i++) {
    out.push(bubble('', { size, filled: i < done, cls: i >= done && i < done + bad ? 'late' : '' }));
  }
  return h('span', { class: 'pips', role: label ? 'img' : null, 'aria-label': label || null }, out);
}

export function tag(text, cls = '') {
  return text ? h('span', { class: `tag ${cls}`.trim() }, text) : null;
}

export function codeTag(course) {
  return course ? tag(course, 'code') : null;
}

export function formLabel(text, tagName = 'span', extra = {}) {
  return h(tagName, { class: 'form', ...extra }, text);
}

export function sec(title, { count = null, note = null, level = 'h2', id = null } = {}) {
  return h('div', { class: 'sec' },
    h(level, { class: 'form', id }, title),
    note ? h('span', { class: 'note' }, note) : null,
    count != null ? h('span', { class: 'count' }, String(count)) : null);
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

// A tear-off slip built on <dialog> for focus trapping and Esc-to-close.
export function openSheet(title, body, { onClose } = {}) {
  const dlg = h('dialog', { class: 'slip', 'aria-label': title });
  const close = () => { if (dlg.open) dlg.close(); };
  dlg.append(
    h('div', { class: 'slip-head' },
      h('h2', { class: 'display' }, title),
      h('button', { class: 'x', type: 'button', 'aria-label': 'Close', onclick: close }, icon('x'))),
    h('div', { class: 'slip-body' }, body),
  );
  dlg.addEventListener('close', () => { dlg.remove(); onClose?.(); });
  dlg.addEventListener('click', (e) => { if (e.target === dlg) close(); });
  document.body.append(dlg);
  dlg.showModal();
  return close;
}

export function field(label, control, hint) {
  return h('label', { class: 'f' },
    h('span', { class: 'form' }, label),
    control,
    hint ? h('span', { class: 'hint' }, hint) : null);
}

// A set of bubble radios: options [[value, label]], current value, onPick(value).
export function choice(options, current, onPick, { ariaLabel } = {}) {
  return h('div', { class: 'choice', role: 'radiogroup', 'aria-label': ariaLabel || null },
    options.map(([v, label]) => h('button', {
      type: 'button', role: 'radio', 'aria-checked': String(v === current), onclick: () => onPick(v),
    }, bubble('', { filled: v === current }), label)));
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
