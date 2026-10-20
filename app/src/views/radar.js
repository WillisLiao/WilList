import { h, svg, rank, fmtMin, titleRow, panel, openSheet } from '../ui.js';
import { fmtShort, relDay, diffDays, weekday, minToTime, timeToMin, addDays } from '../dates.js';
import { radar, vitalFew, missedSessions } from '../agenda.js';
import { weekStats, calibrations } from '../insights.js';

// Ahead answers: am I ready for what is coming? Each exam or deadline is a peak as
// high as its share of the grade; its study sessions are the steps up its slope, and
// the part already climbed is filled in.

const WD = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const DAYS = 14;
// Peaks with no grade weight get a modest height by kind, drawn dashed so they read as unweighted.
const DEFAULT_WEIGHT = { exam: 12, presentation: 10, deadline: 8, reading: 5 };

function notice(text, label, onclick, cls = '') {
  return h('div', { class: `notice ${cls}`.trim() }, h('span', null, text), h('button', { class: 'btn sm', type: 'button', onclick }, label));
}

// Everything on one day, in a sheet: classes, what's due, what to study.
function openDay(d, ctx) {
  const lines = [];
  for (const ev of d.schedule) {
    const end = ev.time ? minToTime(timeToMin(ev.time) + (ev.durationMin || 60)) : null;
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(ev.id); } },
      h('span', { class: 't num' }, ev.time ? `${ev.time}–${end}` : 'All day'),
      h('span', { class: 'what' }, ev.type === 'exam' ? h('b', null, 'Exam: ') : ev.type === 'presentation' ? h('b', null, 'Present: ') : null, ev.title)));
  }
  for (const it of d.due) {
    lines.push(h('li', { role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(it.id); } },
      h('span', { class: 't num' }, it.time || 'Due'),
      h('span', { class: 'what' }, it.priority ? rank(it.priority) : null, ' ', it.title)));
  }
  for (const sd of d.study) {
    lines.push(h('li', { class: 'study', role: 'button', tabindex: '0', onclick: () => { close(); ctx.edit(sd.item.id); } },
      h('span', { class: 't num' }, fmtMin(sd.minutes)), h('span', { class: 'what' }, `Study: ${sd.item.title}`)));
  }
  const title = `${d.date === ctx.today ? 'Today' : WD[weekday(d.date)]} ${fmtShort(d.date)}`;
  const close = openSheet(title, lines.length ? h('ul', { class: 'day-lines' }, lines) : h('p', { class: 'empty' }, 'Free.'));
}

// Round ticks whose top sits above the largest value.
function topTick(max, step) {
  return Math.max(step * 2, Math.ceil((max + 0.001) / step) * step);
}

function peakData(ctx) {
  // The A's are the mountains; B's stay in the list below.
  return vitalFew(ctx.s.items, ctx.today, DAYS + 6).filter((v) => v.item.priority === 'A').map((v) => {
    const it = v.item;
    const sessions = it.sessions || [];
    return {
      v, it,
      due: diffDays(ctx.today, it.date),
      weight: it.weightPct || DEFAULT_WEIGHT[it.type] || 8,
      weighted: !!it.weightPct,
      steps: sessions.map((x) => (x.done ? 'done' : diffDays(ctx.today, x.date) < 0 ? 'missed' : 'open')),
    };
  });
}

function shortName(it) {
  const t = it.title.replace(/^(the|a)\s+/i, '');
  return t.length > 16 ? `${t.slice(0, 15).trimEnd()}…` : t;
}

