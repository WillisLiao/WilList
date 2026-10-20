// Quick: a plain checklist for small stuff. No letters, dates or plans, and it
// never touches Today, so the ABCDE list stays about what matters.

import { h, icon, titleRow, panel } from '../ui.js';

// Tick the circle, let the row slide away, then move it to Done.
function tick(li, t, ctx) {
  if (li.classList.contains('completing')) return;
  if (t.done || window.matchMedia('(prefers-reduced-motion: reduce)').matches) { ctx.act.toggleTodo(t.id); return; }
  li.classList.add('completing');
  setTimeout(() => ctx.act.toggleTodo(t.id), 480);
}

function row(t, ctx) {
  const li = h('li', { class: `item todo${t.done ? ' is-done' : ''}` },
    h('button', { class: 'check', type: 'button', 'aria-pressed': String(t.done),
      'aria-label': `${t.done ? 'Untick' : 'Tick off'} “${t.title}”`, onclick: () => tick(li, t, ctx) }, icon('check')),
    h('span', { class: 'item-title' }, t.title),
    h('button', { class: 'tiny', type: 'button', 'aria-label': `Delete “${t.title}”`, onclick: () => ctx.act.removeTodo(t.id) }, icon('x')));
  return li;
}

export function renderQuick(ctx) {
  const open = ctx.s.todos.filter((t) => !t.done);
  const done = ctx.s.todos.filter((t) => t.done && t.doneAt === ctx.today);
  const input = h('input', { id: 'todo-input', type: 'text', autocomplete: 'off', enterkeyhint: 'enter', maxlength: '200',
    placeholder: 'Buy printer ink', 'aria-label': 'New to-do' });
  const form = h('form', { class: 'todo-add', autocomplete: 'off', onsubmit: (e) => {
    e.preventDefault();
    const title = input.value.trim();
    if (title) ctx.act.addTodo(title); else input.focus();
  } },
    h('span', { class: 'blank', 'aria-hidden': 'true' }, icon('plus')),
    input,
    // Keep the keyboard up: tapping Add shouldn't take focus from the field.
    h('button', { class: 'btn sm', type: 'submit', onmousedown: (e) => e.preventDefault() }, 'Add'));
  return h('div', { class: 'view quick' },
    titleRow(h('h1', null, 'Quick list'), open.length ? `${open.length} left.` : done.length ? 'All done.' : 'Small stuff. No letters, no dates.'),
    h('div', { class: 'grid' },
      panel('To do', { cls: 'span-8', id: 'todo-h' }, form,
        open.length ? h('ul', { class: 'todos' }, open.map((t) => row(t, ctx))) : null),
      panel('Done today', { cls: 'span-4', id: 'done-h' },
        done.length ? h('ul', { class: 'todos' }, done.map((t) => row(t, ctx)))
          : h('p', { class: 'small muted' }, 'Ticked items stay here until tomorrow.'))));
}
