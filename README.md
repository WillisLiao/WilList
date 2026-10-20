# WilList

**Willis's list:** a student planner built on Brian Tracy's ABCDE method.

A to-do app lists everything but doesn't tell you what matters. A calendar shows dates but not
priorities, or when to *start* the exam prep. WilList does both, for high school, college and
grad students:

1. **Get it all in.** Bring in your whole semester from Canvas, Moodle, Blackboard, Google or
   Outlook, paste a syllabus, or type things the way you'd say them: `Chem quiz thu`,
   `Essay due nov 3 25% #HIST`, `Lab every wed 2-5pm`.
2. **Give each one a letter.** A = serious consequences if you skip it, B = should do, C = nice to do,
   D = delegate, E = eliminate. Number your A's: A1, A2, A3. WilList circles a suggestion based on
   the type and the share of your grade; you pick.
3. **Do your A1 first.** WilList works backwards from every exam, presentation, assignment and
   reading to spaced study sessions and a start date, fits today's work into the gaps between your
   classes, and learns how long things really take you.

Every feature maps to an idea from Tracy's *Phoenix Seminar*; see
[docs/PRINCIPLES.md](docs/PRINCIPLES.md).

## What makes it different

- **It reads your semester for you.** A calendar file from your school's LMS or a pasted syllabus
  ("Week 5: Midterm (25%)", "Oct 14 – Essay due") becomes dated, typed items in one step. Re-import
  any time: WilList adds what's new, updates what changed and skips what's already there.
- **The grade decides the letter.** Type `25%` or `worth 10%` and WilList knows a 25% final is not
  a 2% quiz. Anything worth 10% or more is suggested as an A.
- **It starts your studying for you.** Exams get spaced sessions on expanding gaps; essays and
  readings get steady sessions. Planning is load-aware: it fills days with free time before it
  overbooks one, and **Balance my plan** re-spreads everything so A's get first claim.
- **My day.** Switch Today from a list to a timetable: your A1 goes into the first free gap
  between classes, then A2, then the B's, with breaks. Whatever doesn't fit is listed, so you
  decide what to drop instead of finding out at midnight.
- **It learns your pace.** Focus mode logs real minutes. After a few finished sessions the weekly
  review says things like "Reading takes you about 1.4× the plan" and offers to plan that way
  from now on.
- **A1-first streak.** Tracy says a new habit takes about 21 days. Today counts the days in a row
  where the first thing you finished was an A.
- **An optional coach.** Bring your own Anthropic API key and ask "I have three exams next week,
  where do I start?". It answers from your actual items and Tracy's methods, and can read messy
  syllabi the built-in reader can't. See [docs/AI.md](docs/AI.md).

## Screens

