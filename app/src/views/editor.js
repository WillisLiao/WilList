import { h, fill, append, lbl, openSheet, field, choice, TYPE_META, fmtMin, toast } from '../ui.js';
import { fmtShort, relDay, weekday } from '../dates.js';
import { buildPlan, suggestEffort, studyLoad, PLANNED_TYPES, EFFORT_PRESETS } from '../plan.js';
import { LETTERS } from '../agenda.js';
import { TIPS } from '../coach.js';
import { suggestedLetter } from '../store.js';
import { CONSEQUENCE, LETTER_NAME } from '../components.js';

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
    planBox.hidden = !PLANNED_TYPES.includes(draft.type) || !!draft.recur || !draft.date;
    if (planBox.hidden) return;
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
      h('p', null, h('b', null, first ? `Start ${relDay(first.date, ctx.today)}` : sessions.length ? 'All sessions done' : 'No study sessions'),
        sessions.length ? ` · ${sessions.length} session${sessions.length > 1 ? 's' : ''} · ${fmtMin(sessions.reduce((a, x) => a + x.minutes, 0))}` : ''),
      shortfall > 0 ? h('p', { class: 'small hot' }, `${fmtMin(shortfall)} short. ${TIPS.short}`) : null,
      sessions.length ? h('details', null, h('summary', { class: 'small' }, 'Sessions'),
        h('ul', { class: 'sess' }, sessions.map((x) => h('li', { class: x.done ? 'done' : '' },
          h('input', { type: 'checkbox', checked: x.done, disabled: planDirty && !x.done, 'aria-label': `Session on ${x.date} done`,
            onchange: (e) => { x.done = e.target.checked; x.doneAt = x.done ? ctx.today : null; } }),
          h('span', { class: 'num' }, fmtShort(x.date)),
          h('span', null, x.label),
          h('span', { class: 'small muted' }, fmtMin(x.minutes))))),
        existing && !planDirty ? h('button', { type: 'button', class: 'btn sm', onclick: () => { planDirty = true; renderPlan(); } }, 'Re-plan from today') : null) : null,
    ]);
  }

  function render() {
    const t = draft.type;
    const planned = PLANNED_TYPES.includes(t);
    const canRepeat = t === 'event' || t === 'task';
    const sugg = suggestedLetter(t, draft.weightPct);
    const freq = draft.recur?.freq || '';
    const repeat = canRepeat ? [
      h('div', { class: 'f' }, lbl('Repeats'), choice(RECUR, freq, (f) => {
        draft.recur = f ? { freq: f, days: f === 'weekly' || f === 'biweekly' ? (draft.recur?.days?.length ? draft.recur.days : [weekday(draft.date || ctx.today)]) : undefined } : null;
        if (draft.recur && !draft.date) draft.date = ctx.today;
        render();
      }, { ariaLabel: 'Repeats' })),
      freq === 'weekly' || freq === 'biweekly' ? h('div', { class: 'daypick', role: 'group', 'aria-label': 'Days' }, DAY_LETTERS.map(([d, L]) => {
        const on = draft.recur.days.includes(d);
        return h('button', { type: 'button', 'aria-pressed': String(on), 'aria-label': ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d], onclick: () => {
          const days = new Set(draft.recur.days);
          if (on && days.size > 1) days.delete(d); else days.add(d);
          draft.recur.days = [...days].sort();
          render();
        } }, L);
      })) : null,
    ] : null;
    const letters = h('div', { class: 'f' },
      lbl(TIPS.consequences),
      h('div', { class: 'letters-pick options', role: 'radiogroup', 'aria-label': 'Letter' },
        LETTERS.map((L) => h('button', { type: 'button', role: 'radio', class: `option${draft.priority === L ? ' picked' : ''}${!draft.priority && sugg === L ? ' suggested' : ''}`,
          'aria-checked': String(draft.priority === L), 'aria-label': `${L}: ${LETTER_NAME[L]}, ${CONSEQUENCE[L]}`,
          onclick: () => { draft.priority = draft.priority === L ? null : L; planDirty = true; render(); } },
          h('span', { class: `rank big r-${L}` }, L),
          h('b', null, LETTER_NAME[L].split(' ')[0])))));
    fill(body,
      field('What', h('input', { type: 'text', value: draft.title, required: true, autocomplete: 'off', placeholder: 'Organic chem midterm',
        oninput: (e) => {
          draft.title = e.target.value;
          if (!effortTouched && planned) { draft.effortMin = suggestEffort(t, draft.title); planDirty = true; }
        } })),
      h('div', { class: 'f' }, lbl('Kind'), choice(Object.entries(TYPE_META).map(([k, m]) => [k, m.word]), t, (k) => {
        draft.type = k;
        if (!effortTouched) draft.effortMin = suggestEffort(k, draft.title);
        if (k !== 'event' && k !== 'task') draft.recur = null;
        planDirty = true;
        render();
      }, { ariaLabel: 'Kind' })),
      h('div', { class: 'two' },
        field(t === 'event' ? 'Date' : t === 'exam' ? 'Exam date' : 'Due', h('input', { type: 'date', value: draft.date || '', onchange: (e) => set('date', e.target.value || null) })),
        field('Time', h('input', { type: 'time', value: draft.time || '', onchange: (e) => set('time', e.target.value || null) }))),
      t === 'event' ? repeat : null,
      t === 'event' ? field('Minutes', h('input', { type: 'number', min: '5', step: '5', value: String(draft.durationMin || 60), oninput: (e) => { draft.durationMin = Number(e.target.value) || 60; } })) : null,
      planned ? field('% of grade', h('input', { type: 'number', min: '0', max: '100', step: '1', value: draft.weightPct ?? '', placeholder: '25',
        onchange: (e) => { const v = Number(e.target.value); draft.weightPct = v > 0 ? v : null; render(); } })) : null,
      t !== 'event' ? letters : null,
      draft.priority === 'D' ? field('Who', h('input', { type: 'text', value: draft.delegateTo || '', placeholder: 'Teammate, TA…', oninput: (e) => { draft.delegateTo = e.target.value; } })) : null,
      planned && !draft.recur ? planBox : null,
      h('details', { class: 'more-fields' },
        h('summary', null, 'More'),
        h('div', { class: 'fields' },
          field('Course', h('input', { type: 'text', value: draft.course || '', placeholder: 'CHEM110', oninput: (e) => { draft.course = e.target.value.trim() || null; } })),
          planned && !draft.recur ? h('div', { class: 'f' },
            lbl('How much work'),
            choice((EFFORT_PRESETS[t] || []).map(([label, min]) => [min, `${label} · ${fmtMin(min)}`]), draft.effortMin, (min) => { effortTouched = true; set('effortMin', min, true); }, { ariaLabel: 'Size' }),
            h('input', { type: 'number', min: '0', step: '0.5', 'aria-label': 'Hours of work', value: String(Math.round((draft.effortMin / 60) * 10) / 10),
              oninput: (e) => { effortTouched = true; set('effortMin', Math.round(Number(e.target.value || 0) * 60)); } })) : null,
          t === 'task' ? repeat : null,
          t === 'task' && !draft.recur ? field('Do on', h('input', { type: 'date', value: draft.plan || '', onchange: (e) => { draft.plan = e.target.value || null; } })) : null,
          s.goals.length ? field('Goal', h('select', { onchange: (e) => { draft.goalId = e.target.value || null; } },
            h('option', { value: '' }, '—'),
            s.goals.map((g) => h('option', { value: g.id, selected: g.id === draft.goalId }, g.title)))) : null,
          field('Notes', h('textarea', { rows: '2', value: draft.notes || '', oninput: (e) => { draft.notes = e.target.value; } })))),
      h('div', { class: 'btn-row sticky-actions' },
        h('button', { type: 'submit', class: 'btn primary' }, existing ? 'Save' : 'Add'),
        existing ? h('button', { type: 'button', class: 'btn danger', onclick: () => { close(); ctx.act.remove(existing.id); } }, 'Delete') : null),
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
  close = openSheet(existing ? 'Edit' : 'New', body);
  return close;
}