// The landscape, drawn at the width it is shown at so text never scales.
function drawPeaks(host, peaks, today) {
  const W = Math.max(280, Math.round(host.clientWidth));
  if (host.dataset.w === String(W)) return;
  host.dataset.w = String(W);
  const lane = 36;
  const right = 8;
  const G = 188;
  const cw = (W - lane - right) / DAYS;
  const x = (i) => lane + (i + 0.5) * cw;
  const yMax = topTick(Math.max(...peaks.map((p) => p.weight), 10), 10);
  // Label rows sit above the plot; a label moves up a row when it would touch the one before it.
  const rowsY = [14, 32, 50];
  const plotTop = 66;
  const y = (w) => G - (w / yMax) * (G - plotTop);
  const root = svg('svg', { width: String(W), height: '216', viewBox: `0 0 ${W} 216`, 'aria-hidden': 'true' });
  // Climbs that began before today run off the left edge of the plot, not over the axis.
  root.append(svg('clipPath', { id: 'plot-clip' }, svg('rect', { x: String(lane), y: '0', width: String(W - lane), height: String(G + 1) })));
  const hills = svg('g', { 'clip-path': 'url(#plot-clip)' });

  for (const t of [yMax / 2, yMax]) {
    root.append(svg('line', { x1: String(lane), x2: String(W - right), y1: String(y(t)), y2: String(y(t)), class: 'grid' }));
    const tx = svg('text', { x: '0', y: String(y(t) + 4), class: 'tick' });
    tx.textContent = `${t}%`;
    root.append(tx);
  }
  const zero = svg('text', { x: '0', y: String(G + 4), class: 'tick' });
  zero.textContent = '0%';
  root.append(zero);

  const lastEnd = [-Infinity, -Infinity, -Infinity];
  const ordered = [...peaks].sort((a, b) => b.weight - a.weight);
  for (const p of ordered) {
    const xa = x(p.due);
    const ya = y(p.weight);
    // A mountain at its due date: the higher the stake, the wider its foot.
    const xl = xa - Math.max(cw * 1.4, (G - ya) * 0.75);
    const xr = xa + Math.max(cw, (G - ya) * 0.45);
    const n = p.steps.length;
    const doneN = p.steps.filter((s) => s === 'done').length;
    const ready = n ? doneN / n : 0;
    const shape = `M${xl},${G} L${xa},${ya} L${xr},${G} Z`;
    const g = svg('g', { class: `peak${p.weighted ? '' : ' unweighted'}${p.v.status === 'behind' || p.v.status === 'short' ? ' behind' : ''}` });
    g.append(svg('path', { d: shape, class: 'hill' }));
    if (ready > 0) {
      const id = `clip-${p.it.id}`;
      const clip = svg('clipPath', { id }, svg('rect', { x: String(xl), y: String(G - (G - ya) * ready), width: String(xr - xl), height: String((G - ya) * ready) }));
      g.append(clip, svg('path', { d: shape, class: 'climbed', 'clip-path': `url(#${id})` }));
    }
    g.append(svg('path', { d: `M${xl},${G} L${xa},${ya} L${xr},${G}`, class: 'edge' }));
    // Sessions as steps up the left slope.
    const slope = Math.hypot(xa - xl, G - ya);
    if (slope / (n + 1) >= 9) p.steps.forEach((st, k) => {
      const f = (k + 1) / (n + 1);
      g.append(svg('circle', { cx: String(xl + (xa - xl) * f), cy: String(G - (G - ya) * f), r: '3.5', class: `step ${st}` }));
    });
    hills.append(g);
  }
  root.append(hills);
  // Labels last, so no hill covers them: nearest peak first.
  for (const p of [...peaks].sort((a, b) => a.due - b.due)) {
    if (p.due >= DAYS) continue;
    const xa = x(p.due);
    const when = p.due === 0 ? 'today' : `${p.due} d`;
    let text = `${shortName(p.it)} · ${when}`;
    let wText = text.length * 6.6;
    let row = rowsY.findIndex((_, r) => xa - wText / 2 > lastEnd[r] + 8);
    if (row < 0) {
      // No room for the name: the countdown alone, and the list below says which.
      text = when;
      wText = text.length * 6.6;
      row = Math.max(0, rowsY.findIndex((_, r) => xa - wText / 2 > lastEnd[r] + 6));
    }
    const lx = Math.max(wText / 2, Math.min(W - wText / 2, xa));
    lastEnd[row] = lx + wText / 2;
    root.append(svg('line', { x1: String(xa), x2: String(xa), y1: String(rowsY[row] + 5), y2: String(y(p.weight) - 4), class: 'leader' }));
    const t = svg('text', { x: String(lx), y: String(rowsY[row]), class: `plabel${p.due <= 2 ? ' soon' : ''}`, 'text-anchor': 'middle' });
    t.textContent = text;
    root.append(t);
  }
  root.append(svg('line', { x1: String(lane), x2: String(W - right), y1: String(G), y2: String(G), class: 'base' }));
  const step = Math.max(2, Math.ceil(54 / cw));
  for (let i = 0; i < DAYS; i += step) {
    const d = addDays(today, i);
    const t = svg('text', { x: String(x(i)), y: String(G + 22), class: 'tick', 'text-anchor': 'middle' });
    t.textContent = i === 0 ? 'Today' : `${WD[weekday(d)]} ${Number(d.slice(8))}`;
    root.append(t);
  }
  host.replaceChildren(root);
}

