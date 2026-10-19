// Focus mode: one task, one timer, nothing else on screen.

import { h, icon, fmtMin } from './ui.js';
import { TIPS } from './coach.js';
import { dayRows } from './agenda.js';

const mmss = (sec) => `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;

export function openFocus(ctx, row) {
  if (row.priority !== 'A') {
    const aLeft = dayRows(ctx.s.items, ctx.today).filter((r) => r.priority === 'A' && r.item.id !== row.item.id).length;
    if (aLeft && !confirm(`${TIPS.bBeforeA}\n\nYou still have ${aLeft} A item${aLeft > 1 ? 's' : ''} today. Start this anyway?`)) return;
  }
  const minutes = row.session?.minutes || ctx.s.settings.sessionMin || 50;
  let endAt = Date.now() + minutes * 60000;
  let pausedLeft = null;
  let wake = null;
  let finished = false;

  const time = h('div', { class: 'focus-time', role: 'timer', 'aria-live': 'off' }, mmss(minutes * 60));
  const bar = h('span');
  const tip = h('p', { class: 'focus-tip' }, `${TIPS.focus} ${TIPS.start}`);
  const pauseBtn = h('button', { class: 'btn big', onclick: () => {
    if (pausedLeft == null) { pausedLeft = endAt - Date.now(); pauseBtn.replaceChildren(icon('play'), 'Resume'); }
    else { endAt = Date.now() + pausedLeft; pausedLeft = null; pauseBtn.replaceChildren(icon('pause'), 'Pause'); }
  } }, icon('pause'), 'Pause');

  const dlg = h('dialog', { class: `focus-mode l-${row.priority}`, 'aria-label': `Focus: ${row.item.title}` },
    h('div', { class: 'focus-inner' },
      h('p', { class: 'focus-label' }, h('span', { class: `badge l-${row.priority}` }, row.label), ' Focus'),
      h('h1', null, row.item.title),
      row.session ? h('p', { class: 'focus-sub' }, `${row.session.label} · ${fmtMin(minutes)}`) : null,
      time,
      h('div', { class: 'bar focus-bar' }, bar),
      tip,
      h('div', { class: 'btn-row center' },
        pauseBtn,
        h('button', { class: 'btn primary big', onclick: () => { close(); ctx.act.complete(row); } }, icon('check'), 'Done'),
        h('button', { class: 'btn ghost big', onclick: () => close() }, 'Stop'))));

  const tick = () => {
    const left = Math.max(0, Math.round(((pausedLeft ?? (endAt - Date.now()))) / 1000));
    time.textContent = mmss(left);
    bar.style.width = `${100 - (left / (minutes * 60)) * 100}%`;
    if (left === 0 && !finished) {
      finished = true;
      time.textContent = 'Break';
      tip.textContent = TIPS.breakTime;
      navigator.vibrate?.([200, 100, 200]);
      if ('Notification' in window && Notification.permission === 'granted' && document.hidden) {
        try { new Notification('Session done', { body: TIPS.breakTime }); } catch { /* not allowed here */ }
      }
    }
  };
  const timer = setInterval(tick, 1000);
  function close() { if (dlg.open) dlg.close(); }
  dlg.addEventListener('close', () => { clearInterval(timer); wake?.release?.().catch(() => {}); dlg.remove(); });
  document.body.append(dlg);
  dlg.showModal();
  navigator.wakeLock?.request('screen').then((w) => { wake = w; }).catch(() => {});
}
