// Bring in a semester: a calendar file (.ics) or pasted text, previewed before anything is added.

import { h, fill, icon, tag, meta, sec, segmented, openSheet, field, toast, fmtMin, TYPE_META } from '../ui.js';
import { fmtShort } from '../dates.js';
import { importICS, parseSyllabus, planImport } from '../importer.js';
import { getKey, structureText } from '../ai.js';
import { dateOrder } from '../store.js';

const HOW = [
  ['Canvas', 'Calendar → Calendar Feed (bottom right). Open the link and save the file.'],
  ['Moodle', 'Calendar → Import or export calendars → Export calendar → All events.'],
  ['Blackboard', 'Calendar → settings or share icon → copy the external calendar (iCal) link. Open it and save.'],
  ['Google', 'On a computer: Settings → your calendar → Integrate calendar → Secret address in iCal format. Open it and save.'],
  ['Outlook', 'Settings → Calendar → Shared calendars → Publish a calendar → ICS link. Open it and save.'],
];

export function openImport(ctx, { tab = 'file' } = {}) {
  const st = { tab, rows: [], past: 0, ignored: 0, text: '', course: '', week1: '', busy: false, source: '', cost: null };
  const body = h('div', { class: 'fields' });
  let close = null;

  const classify = (fields) => {
    const p = planImport(ctx.store.state.items, [fields]);
    return p.adds.length ? 'new' : p.updates.length ? 'update' : 'same';
  };
  const setRows = (rows, source) => {
    st.rows = rows.map((r) => ({ ...r, kind: classify(r.fields) }));
    for (const r of st.rows) if (r.kind === 'same') r.keep = false;
    st.source = source;
    render();
  };

  const fileInput = h('input', { type: 'file', accept: '.ics,text/calendar', class: 'visually-hidden', onchange: async (e) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const text = await f.text();
    const r = importICS(text, ctx.today);
    if (!r.items.length && !r.past) { toast('No events found in that file. Is it an .ics calendar file?'); return; }
    st.past = r.past;
    st.ignored = r.ignored;
    setRows(r.items.map((fields) => ({ fields, keep: true })), f.name);
  } });

  async function readText(withCoach) {
    if (!st.text.trim()) { toast('Paste the syllabus or schedule first.'); return; }
    if (withCoach) {
      st.busy = true;
      render();
      try {
        const r = await structureText(st.text, ctx.today);
        st.cost = r.cost;
        st.past = 0;
        setRows(r.items.map((fields) => ({ fields: { ...fields, course: fields.course || st.course || null }, keep: fields.type !== 'event' && fields.type !== 'task' ? true : !!fields.recur })), 'coach');
      } catch (err) {
        toast(err.message, { ms: 7000 });
      } finally {
        st.busy = false;
        render();
      }
      return;
    }
    const r = parseSyllabus(st.text, { now: ctx.now, dateOrder: dateOrder(ctx.store.state), course: st.course.trim() || null, week1: st.week1 || null });
    st.past = r.past;
    st.cost = null;
    if (!r.rows.length) toast('No dated lines found. Each item needs a date like “Oct 30” or “10/30”, or a week number with “Week 1 starts on”.', { ms: 7000 });
    setRows(r.rows, 'text');
  }

  function preview() {
    if (!st.rows.length) return null;
    const keep = st.rows.filter((r) => r.keep);
    const counts = { new: 0, update: 0, same: 0 };
    for (const r of st.rows) counts[r.kind]++;
    return h('section', { class: 'part' },
      sec('Found', { count: st.rows.length, note: `${counts.new} new · ${counts.update} changed · ${counts.same} already there${st.past ? ` · ${st.past} past, skipped` : ''}` }),
      st.cost ? h('p', { class: 'mono muted' }, `Coach read it: ${st.cost.tokens.toLocaleString()} tokens ≈ $${st.cost.usd.toFixed(3)}`) : null,
      h('p', { class: 'small muted' }, 'Ticked items get added. Tap a tick to skip or keep an item. You can fix anything later.'),
      h('ul', { class: 'pick' }, st.rows.map((r) => {
        const f = r.fields;
        return h('li', { class: r.keep ? 'on' : 'off' },
          h('button', { class: 'check', type: 'button', 'aria-pressed': String(r.keep), 'aria-label': `${r.keep ? 'Skip' : 'Keep'} ${f.title}`, onclick: () => { r.keep = !r.keep; render(); } }, icon('check')),
          h('div', { class: 'min0' },
            h('div', { class: 't' }, f.title),
            meta(
              tag(TYPE_META[f.type]?.word || f.type),
              f.date ? tag(`${fmtShort(f.date)}${f.time ? ` ${f.time}` : ''}`) : null,
              f.recur ? tag('repeats') : null,
              f.weightPct ? tag(`${f.weightPct}%`, 'stake') : null,
              f.effortMin ? tag(fmtMin(f.effortMin)) : null,
              f.course ? tag(f.course, 'code') : null,
              r.kind === 'update' ? tag('changed', 'soon') : r.kind === 'same' ? tag('already there') : null,
              r.approx ? tag('week only, check the day', 'soon') : null)));
      })),
      h('div', { class: 'btn-row sticky-actions' },
        h('button', { class: 'btn primary', type: 'button', disabled: !keep.length, onclick: () => {
          ctx.act.importItems(keep.map((r) => r.fields));
          close();
        } }, `Add ${keep.length} item${keep.length === 1 ? '' : 's'}`),
        h('button', { class: 'btn quiet', type: 'button', onclick: () => { st.rows = []; render(); } }, 'Start over')));
  }

  function render() {
    const tabs = segmented([['file', 'Calendar file'], ['paste', 'Paste text']], st.tab, (k) => { st.tab = k; st.rows = []; render(); }, { ariaLabel: 'Source', tabs: true });
    const fileTab = [
      h('p', null, 'Most course sites and calendars can give you an .ics file with every assignment, quiz and class. Bring it in once; bring it in again later and changed dates update instead of duplicating.'),
      h('ul', { class: 'how' }, HOW.map(([name, how]) => h('li', null, h('b', null, name), h('span', null, how)))),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'button', onclick: () => fileInput.click() }, icon('import'), 'Choose .ics file'), fileInput),
      st.ignored ? h('p', { class: 'small muted' }, `${st.ignored} entries were skipped (no date, or “quiz opens” notices).`) : null,
    ];
    const ta = h('textarea', { class: 'ruled', rows: '8', placeholder: 'Paste a syllabus schedule, a professor’s email, or a list of due dates…',
      value: st.text, oninput: (e) => { st.text = e.target.value; } });
    const pasteTab = [
      ta,
      h('div', { class: 'two' },
        field('Course code', h('input', { type: 'text', value: st.course, placeholder: 'HIST150', oninput: (e) => { st.course = e.target.value; } }), 'Added to everything without one.'),
        field('Week 1 starts on', h('input', { type: 'date', value: st.week1, onchange: (e) => { st.week1 = e.target.value; } }), 'Only needed for “Week 5: Quiz” style schedules.')),
      h('div', { class: 'btn-row' },
        h('button', { class: 'btn primary', type: 'button', disabled: st.busy, onclick: () => readText(false) }, 'Read it'),
        getKey()
          ? h('button', { class: 'btn', type: 'button', disabled: st.busy, onclick: () => readText(true) }, st.busy ? 'The coach is reading…' : 'Read it with the coach')
          : h('span', { class: 'small muted' }, 'Messy text? Turn on the coach in Tools for a smarter read.')),
    ];
    fill(body, tabs, st.rows.length ? null : (st.tab === 'file' ? fileTab : pasteTab), preview());
  }

  render();
  close = openSheet('Bring in your semester', body);
}