function peaksChart(ctx) {
  const peaks = peakData(ctx);
  const host = h('div', { class: 'peaks' });
  const desc = peaks.length
    ? peaks.map((p) => `${p.it.title}: ${p.due} days, ${p.weighted ? `${p.weight}% of grade, ` : ''}${p.steps.filter((s) => s === 'done').length} of ${p.steps.length} sessions done`).join('; ')
    : 'No A is due in the next two weeks.';
  if (!peaks.length) return h('div', { class: 'peaks-wrap' }, h('p', { class: 'empty' }, 'Flat ground: no A is due in the next two weeks.'));
  const wrap = h('figure', { class: 'peaks-wrap', role: 'img', 'aria-label': desc }, host);
  const ro = new ResizeObserver(() => drawPeaks(host, peaks, ctx.today));
  ro.observe(host);
  return wrap;
}

// Study planned per day against the daily budget. Each column opens that day.
function loadChart(days, ctx) {
  const budget = ctx.s.settings.perDayMin || 120;
  const top = topTick(Math.max(budget, ...days.map((d) => d.load)) / 60, 1) * 60;
  const pct = (m) => Math.round((m / top) * 1000) / 10;
  const ticks = [];
  for (let m = 0; m <= top; m += 60) ticks.push(m);
  return h('div', { class: 'load', style: { '--b': String(pct(budget)) } },
    h('div', { class: 'load-y', 'aria-hidden': 'true' }, ticks.map((m) => h('span', { style: { bottom: `${pct(m)}%` } }, m ? `${m / 60} h` : '0'))),
    h('div', { class: 'load-plot', role: 'group', 'aria-label': `Study planned per day; budget ${fmtMin(budget)}` },
      ticks.slice(1).map((m) => h('i', { class: 'gridline', style: { bottom: `${pct(m)}%` }, 'aria-hidden': 'true' })),
      h('i', { class: 'budget', 'aria-hidden': 'true' }, h('span', null, `${fmtMin(budget)} budget`)),
      days.map((d) => {
        const wd = weekday(d.date);
        const over = Math.max(0, d.load - budget);
        const due = d.due.length + d.schedule.filter((e) => e.type === 'exam' || e.type === 'presentation').length;
        return h('button', { class: `day-col${d.date === ctx.today ? ' today' : ''}`, type: 'button',
          'aria-label': `${WD[wd]} ${Number(d.date.slice(8))}: ${fmtMin(d.load)} study${due ? `, ${due} due` : ''}`, onclick: () => openDay(d, ctx) },
          h('span', { class: 'bar', 'aria-hidden': 'true' },
            over ? h('i', { class: 'over', style: { height: `${pct(over)}%` } }) : null,
            h('i', { style: { height: `${pct(d.load - over)}%` } })),
          h('span', { class: 'lbl', 'aria-hidden': 'true' }, h('span', null, WD[wd][0]), h('b', { class: 'num' }, String(Number(d.date.slice(8)))), due ? h('i', { class: 'due' }) : null));
      })));
}

function statusPill(v, ctx) {
  if (v.status === 'short') return h('span', { class: 'pill neg' }, 'Short on time');
  if (v.status === 'behind') return h('span', { class: 'pill neg' }, 'Behind');
  if (v.status === 'not-started') return h('span', { class: 'pill' }, `Starts ${relDay(v.startBy, ctx.today)}`);
  if (v.status === 'no-plan') return null;
  if (v.done < v.total && v.startBy === ctx.today) return h('span', { class: 'pill warn' }, 'Start today');
  return h('span', { class: 'pill pos' }, 'On track');
}

function comingRow(v, ctx) {
  const it = v.item;
  const n = diffDays(ctx.today, it.date);
  const canPull = it.priority === 'A' && v.status === 'not-started' && n > 3;
  return h('li', { class: 'vital', role: 'button', tabindex: '0', onclick: () => ctx.edit(it.id), onkeydown: (e) => { if (e.key === 'Enter') ctx.edit(it.id); } },
    h('div', { class: 'min0' },
      h('h3', null, rank(it.priority), it.title),
      h('div', { class: 'vital-sub' },
        v.total ? h('span', { class: 'num' }, `${v.done} of ${v.total} sessions`) : null,
        it.weightPct ? h('span', { class: 'num' }, `${it.weightPct}% of grade`) : null,
        statusPill(v, ctx),
        canPull ? h('button', { class: 'linkish strong', type: 'button', onclick: (e) => { e.stopPropagation(); ctx.act.pullForward(it.id); } }, 'Do one today') : null)),
    h('span', { class: `days num${n <= 2 ? ' soon' : ''}` }, String(n), h('small', null, n === 1 ? ' day' : ' days')));
}