| | |
|---|---|
| **Today** (yellow) | Your one thing: the A1, highlighted, with Start and Done. Below it, anything without a letter waits behind a **Sort** button (one item at a time, one question each), then either the list (classes, the rest of your A's and B's, later, delegated, done today) or **My day** (a time-blocked timetable). B's stay dimmed while any A is open. |
| **Radar** (blue) | A chart of the next 14 (or 30) days: study load per day against your budget, with exams and due dates marked on top. Then "the vital few" with countdowns and progress, and every day in detail. **Balance my plan** re-spreads all work so A's get first claim on each day. |
| **Plan** (night) | *Tonight*: a five-step evening ritual (empty your head, letter everything, look at tomorrow, number your A's, lock it in). *This week*: what you finished and focused, your real pace, the next 7 days, important-not-urgent work, goals, clean-up, balance. |
| **Goals** (green) | Your major definite purpose as the headline, goals in three balanced areas, and Tracy's seven questions. |
| **Tools** (coral) | Bring in your semester, Coach, Worry Buster, 20 Ideas, Pre-game (mental rehearsal before an exam or talk), the Principles library, calendar export, backup, settings. |

The black **+** button (or the `/` key) opens *Write it down* from anywhere.

## Quick-add cheat sheet

| You type | WilList understands |
|---|---|
| `Calc midterm fri 2pm 25% #MATH201` | Exam on Friday at 2pm, 25% of the grade (suggested A), ~8h of prep over spaced sessions |
| `HW3 due 10/24 11:59pm` | Homework due on that date and time |
| `Calculus lecture mwf 10-10:50am` | Class every Mon/Wed/Fri, 10:00–10:50 |
| `Advisor sync every other thu 3pm` | Every two weeks |
| `Read Smith 2019 paper by next mon` | Reading, due Monday of next week |
| `Essay draft due in 2 weeks !a1` | Deadline, already lettered A1 |
| `Study 2h for chem quiz oct 22` | 2 hours of prep for the quiz |

Dates: `today`, `tonight`, `tomorrow`, `fri`, `next fri`, `in 3 days`, `10/24`, `oct 24`, `24 oct`, `2026-10-24`.
Repeats: `daily`, `weekdays`, `weekly`, `every tue`, `every mon and wed`, `tuesdays`, `mwf`, `tth`, `every other thu`, `monthly`.
Grade weight: `25%`, `worth 25%`, `(20%)`.

## Bring in your semester

**Tools → Bring in your semester** has two tabs:

- **Calendar file.** Download your calendar as an `.ics` file (the screen shows where to find it in
  Canvas, Moodle, Blackboard, Google and Outlook) and choose it. Repeating events, time zones and
  cancelled occurrences are handled. "Quiz opens" notices and past events are skipped.
- **Paste text.** Paste a syllabus schedule, a professor's email or a list of due dates. Set a
  course code and, for "Week 5: Quiz" style schedules, the date Week 1 starts. Every line is
  previewed with a keep/skip tick before anything is added.

Both run entirely in your browser. "Read it with the coach" sends the pasted text to Claude and
only appears once you've added a key.

## Reminders

Browsers only allow notifications while the page is open, so WilList offers two options:

- **Tools → Add to calendar** downloads an `.ics` file containing repeating classes, exams, presentations
  and deadlines (with alarms), plus your study sessions and start days. Import it into Apple, Google or
  Outlook calendar for reminders you can rely on. It's a snapshot: export again after big changes.
- **Settings → Remind me while WilList is open** shows classes 15 minutes ahead, your evening plan time
  and your morning A1.

## Your data

Everything lives in your browser's local storage on your device. There is no account and no server.
Use **Tools → Backup & data** to download a backup or move to another device. The coach's API key
is stored separately and is never included in backups.

## Design

WilList is a ring binder. Each section is a coloured divider: its tab sticks up at its own
position (Today on the left, Tools on the right, like real staggered dividers), its band holds
that page's one big thing, and the work sits on plain paper below. So you always know where you
are, and each page leads with one thing: your A1, the load chart, tonight's ritual, your
purpose, the semester import.

The only marks on the paper are the ones a student makes: a yellow highlighter on the A's, blue
pen notes in the margin (the suggested letter is circled in pen), and a tick that draws itself
when something's done. Focus mode turns the lights down to one task and one ring.

Type is Bricolage Grotesque, with Nanum Pen Script for the pen notes and IBM Plex Mono for
times. Fonts are self-hosted (SIL OFL, see `app/fonts/OFL.txt`). Light and dark follow your
system.

## Run it

No build step and no dependencies. Any static file server works:

```sh
npm start          # serves app/ on http://localhost:8080
npm test           # 72 unit tests (Node 18+), no install needed
npm run test:e2e   # optional browser test: npm i --no-save playwright && npx playwright install chromium
```

On a phone, open the site and choose **Add to Home Screen**. It installs like an app and works offline.

### Deploy to GitHub Pages

`.github/workflows/pages.yml` runs the tests and publishes `app/` on every push to `main`.
One-time setup: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
The site will be at `https://<user>.github.io/WilList/`.

## Project layout

```
app/                  the website (deployed as-is)
  index.html, styles.css, sw.js, manifest.webmanifest, icons/, fonts/
  vendor/             the Anthropic SDK bundle, loaded only when the coach is used
  src/
    parse.js          quick-add language → item
    importer.js       .ics calendar files and pasted syllabi → items, with de-duplication
    plan.js           backward planning, spaced sessions, study-load balancing
    timeline.js       My day: fits work into the free gaps between fixed events
    agenda.js         Today's lettered list, schedule, radar, vital few
    insights.js       focus log, pace calibration, A1-first streak, week stats
    store.js          state, persistence, undo, actions
    ai.js             the optional coach (Claude) and AI syllabus reading
    ics.js            calendar export
    coach.js          Tracy's principles and tips
    views/            Today, Radar, Plan, Goals, Tools, import, coach, item editor
tests/                node:test unit tests for the logic, plus a Playwright smoke test
docs/PRINCIPLES.md    every Tracy idea → where it lives in the app
docs/AI.md            the coach: setup, privacy, cost
briantracy.md         the seminar transcript
```
