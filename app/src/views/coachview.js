// The coach slip: key setup when there is no key, otherwise a chat about your actual planner.

import { h, fill, sec, openSheet, field, formLabel, toast } from '../ui.js';
import { getKey, setKey, newConversation, ask, visibleText, MODEL } from '../ai.js';
import { openImport } from './importview.js';

const STARTERS = [
  'I have three exams next week. Where do I start?',
  'Plan my evening around what is due.',
  'I keep putting off my essay. What do I do right now?',
  'Which of my A’s matters most, and why?',
];

export function openCoach(ctx) {
  const body = h('div', { class: 'fields' });
  let close = null;
  let busy = false;

  function setup() {
    const input = h('input', { id: 'coach-key', type: 'password', autocomplete: 'off', placeholder: 'sk-ant-…', spellcheck: 'false' });
    fill(body,
      h('p', null, 'The coach reads your planner and answers in the spirit of Brian Tracy’s methods: what to do first, how to break a big task down, what to do when you are behind. It can also read a messy syllabus for you.'),
      h('ul', { class: 'lines' },
        h('li', null, formLabel('Needs'), h('span', { class: 'grow' }, 'An Anthropic API key. Create one at console.anthropic.com → API keys.')),
        h('li', null, formLabel('Costs'), h('span', { class: 'grow' }, 'Billed to your Anthropic account. WilList shows the token count and cost after every answer.')),
        h('li', null, formLabel('Privacy'), h('span', { class: 'grow' }, 'The key stays in this browser and is never in backups. Your question and a summary of your planner go straight from this device to Anthropic.')),
        h('li', null, formLabel('Model'), h('span', { class: 'grow' }, 'Claude Opus 5.5. If it declines a request, Anthropic’s recommended fallback model answers instead.'))),
      field('Your API key', input),
      h('div', { class: 'btn-row sticky-actions' },
        h('button', { class: 'btn primary', type: 'button', onclick: () => {
          const v = input.value.trim();
          if (!/^sk-ant-/.test(v)) { toast('That does not look like an Anthropic key. It starts with “sk-ant-”.'); return; }
          setKey(v);
          toast('Coach turned on.');
          chat();
        } }, 'Turn on the coach'),
        h('button', { class: 'btn quiet', type: 'button', onclick: () => close() }, 'Not now')));
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
          log.append(h('li', { class: 'coach' }, formLabel('Coach'), h('div', { class: 'says' }, visibleText(m.content)),
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
      log.append(h('li', { class: 'coach' }, formLabel('Coach'), says, costEl));
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
        formLabel(`${MODEL} · your key`),
        h('button', { class: 'link', type: 'button', onclick: () => { ctx.act.setCoach(null); chat(); } }, 'New conversation'),
        h('button', { class: 'link', type: 'button', onclick: () => { setKey(''); toast('Coach key removed from this browser.'); setup(); } }, 'Remove key')),
      convo?.messages?.length ? null : h('section', { class: 'part' },
        sec('Try asking'),
        h('div', { class: 'btn-row' }, STARTERS.map((q) => h('button', { class: 'btn sm', type: 'button', onclick: () => send(q) }, q))),
        h('p', { class: 'small' }, 'Or ', h('button', { class: 'link', type: 'button', onclick: () => { close(); openImport(ctx, { tab: 'paste' }); } }, 'let the coach read a syllabus'), '.')),
      log,
      h('div', { class: 'composer sticky-actions' }, box,
        h('button', { class: 'btn primary', type: 'button', onclick: () => send(box.value) }, 'Ask')));
    setTimeout(() => box.focus(), 50);
  }

  if (getKey()) chat(); else setup();
  close = openSheet('Coach', body);
}
