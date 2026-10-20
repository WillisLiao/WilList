import { h, fill, append, bubble, openSheet, field, choice, formLabel, TYPE_META, fmtMin, toast } from '../ui.js';
import { fmtShort, relDay, weekday } from '../dates.js';
import { buildPlan, suggestEffort, studyLoad, PLANNED_TYPES, EFFORT_PRESETS } from '../plan.js';
import { LETTERS } from '../agenda.js';
import { TIPS } from '../coach.js';
import { suggestedLetter } from '../store.js';
import { CONSEQUENCE } from '../components.js';

const RECUR = [['', 'Once'], ['daily', 'Daily'], ['weekdays', 'Weekdays'], ['weekly', 'Weekly'], ['biweekly', 'Every 2 weeks'], ['monthly', 'Monthly']];
const DAY_LETTERS = [[1, 'M'], [2, 'T'], [3, 'W'], [4, 'T'], [5, 'F'], [6, 'S'], [0, 'S']];

export function openEditor(ctx, id, prefill = {}) {
  const s = ctx.store.state;
  const existing = id ? s.items.find((i) => i.id === id) : null;
  const draft = existing ? structuredClone(existing) : {
    title: '', type: 'task', date: null, time: null, course: '', recur: null, durationMin: 60,
    priority: null, effortMin: 0, weightPct: null, notes: '', goalId: null, plan: null, delegateTo: '', sessions: [],
    ...prefill,
  };
  if (!existing && PLANNED_TYPES.includes(draft.type) && !draft.effortMin) draft.effortMin = suggestEffort(draft.type, draft.title);
  let effortTouched = !!(existing || prefill.effortMin);
  let planDirty = !existing;
  const body = h('form', { class: 'fields', onsubmit: (e) => { e.preventDefault(); save(); } });
  const planBox = h('div', { class: 'plan-box' });
  let close = null;

  const set = (k, v, rerender = false) => {
    draft[k] = v;
    if (['date', 'effortMin', 'type'].includes(k)) planDirty = true;
    if (rerender) render(); else renderPlan();
  };

  function renderPlan() {
    fill(planBox);
    planBox.hidden = !PLANNED_TYPES.includes(draft.type) || !!draft.recur;
    if (planBox.hidden) return;
    if (!draft.date) {
      append(planBox, [h('p', { class: 'small' }, 'Add a date and WilList works out when to start and splits the work into sessions.')]);
      return;
    }
    const idle = draft.priority === 'D' || draft.priority === 'E';
    let sessions = draft.sessions || [];
    let shortfall = draft.shortfallMin || 0;
    if (planDirty) {
      const r = idle ? { sessions: sessions.filter((x) => x.done), shortfallMin: 0 }
        : buildPlan({ ...draft, sessions: sessions.filter((x) => x.done) }, s.settings, ctx.today, studyLoad(s.items, draft.id));
      sessions = r.sessions;
      shortfall = r.shortfallMin;
    }
    const first = sessions.find((x) => !x.done);
    append(planBox, [
      h('p', null, formLabel('Plan'), ' ',
        h('b', null, first ? `Start ${relDay(first.date, ctx.today)}` : sessions.length ? 'All sessions done' : idle ? 'No study time for D or E items' : 'No sessions'),
        sessions.length ? ` · ${sessions.length} session${sessions.length > 1 ? 's' : ''}, ${fmtMin(sessions.reduce((a, x) => a + x.minutes, 0))}` : ''),
      shortfall > 0 ? h('p', { class: 'small' }, h('b', null, `About ${fmtMin(shortfall)} short. `), TIPS.short) : null,
      draft.type === 'exam' ? h('p', { class: 'small muted' }, TIPS.exam) : null,
      sessions.length ? h('ul', { class: 'sess' }, sessions.map((x) => h('li', { class: x.done ? 'done' : '' },
        h('input', { type: 'checkbox', checked: x.done, disabled: planDirty && !x.done, 'aria-label': `Session on ${x.date} done`,
          onchange: (e) => { x.done = e.target.checked; x.doneAt = x.done ? ctx.today : null; } }),
        h('span', { class: 'mono' }, fmtShort(x.date)),
        h('span', null, x.label),
        h('span', { class: 'mono muted' }, fmtMin(x.minutes))))) : null,
      existing && !planDirty ? h('div', null, h('button', { type: 'button', class: 'btn sm', onclick: () => { planDirty = true; renderPlan(); } }, 'Re-plan from today')) : null,
      planDirty && existing ? h('p', { class: 'small muted' }, 'Preview. Saved when you tap Save.') : null,
    ]);
  }

  function render() {
    const t = draft.type;
    const planned = PLANNED_TYPES.includes(t);
    const canRepeat = t === 'event' || t === 'task';
    const sugg = suggestedLetter(t, draft.weightPct);
    const freq = draft.recur?.freq || '';
    fill(body,
      field('What', h('input', { type: 'text', value: draft.title, required: true, autocomplete: 'off', placeholder: 'Organic chem midterm',
        oninput: (e) => {
          draft.title = e.target.value;
          if (!effortTouched && planned) { draft.effortMin = suggestEffort(t, draft.title); planDirty = true; }
        } })),
      h('div', { class: 'f' }, formLabel('Kind'), choice(Object.entries(TYPE_META).map(([k, m]) => [k, m.label]), t, (k) => {
        draft.type = k;
        if (!effortTouched) draft.effortMin = suggestEffort(k, draft.title);
        if (k !== 'event' && k !== 'task') draft.recur = null;
        planDirty = true;
        render();
      }, { ariaLabel: 'Kind' })),
      h('div', { class: 'two' },
        field(t === 'event' ? 'Date' : t === 'exam' ? 'Exam date' : t === 'presentation' ? 'Presenting on' : 'Due', h('input', { type: 'date', value: draft.date || '', onchange: (e) => set('date', e.target.value || null) })),
        field('Time', h('input', { type: 'time', value: draft.time || '', onchange: (e) => set('time', e.target.value || null) }), t === 'event' ? null : 'Optional')),
      canRepeat ? h('div', { class: 'f' }, formLabel('Repeats'), choice(RECUR, freq, (f) => {
        draft.recur = f ? { freq: f, days: f === 'weekly' || f === 'biweekly' ? (draft.recur?.days?.length ? draft.recur.days : [weekday(draft.date || ctx.today)]) : undefined } : null;
        if (draft.recur && !draft.date) draft.date = ctx.today;
        render();
      }, { ariaLabel: 'Repeats' })) : null,
      freq === 'weekly' || freq === 'biweekly' ? h('div', { class: 'bubbles', role: 'group', 'aria-label': 'Days' }, DAY_LETTERS.map(([d, L]) => {
        const on = draft.recur.days.includes(d);
        return bubble(L, { button: true, filled: on, 'aria-pressed': String(on), 'aria-label': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d], onclick: () => {
          const days = new Set(draft.recur.days);
          if (on && days.size > 1) days.delete(d); else days.add(d);
          draft.recur.days = [...days].sort();
          render();
        } });
      })) : null,
      t === 'event' ? field('Length in minutes', h('input', { type: 'number', min: '5', step: '5', value: String(draft.durationMin || 60), oninput: (e) => { draft.durationMin = Number(e.target.value) || 60; } })) : null,
      t === 'task' && !draft.recur ? field('Do on (optional)', h('input', { type: 'date', value: draft.plan || '', onchange: (e) => { draft.plan = e.target.value || null; } }), 'Stays off Today until that day.') : null,
      h('div', { class: 'two' },
        field('Course', h('input', { type: 'text', value: draft.course || '', placeholder: 'CHEM110', oninput: (e) => { draft.course = e.target.value.trim() || null; } })),
        planned ? field('% of final grade', h('input', { type: 'number', min: '0', max: '100', step: '1', value: draft.weightPct ?? '', placeholder: 'e.g. 25',
          onchange: (e) => { const v = Number(e.target.value); draft.weightPct = v > 0 ? v : null; render(); } }), 'Sets the suggested letter.') : null),
      h('div', { class: 'f' },
        formLabel('Letter: if you skip it, what happens?'),
        h('div', { class: 'letters-pick', role: 'radiogroup', 'aria-label': 'Letter' },
          LETTERS.map((L) => h('button', { type: 'button', role: 'radio', 'aria-checked': String(draft.priority === L),
            onclick: () => { draft.priority = draft.priority === L ? null : L; planDirty = true; render(); } },
            bubble(L, { filled: draft.priority === L, ghost: !draft.priority && sugg === L }),
            h('small', null, CONSEQUENCE[L]))))),
      draft.priority === 'D' ? field('Delegated to', h('input', { type: 'text', value: draft.delegateTo || '', placeholder: 'Teammate, TA, a tool…', oninput: (e) => { draft.delegateTo = e.target.value; } }), TIPS.delegate) : null,
      planned && !draft.recur ? h('div', { class: 'f' },
        formLabel('How much work, roughly?'),
        choice((EFFORT_PRESETS[t] || []).map(([label, min]) => [min, `${label} (${fmtMin(min)})`]), draft.effortMin, (min) => { effortTouched = true; set('effortMin', min, true); }, { ariaLabel: 'Size' }),
        h('div', { class: 'two' },
          h('label', { class: 'f' }, h('span', { class: 'small muted' }, 'or hours'),
            h('input', { type: 'number', min: '0', step: '0.5', value: String(Math.round((draft.effortMin / 60) * 10) / 10),
              oninput: (e) => { effortTouched = true; set('effortMin', Math.round(Number(e.target.value || 0) * 60)); } }))),
        planBox) : null,
      s.goals.length ? field('Moves this goal forward', h('select', { onchange: (e) => { draft.goalId = e.target.value || null; } },
        h('option', { value: '' }, '—'),
        s.goals.map((g) => h('option', { value: g.id, selected: g.id === draft.goalId }, g.title)))) : null,
      field('Notes', h('textarea', { rows: '2', value: draft.notes || '', oninput: (e) => { draft.notes = e.target.value; } })),
      h('div', { class: 'btn-row sticky-actions' },
        h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add'),
        existing ? h('button', { type: 'button', class: 'btn ink', onclick: () => { close(); ctx.act.remove(existing.id); } }, 'Delete') : null,
        h('button', { type: 'button', class: 'btn quiet', onclick: () => close() }, 'Cancel')),
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
