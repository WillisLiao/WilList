# WilList

**Willis's list:** a student planner built on Brian Tracy's ABCDE method.

1. **Add everything.** Tap **+** (or press `/`) and type it the way you'd say it, or import your
   whole semester.
2. **Give each one a letter.** A = serious if skipped, B = mild, C = nothing happens,
   D = someone else can, E = doesn't matter.
3. **Do A1 first.** WilList plans study sessions backwards from every exam and deadline and fits
   today's work between your classes.

Every feature maps to an idea from Tracy's *Phoenix Seminar*: [docs/PRINCIPLES.md](docs/PRINCIPLES.md).

## Four tabs

| | |
|---|---|
| **Today** | Your A1, then the rest of the day in time order. Flip to **Tomorrow** in the evening to number your A's and lock in the plan. |
| **Ahead** | 14 days at a glance: study load against your budget, exams and due dates, countdowns. |
| **Goals** | The one goal that matters most, and the rest with their next step. |
| **More** | Import semester, coach, Worry Buster, 20 Ideas, Pre-game, principles, calendar export, backup, settings. |

## Typing

| You type | WilList reads |
|---|---|
| `Calc midterm fri 2pm 25% #MATH201` | Exam, Friday 2pm, 25% of grade (suggests A), spaced study sessions |
| `HW3 due 10/24 11:59pm` | Homework due that date and time |
| `Calculus lecture mwf 10-10:50am` | Class every Mon/Wed/Fri |
| `Essay draft due in 2 weeks !a1` | Deadline, already A1 |

Dates: `today`, `fri`, `next fri`, `in 3 days`, `10/24`, `oct 24`. Repeats: `daily`, `weekdays`,
`every tue`, `mwf`, `tth`, `every other thu`. Weight: `25%`, `worth 25%`.

## Import

**More → Import semester** reads an `.ics` calendar file (Canvas, Moodle, Blackboard, Google,
Outlook) or a pasted syllabus. You see every line before anything is added, and importing again
only adds or updates what changed. It all runs in your browser.

## Your data

Everything stays in this browser on this device: no account, no server. **More → Backup**
downloads a copy. **More → Add to calendar** exports an `.ics` with alarms for reliable phone
reminders. The optional coach uses your own Anthropic key ([docs/AI.md](docs/AI.md)).

## Run it

No build step, no dependencies:

```sh
npm start          # http://localhost:8080
npm test           # unit tests (Node 18+)
npm run test:e2e   # browser test: npm i --no-save playwright && npx playwright install chromium
```

On a phone, open the site and **Add to Home Screen**: it installs like an app and works offline.
`.github/workflows/pages.yml` publishes `app/` to GitHub Pages on every push to `main`
(one-time setup: **Settings → Pages → Source: GitHub Actions**).

## Layout

```
app/          the website: index.html, styles.css, sw.js, icons/, fonts/, vendor/ (coach SDK)
  src/        parse, importer, plan, timeline, agenda, insights, store, ai, ics, coach
  src/views/  today, radar (Ahead), goals, tools (More), editor, import, coach
tests/        unit tests and a Playwright smoke test
docs/         PRINCIPLES.md (Tracy → app), AI.md (coach)
```

Fonts: Bricolage Grotesque, Nanum Pen Script, IBM Plex Mono (SIL OFL, `app/fonts/OFL.txt`).
