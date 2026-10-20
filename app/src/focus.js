// Focus mode: one task and one big bubble that fills in as the session runs.
// Real minutes are logged so WilList can learn how long things actually take.

import { h, icon, rank, fmtMin, ask } from './ui.js';
import { TIPS } from './coach.js';
import { dayRows } from './agenda.js';

const mmss = (sec) => `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`;

export async function openFocus(ctx, row) {
  if (row.priority !== 'A') {
    const aLeft = dayRows(ctx.s.items, ctx.today).filter((r) => r.priority === 'A' && r.item.id !== row.item.id).length;
    if (aLeft && !(await ask('Your A’s come first', `${TIPS.bBeforeA} You still have ${aLeft} A item${aLeft > 1 ? 's' : ''} today.`,
      'Start this anyway', { no: 'Back to my A’s' }))) return;
  }
  const minutes = row.session?.minutes || ctx.s.settings.taskMin || 25;
  const total = minutes * 60;
  let elapsedMs = 0;
  let runningSince = Date.now();
  let wake = null;
  let finished = false;
  let completed = false;

  const active = () => elapsedMs + (runningSince ? Date.now() - runningSince : 0);
  const time = h('span', { class: 'time', role: 'timer' }, mmss(total));
  const ring = h('div', { class: 'ring', 'aria-hidden': 'true' }, time);
  const tip = h('p', { class: 'tip' }, `${TIPS.focus} ${TIPS.start}`);
  const pauseBtn = h('button', { class: 'btn', type: 'button', onclick: () => {
    if (runningSince) { elapsedMs += Date.now() - runningSince; runningSince = null; pauseBtn.replaceChildren('Resume'); }
    else { runningSince = Date.now(); pauseBtn.replaceChildren('Pause'); }
  } }, 'Pause');

  const dlg = h('dialog', { class: 'focus', 'aria-label': `Focus: ${row.item.title}` },
    h('div', { class: 'focus-inner' },
      h('div', { class: 'kicker' }, rank(row.label, row.priority), 'Focus. One thing, until it’s done.'),
      h('h1', { class: 'display' }, row.item.title),
      row.session ? h('p', { class: 'muted' }, `${row.session.label} · ${fmtMin(minutes)}`) : null,
      ring,
      tip,
      h('div', { class: 'btn-row' },
        pauseBtn,
        h('button', { class: 'btn primary', type: 'button', onclick: () => { completed = true; close(); ctx.act.complete(row); } }, icon('check'), 'Done'),
        h('button', { class: 'btn quiet', type: 'button', onclick: () => close() }, 'Stop'))));

  const tick = () => {
    const left = Math.max(0, total - Math.round(active() / 1000));
    ring.style.setProperty('--p', String(Math.min(100, (1 - left / total) * 100)));
    if (!finished) time.textContent = mmss(left);
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
  dlg.addEventListener('close', () => {
    clearInterval(timer);
    wake?.release?.().catch(() => {});
    dlg.remove();
    ctx.act.logFocus(row, active() / 60000, completed);
  });
  document.body.append(dlg);
  dlg.showModal();
  navigator.wakeLock?.request('screen').then((w) => { wake = w; }).catch(() => {});
}

