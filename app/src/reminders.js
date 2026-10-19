// In-app reminders. Browsers only allow these while WilList is open, which is
// why the calendar export exists for reminders you can rely on.

import { todayISO, nowHHMM, timeToMin, fmtTime } from './dates.js';
import { scheduleOn, dayRows } from './agenda.js';
import { TIPS } from './coach.js';

function show(title, body) {
  const opts = { body, icon: 'icons/icon-192.png', tag: title };
  if (navigator.serviceWorker?.controller) {
    navigator.serviceWorker.ready.then((reg) => reg.showNotification(title, opts)).catch(() => {});
  } else {
    try { new Notification(title, opts); } catch { /* blocked */ }
  }
}

export function dueReminders(state, now) {
  const today = todayISO(now);
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const out = [];
  for (const ev of scheduleOn(state.items, today)) {
    if (!ev.time) continue;
    const lead = timeToMin(ev.time) - nowMin;
    if (lead >= 0 && lead <= 15) out.push([`${today}|ev|${ev.id}`, `${ev.title} at ${fmtTime(ev.time)}`, lead ? `Starts in ${lead} min.` : 'Starting now.']);
  }
  if (nowHHMM(now) >= state.settings.planTime && state.meta.lastPlanned !== today) {
    out.push([`${today}|plan`, 'Plan tomorrow (2 min)', TIPS.planTonight]);
  }
  if (now.getHours() >= 8 && now.getHours() < 12) {
    const first = dayRows(state.items, today)[0];
    if (first) out.push([`${today}|a1`, `${first.label}: ${first.item.title}`, TIPS.a1]);
  }
  return out;
}

export function startReminders(store) {
  const tick = () => {
    const s = store.state;
    if (!s.settings.notify || !('Notification' in window) || Notification.permission !== 'granted') return;
    const now = new Date();
    const today = todayISO(now);
    const fresh = dueReminders(s, now).filter(([key]) => !s.meta.fired?.[key]);
    if (!fresh.length) return;
    for (const [, title, body] of fresh) show(title, body);
    store.commit((d) => {
      const kept = Object.fromEntries(Object.entries(d.meta.fired || {}).filter(([k]) => k.startsWith(today)));
      for (const [key] of fresh) kept[key] = 1;
      d.meta.fired = kept;
    });
  };
  tick();
  setInterval(tick, 30000);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) tick(); });
}