export function renderRadar(ctx) {
  const { s, today } = ctx;
  const days = radar(s.items, today, DAYS, s.settings.perDayMin);
  const vital = vitalFew(s.items, today);
  const missed = missedSessions(s.items, today);
  const over = days.filter((d) => d.over).length;
  const dueCount = days.reduce((a, d) => a + d.due.length, 0);
  const exams = days.reduce((a, d) => a + d.schedule.filter((e) => e.type === 'exam').length, 0);
  const stats = weekStats(s, today);
  const cal = calibrations(s.log, s.settings.calib)[0];
  const stale = s.items.filter((it) => ['C', 'D', 'E'].includes(it.priority) && !it.done && it.type !== 'event' && it.createdAt && diffDays(it.createdAt, today) >= 14);
  // The finding: the nearest thing that isn't on track, else the nearest thing at all.
  const risk = vital.find((v) => v.status === 'behind' || v.status === 'short') || vital.find((v) => v.total && v.done === 0 && diffDays(today, v.item.date) <= 4);
  const sub = risk
    ? `${risk.item.title} in ${diffDays(today, risk.item.date)} days: ${risk.done} of ${risk.total} sessions done.`
    : `${dueCount} due and ${exams} exam${exams === 1 ? '' : 's'} in the next two weeks.`;
  const needs = [
    missed.length ? notice('Behind on study', 'Re-plan', ctx.act.replanMissed, 'bad') : null,
    over ? notice(`${over} day${over > 1 ? 's' : ''} over your study budget`, 'Balance', ctx.act.balance) : null,
    cal ? notice(`${cal.label} takes you ${cal.ratio}× longer`, 'Adjust', () => ctx.act.setCalib(cal.type, cal.ratio)) : null,
    stale.length ? notice(`${stale.length} old C–E item${stale.length > 1 ? 's' : ''}`, 'Review', () => openStale(stale, ctx)) : null,
  ].filter(Boolean);
  return h('div', { class: 'view radar' },
    titleRow(h('h1', null, 'Next 14 days'), sub),
    needs.length ? h('div', { class: 'needs row' }, needs) : null,
    h('div', { class: 'grid' },
      panel('How ready you are', { cls: 'span-12', id: 'peaks-h' }, h('div', { class: 'inner' }, peaksChart(ctx))),
      panel('Coming up', { cls: 'span-7', id: 'coming-h' },
        vital.length ? h('ul', { class: 'vital-list' }, vital.slice(0, 5).map((v) => comingRow(v, ctx)))
          : h('p', { class: 'empty' }, 'Lettered exams and deadlines show up here.')),
      h('div', { class: 'side-col span-5' },
        panel('Study planned', { id: 'load-h' }, loadChart(days, ctx)),
        panel('Last 7 days', { id: 'week-h' },
        h('div', { class: 'kpis' },
          h('div', { class: 'stat' }, h('span', { class: 'kpi-label' }, 'Focused'), h('b', { class: 'kpi-value num' }, fmtMin(stats.focusMin))),
          h('div', { class: 'stat' }, h('span', { class: 'kpi-label' }, 'A’s done'), h('b', { class: 'kpi-value num' }, String(stats.aDone))),
          h('div', { class: 'stat' }, h('span', { class: 'kpi-label' }, 'All done'), h('b', { class: 'kpi-value num' }, String(stats.done))))))));
}

// "Do first things first, and second things not at all."
function openStale(items, ctx) {
  let close = null;
  const list = h('ul', { class: 'mini' }, items.map((it) => h('li', null,
    h('span', { class: 'min0' }, rank(it.priority), ' ', it.title),
    h('div', { class: 'btn-row' },
      h('button', { class: 'btn sm', type: 'button', onclick: (e) => { ctx.act.keep(it.id); e.target.closest('li').remove(); if (!list.children.length) close(); } }, 'Keep'),
      h('button', { class: 'btn sm danger', type: 'button', onclick: (e) => { ctx.act.remove(it.id); e.target.closest('li').remove(); if (!list.children.length) close(); } }, 'Drop')))));
  close = openSheet('Still worth it?', list);
}
