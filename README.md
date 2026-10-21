# WilList

**Willis's list:** a student planner built on Brian Tracy's ABCDE method.

1. **Add everything.** Tap **+** (or press `/`) and type it the way you'd say it, or import your
   whole semester.
2. **Give each one a letter.** A = serious if skipped, B = mild, C = nothing happens,
   D = someone else can, E = doesn't matter.
3. **Do A1 first.** WilList plans study sessions backwards from every exam and deadline and fits
   today's work between your classes.

Every feature maps to an idea from Tracy's *Phoenix Seminar*: [docs/PRINCIPLES.md](docs/PRINCIPLES.md).

## Five tabs

| | |
|---|---|
| **Today** | Your day in time order: classes as fixed blocks, your A1 card in the first free gap, a line for now, what you finished above it and what won't fit below the end of the day. The greeting says whether it all fits. Flip to **Tomorrow** in the evening to number your A's and lock in the plan. |
| **Quick** | A plain checklist for small stuff: type it, tick it off. No letters, dates or planning, and it stays out of Today. Ticked items clear the next day. |
| **Ahead** | Each A in the next two weeks as a peak, as high as its share of the grade and filled in as far as you've studied; then countdowns, study load against your budget, and the last 7 days. |
| **Goals** | The one goal that matters most, your goals with their next step, and 21 days of starting with an A. |
| **More** | Import semester, coach, Worry Buster, 20 Ideas, Pre-game, principles, calendar export, backup, settings. |

## iPhone and iPad app

`ios/` is a native SwiftUI app for iOS 18 and later (with Liquid Glass on iOS 26).
It is always light: white, with one bright green for ticking off, the A's and the main button, and red only for problems.
It has four tabs:

| | |
|---|---|
| **Today** | A plain checklist under today's date. Type a line, press return, type the next. Tick it off and it slides into Done. |
| **Goals** | Your main goal, what to do first as one large card, then the rest by letter, with the letter on the right of each row. Items still waiting for a letter get a **Letter** button. **Plan tomorrow** and **Bring in a schedule** sit at the bottom; your other goals and 21 days of starting with an A are behind the main goal. |
| **Study** | Today's study sessions, this week's study per day (red where a day has more than your daily study time), and each exam and deadline coming up, with a line only when it needs attention. |
| **More** | Calendar links, study settings, your Claude key and backups. |

Ways in, from the least effort:

- **Calendar links** from Canvas, Moodle, Blackboard, Brightspace, Google or Outlook are read again every time the app opens, so new deadlines appear by themselves.
- **Bring in a schedule** reads any file or photo with Claude (PDF, Word, Excel, PowerPoint, a photo of a printed timetable or whiteboard, pasted text) and lists what it found for you to check before anything is added. It works for any course, job, roster or project. It needs your own Anthropic API key, kept in the iPhone's keychain. Calendar files are read without it.
- **Typing it the way you'd say it**, as on the web.

The planner, the parser, the importer and the Claude request live in `ios/WilListCore`, a Swift package with its own tests: `swift test` in that folder.
`npm run ios` builds the app and installs it on every paired iPhone and iPad that is unlocked and on this Mac's Wi-Fi.
It keeps your plan in the same file the earlier web-based app used, so updating loses nothing.

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
npm run test:e2e   # browser test: npm i --no-save playwright (uses Playwright's Chromium, else your Chrome)
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
ios/          the native app (SwiftUI) and WilListCore, its planner as a tested Swift package
```

Fonts: Instrument Sans and Instrument Serif (SIL OFL, `app/fonts/OFL.txt`).
The visual style was dealt and checked with [taste-skill](https://github.com/Leonxlnx/taste-skill)'s app-screen rules.
