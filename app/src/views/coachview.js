// The coach slip: key setup when there is no key, otherwise a chat about your actual planner.

import { h, fill, openSheet, field, toast } from '../ui.js';
import { getKey, setKey, newConversation, ask, visibleText, MODEL } from '../ai.js';

const STARTERS = [
  'I have three exams next week. Where do I start?',
  'Plan my evening around what is due.',
  'I keep putting off my essay. What do I do right now?',
  'Which of my A’s matters most, and why?',
];

export function openCoach(ctx) {
  const body = h('div', { class: 'fields' });
  let busy = false;

  function setup() {
    const input = h('input', { id: 'coach-key', type: 'password', autocomplete: 'off', placeholder: 'sk-ant-…', spellcheck: 'false' });
    fill(body,
      h('p', null, 'Ask for help planning, in Tracy’s spirit. Uses your own Anthropic API key, billed to you.'),
      h('details', null, h('summary', { class: 'small' }, 'Details'),
        h('ul', { class: 'how' },
          h('li', null, h('b', null, 'Key'), h('span', null, 'console.anthropic.com → API keys.')),
          h('li', null, h('b', null, 'Cost'), h('span', null, 'Shown after every answer.')),
          h('li', null, h('b', null, 'Privacy'), h('span', null, 'Key stays in this browser, never in backups. Questions and a planner summary go to Anthropic.')),
          h('li', null, h('b', null, 'Model'), h('span', null, 'Claude Opus 5.5, with Anthropic’s fallback model if it declines.')))),
      field('API key', input),
      h('div', { class: 'btn-row sticky-actions' },
        h('button', { class: 'btn primary', type: 'button', onclick: () => {
          const v = input.value.trim();
          if (!/^sk-ant-/.test(v)) { toast('Keys start with “sk-ant-”.'); return; }
          setKey(v);
          toast('Coach turned on.');
          chat();
        } }, 'Turn on the coach')));
  }

  function chat() {
    const convo = ctx.store.state.coach || null;
    const log = h('ol', { class: 'chat', 'aria-live': 'polite' });
    const box = h('textarea', { id: 'coach-q', rows: '2', placeholder: 'Ask the coach…', onkeydown: (e) => {
      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(box.value); }
    } });
    const costs = convo?.costs || {};
    if (convo) {
      convo.messages.forEach((m, i) => {
        if (m.role === 'user') log.append(h('li', { class: 'me' }, m.content));
        else if (m.role === 'assistant') {
          log.append(h('li', { class: 'coach' }, h('span', { class: 'who' }, 'coach'), h('div', { class: 'says' }, visibleText(m.content)),
            costs[i] ? h('span', { class: 'cost' }, `${costs[i].tokens.toLocaleString()} tokens ≈ $${costs[i].usd.toFixed(3)}`) : null));
        }
      });
    }
    async function send(q) {
      q = q.trim();
      if (!q || busy) return;
      busy = true;
      box.value = '';
      const s = ctx.store.state;
      const current = s.coach || newConversation(s, ctx.today);
      log.append(h('li', { class: 'me' }, q));
      const says = h('div', { class: 'says' }, '…');
      const costEl = h('span', { class: 'cost' });
      log.append(h('li', { class: 'coach' }, h('span', { class: 'who' }, 'coach'), says, costEl));
      says.scrollIntoView({ block: 'nearest' });
      let streamed = '';
      try {
        const r = await ask(current, q, s, ctx.today, (t) => { streamed += t; says.textContent = streamed; });
        says.textContent = r.text;
        if (r.cost) costEl.textContent = `${r.cost.tokens.toLocaleString()} tokens ≈ $${r.cost.usd.toFixed(3)}`;
        const idx = r.convo.messages.length - 1;
        ctx.act.setCoach({ ...r.convo, costs: { ...(current.costs || {}), [idx]: r.cost } });
      } catch (err) {
        says.textContent = err.message;
        says.classList.add('muted');
      } finally {
        busy = false;
      }
    }
    fill(body,
      h('div', { class: 'meta' },
        h('span', null, `${MODEL} · your key`),
        h('button', { class: 'link', type: 'button', onclick: () => { ctx.act.setCoach(null); chat(); } }, 'New conversation'),
        h('button', { class: 'link', type: 'button', onclick: () => { setKey(''); toast('Coach key removed from this browser.'); setup(); } }, 'Remove key')),
      convo?.messages?.length ? null : h('section', { class: 'part' },
        h('div', { class: 'starters' }, STARTERS.map((q) => h('button', { type: 'button', onclick: () => send(q) }, q))),
        null),
      log,
      h('div', { class: 'composer sticky-actions' }, box,
        h('button', { class: 'btn primary', type: 'button', onclick: () => send(box.value) }, 'Ask')));
    setTimeout(() => box.focus(), 50);
  }

  if (getKey()) chat(); else setup();
  openSheet('Coach', body);
}
