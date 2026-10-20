# The coach (optional)

WilList works fully without AI. The coach is an add-on for students who have an Anthropic API
key. It does two things:

1. **Answers questions about your week**, such as "I have three exams next week, where do I start?" or
   "I keep putting off my essay. What do I do right now?". It answers from your actual items and
   dates, in the spirit of Brian Tracy's methods, and ends with one thing you can start in the
   next ten minutes. It coaches *like* Tracy's teaching; it never claims to be him.
2. **Reads messy text into items.** In **More → Import semester → Paste text**, "Read with
   coach" turns a syllabus, a professor's email or a brain dump into dated, typed items with grade
   weights and realistic prep hours. You review every line before anything is added, exactly as
   with the built-in reader.

## Setup

1. Create a key at [console.anthropic.com](https://console.anthropic.com/) → API keys. It starts
   with `sk-ant-`.
2. In WilList: **More → Coach**, paste the key, **Turn on the coach**.

**Remove key** on the same screen deletes it from the browser.

## Privacy

- The key is stored in this browser's local storage under `willist.ai-key`, separate from your
  planner data. It is **never** included in backups and never leaves your device except in requests
  to Anthropic.
- Requests go straight from your browser to `api.anthropic.com`. There is no WilList server.
- What is sent when you ask the coach something: your question, the conversation so far, and a short
  summary of your planner. The summary contains the date and time, your major definite purpose,
  daily study budget, A1-first streak, today's list, lettered items due in the next three weeks
  (title, type, date, course, grade weight), missed sessions, and goal titles. Notes, worries and
  20-idea lists are not sent.
- What is sent when the coach reads text: the text you pasted and today's date.
- Without a key the SDK isn't loaded and no request is ever made.

## Cost

The coach runs on your key, so calls are billed to your Anthropic account. It uses Claude Opus 5.5
at $4 per million input tokens and $20 per million output tokens; cached input is billed at
$0.20 per million to read and $5 per million to write. A typical question costs a few cents.
WilList shows the tokens and cost under every answer. Start a **New conversation** when the
topic changes. Long conversations resend the history on every turn,
mostly from cache.

## How it's built

All of it is in [`app/src/ai.js`](../app/src/ai.js).

- **Model:** `claude-opus-5-5` with `output_config.effort: "medium"`. Answers stream in as they're
  written.
- **Append-only conversations.** The system prompt (the coaching instructions plus your planner as it
  was when the conversation started) is frozen for the life of a conversation. When your planner
  changes, the new summary is appended as a `role: "system"` message after your question instead of
  rewriting the prompt. Assistant turns are stored exactly as returned. This keeps the cached prefix
  valid, so follow-up questions are cheap.
- **Structured reading.** Syllabus reading uses a JSON schema (`output_config.format`), so the reply is
  always a list of items with title, type, date, time, course, grade weight, prep hours and repeat
  days. Each item is checked again in the app before it reaches the preview.
- **Refusals don't dead-end.** Both calls send `fallbacks: "default"` (beta
  `server-side-fallback-2026-07-01`). If the request is declined, Anthropic re-runs it on its
  recommended fallback model instead of failing. When that happens mid-answer, only the fallback's text is
  shown. If the answer is still a refusal, you get a plain message suggesting another way to ask.
- **Errors in plain language.** A bad key, a rate limit or no connection each get a sentence you
  can act on, not a stack trace.

## The vendored SDK

`app/vendor/anthropic-sdk-0.131.0.mjs` is the official
[`@anthropic-ai/sdk`](https://github.com/anthropics/anthropic-sdk-typescript) 0.131.0 (MIT),
bundled for the browser so the site keeps working with no build step. It is loaded with a dynamic
`import()` only after you add a key. To rebuild or upgrade it:

```sh
mkdir sdkbuild && cd sdkbuild
npm init -y
npm i @anthropic-ai/sdk@0.131.0 esbuild
echo "export { default, Anthropic } from '@anthropic-ai/sdk';" > entry.mjs
npx esbuild entry.mjs --bundle --format=esm --platform=browser --minify \
  --legal-comments=eof --outfile=anthropic-sdk.mjs
```

Then copy `anthropic-sdk.mjs` to `app/vendor/anthropic-sdk-<version>.mjs` and keep the two-line
header comment at the top. Update the import path in `app/src/ai.js` and bump `VERSION` in
`app/sw.js` so installed copies pick it up. The service worker caches the bundle on first use, so
it isn't in the `SHELL` list.

## Tests

`tests/ai.test.js` exercises the coach and the reader against a fake `fetch` (including streamed
answers, refusals, fallbacks and the append-only history), so `npm test` never makes a real request or
spends money.
