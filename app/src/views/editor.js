import { h, fill, append, icon, openSheet, field, TYPE_META, fmtMin, toast } from '../ui.js';
import { fmtShort, relDay, WEEKDAYS, weekday } from '../dates.js';
import { buildPlan, suggestEffort, studyLoad, PLANNED_TYPES, EFFORT_PRESETS } from '../plan.js';
import { LETTERS } from '../agenda.js';
import { LETTER_HELP, TIPS } from '../coach.js';
import { suggestedLetter } from '../store.js';

const RECUR = [['', 'Does not repeat'], ['daily', 'Every day'], ['weekdays', 'Every weekday'], ['weekly', 'Weekly'], ['biweekly', 'Every 2 weeks'], ['monthly', 'Monthly']];

export function openEditor(ctx, id, prefill = {}) {
  const s = ctx.store.state;
  const existing = id ? s.items.find((i) => i.id === id) : null;
  const draft = existing ? structuredClone(existing) : {
    title: '', type: 'task', date: null, time: null, course: '', recur: null, durationMin: 60,
    priority: null, effortMin: 0, notes: '', goalId: null, plan: null, delegateTo: '', sessions: [],
    ...prefill,
  };
  if (!existing && PLANNED_TYPES.includes(draft.type) && !draft.effortMin) draft.effortMin = suggestEffort(draft.type, draft.title);
  let effortTouched = !!(existing || prefill.effortMin);
  let planDirty = !existing;
  const body = h('form', { class: 'editor', onsubmit: (e) => { e.preventDefault(); save(); } });
  let close = null;

  const set = (k, v, rerender = false) => {
    draft[k] = v;
    if (['date', 'effortMin', 'type'].includes(k)) planDirty = true;
    if (rerender) render(); else renderPlan();
  };

  const planBox = h('div', { class: 'plan-box' });

  function renderPlan() {
    planBox.replaceChildren();
    if (!PLANNED_TYPES.includes(draft.type) || draft.recur) return;
    if (!draft.date) {
      planBox.append(h('p', { class: 'field-hint' }, 'Add a date and WilList will plan when to start and split the work into sessions.'));
      return;
    }
    let sessions = draft.sessions || [];
    let shortfall = draft.shortfallMin || 0;
    if (planDirty) {
      const idle = draft.priority === 'D' || draft.priority === 'E';
      const r = idle ? { sessions: sessions.filter((x) => x.done), shortfallMin: 0 }
        : buildPlan({ ...draft, sessions: sessions.filter((x) => x.done) }, s.settings, ctx.today, studyLoad(s.items, draft.id));
      sessions = r.sessions;
      shortfall = r.shortfallMin;
    }
    const first = sessions.find((x) => !x.done);
    append(planBox, [
      h('div', { class: 'plan-head' },
        h('b', null, first ? `Start ${relDay(first.date, ctx.today)}` : sessions.length ? 'All sessions done' : draft.priority === 'D' || draft.priority === 'E' ? 'No study time planned for D/E items' : 'No sessions'),
        sessions.length ? h('span', null, ` · ${sessions.length} session${sessions.length > 1 ? 's' : ''}, ${fmtMin(sessions.reduce((a, x) => a + x.minutes, 0))}`) : null),
      shortfall > 0 ? h('p', { class: 'warn-text' }, icon('alert'), `About ${fmtMin(shortfall)} short. ${TIPS.short}`) : null,
      draft.type === 'exam' ? h('p', { class: 'field-hint' }, TIPS.exam) : null,
      sessions.length ? h('ul', { class: 'sess-list' }, sessions.map((x) => h('li', { class: x.done ? 'is-done' : '' },
        h('input', { type: 'checkbox', checked: x.done, disabled: planDirty && !x.done, 'aria-label': `Session on ${x.date} done`,
          onchange: (e) => { x.done = e.target.checked; x.doneAt = x.done ? ctx.today : null; } }),
        h('span', { class: 'sess-date' }, fmtShort(x.date)),
        h('span', { class: 'sess-label' }, x.label),
        h('span', { class: 'sess-min' }, fmtMin(x.minutes))))) : null,
      existing && !planDirty ? h('button', { type: 'button', class: 'btn sm', onclick: () => { planDirty = true; renderPlan(); } }, icon('undo'), 'Re-plan from today') : null,
      planDirty && existing ? h('p', { class: 'field-hint' }, 'Preview. Saved when you tap Save.') : null]);
  }

  function render() {
    const t = draft.type;
    const planned = PLANNED_TYPES.includes(t);
    const canRepeat = t === 'event' || t === 'task';
    const sugg = suggestedLetter(t);
    const freq = draft.recur?.freq || '';
    fill(body,
      field('What', h('input', { type: 'text', value: draft.title, required: true, autocomplete: 'off', placeholder: 'e.g. Organic chem midterm',
        oninput: (e) => {
          draft.title = e.target.value;
          if (!effortTouched && planned) { draft.effortMin = suggestEffort(t, draft.title); planDirty = true; }
        } })),
      h('div', { class: 'seg', role: 'radiogroup', 'aria-label': 'Type' }, Object.entries(TYPE_META).map(([k, m]) =>
        h('button', { type: 'button', role: 'radio', 'aria-checked': String(k === t), class: k === t ? 'on' : '',
          onclick: () => {
            draft.type = k;
            if (!effortTouched) draft.effortMin = suggestEffort(k, draft.title);
            if (k !== 'event' && k !== 'task') draft.recur = null;
            planDirty = true;
            render();
          } }, icon(m.icon), m.label))),
      h('div', { class: 'two' },
        field(t === 'event' ? 'Date' : t === 'exam' ? 'Exam date' : t === 'presentation' ? 'Presenting on' : 'Due', h('input', { type: 'date', value: draft.date || '', onchange: (e) => set('date', e.target.value || null) })),
        field('Time', h('input', { type: 'time', value: draft.time || '', onchange: (e) => set('time', e.target.value || null) }), t === 'event' ? null : 'Optional')),
      canRepeat ? h('div', { class: 'two' },
        field('Repeats', h('select', { onchange: (e) => {
          const f = e.target.value;
          draft.recur = f ? { freq: f, days: f === 'weekly' || f === 'biweekly' ? (draft.recur?.days?.length ? draft.recur.days : [weekday(draft.date || ctx.today)]) : undefined } : null;
          if (draft.recur && !draft.date) draft.date = ctx.today;
          render();
        } }, RECUR.map(([v, l]) => h('option', { value: v, selected: v === freq }, l)))),
        t === 'event' ? field('Length (min)', h('input', { type: 'number', min: '5', step: '5', value: String(draft.durationMin || 60), oninput: (e) => { draft.durationMin = Number(e.target.value) || 60; } })) : null) : null,
      freq === 'weekly' || freq === 'biweekly' ? h('div', { class: 'days-pick', role: 'group', 'aria-label': 'Days' }, [1, 2, 3, 4, 5, 6, 0].map((d) => {
        const on = draft.recur.days.includes(d);
        return h('button', { type: 'button', class: on ? 'on' : '', 'aria-pressed': String(on), onclick: () => {
          const days = new Set(draft.recur.days);
          if (on && days.size > 1) days.delete(d); else days.add(d);
          draft.recur.days = [...days].sort();
          render();
        } }, WEEKDAYS[d].slice(0, 2).replace(/^./, (c) => c.toUpperCase()));
      })) : null,
      t === 'task' && !draft.recur ? field('Do on (optional)', h('input', { type: 'date', value: draft.plan || '', onchange: (e) => { draft.plan = e.target.value || null; } }), 'Hidden from Today until that day.') : null,
      field('Course / subject', h('input', { type: 'text', value: draft.course || '', placeholder: 'e.g. CHEM110', oninput: (e) => { draft.course = e.target.value.trim() || null; } })),
      h('div', { class: 'field' },
        h('span', { class: 'field-label' }, 'Priority'),
        h('span', { class: 'field-hint' }, TIPS.consequences),
        h('div', { class: 'letters big', role: 'radiogroup', 'aria-label': 'Priority' },
          LETTERS.map((L) => h('button', { type: 'button', role: 'radio', 'aria-checked': String(draft.priority === L),
            class: `letter l-${L}${draft.priority === L ? ' on' : ''}${!draft.priority && sugg === L ? ' suggest' : ''}`,
            onclick: () => { draft.priority = draft.priority === L ? null : L; planDirty = true; render(); } },
            h('b', null, L), h('small', null, LETTER_HELP[L].name)))),
        draft.priority ? h('p', { class: 'field-hint' }, LETTER_HELP[draft.priority].hint) : null),
      draft.priority === 'D' ? field('Delegated to', h('input', { type: 'text', value: draft.delegateTo || '', placeholder: 'Teammate, TA, a tool…', oninput: (e) => { draft.delegateTo = e.target.value; } }), TIPS.delegate) : null,
      planned && !draft.recur ? h('div', { class: 'field' },
        h('span', { class: 'field-label' }, 'How much work, roughly?'),
        h('div', { class: 'presets' }, (EFFORT_PRESETS[t] || []).map(([label, min]) =>
          h('button', { type: 'button', class: `chip-btn${draft.effortMin === min ? ' on' : ''}`, onclick: () => { effortTouched = true; set('effortMin', min, true); } }, `${label} · ${fmtMin(min)}`))),
        h('div', { class: 'inline' },
          h('input', { type: 'number', min: '0', step: '0.5', value: String(Math.round((draft.effortMin / 60) * 10) / 10), 'aria-label': 'Hours of work',
            oninput: (e) => { effortTouched = true; set('effortMin', Math.round(Number(e.target.value || 0) * 60)); } }),
          h('span', null, 'hours total')),
        planBox) : null,
      s.goals.length ? field('Moves this goal forward', h('select', { onchange: (e) => { draft.goalId = e.target.value || null; } },
        h('option', { value: '' }, '—'),
        s.goals.map((g) => h('option', { value: g.id, selected: g.id === draft.goalId }, g.title)))) : null,
      field('Notes', h('textarea', { rows: '2', value: draft.notes || '', oninput: (e) => { draft.notes = e.target.value; } })),
      h('div', { class: 'btn-row sticky' },
        h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add'),
        existing ? h('button', { type: 'button', class: 'btn danger', onclick: () => { close(); ctx.act.remove(existing.id); } }, icon('trash'), 'Delete') : null,
        h('button', { type: 'button', class: 'btn ghost', onclick: () => close() }, 'Cancel')),
    );
    renderPlan();
  }

  function save() {
    if (!draft.title.trim()) { toast('Give it a name first.'); return; }
    draft.title = draft.title.trim();
    if (draft.type === 'event' && !draft.date) draft.date = ctx.today;
    if (existing) ctx.act.saveItem(draft, { replan: planDirty, priorityChanged: draft.priority !== existing.priority });
    else ctx.act.createItem(draft);
    close();
  }

  render();
  close = openSheet(existing ? 'Edit' : 'New item', body);
  return close;
}
