# WilList

**Willis's list:** a student planner built on Brian Tracy's ABCDE method.

A to-do app lists everything but doesn't tell you what matters. A calendar shows dates but not
priorities, or when to *start* the exam prep. WilList does both, for high school, college and
grad students:

1. **Dump everything in.** Type it the way you'd say it: `Chem quiz thu`, `Essay due nov 3 #HIST`,
   `Lab every wed 2-5pm`.
2. **Give each one a letter.** A = serious consequences if you skip it, B = should do, C = nice to do,
   D = delegate, E = eliminate. Number your A's: A1, A2, A3.
3. **Do your A1 first.** WilList works backwards from every exam, presentation, assignment and
   reading to spaced study sessions and a start date, then puts today's session on today's list.

Every feature maps to an idea from Tracy's *Phoenix Seminar*; see
[docs/PRINCIPLES.md](docs/PRINCIPLES.md).

## Screens

| | |
|---|---|
| **Today** | Your A1 with a Start button, a tray for anything without a letter, today's classes and meetings, then A / B / C / D / E. B's stay dimmed while any A is open. |
| **Radar** | The next 14 (or 30) days: classes, exams, deadlines, study load per day against your budget, and "the vital few" with progress bars. **Balance my plan** re-spreads all work so A's get first claim on each day. |
| **Plan** | *Plan tomorrow* (2 minutes, each evening) and a *Weekly review* (important-not-urgent work, goals, clean-up, balance). |
| **Goals** | A major definite purpose pinned to Today, goals in three balanced areas, and Tracy's seven questions. |
| **Tools** | Worry Buster, 20 Ideas, Pre-game (mental rehearsal before an exam or talk), the Principles library, calendar export, backup, settings. |

## Quick-add cheat sheet

| You type | WilList understands |
|---|---|
| `Calc midterm fri 2pm #MATH201` | Exam on Friday at 2pm, course MATH201, ~8h of prep spread over spaced sessions |
| `HW3 due 10/24 11:59pm` | Homework due on that date and time |
| `Calculus lecture mwf 10-10:50am` | Class every Mon/Wed/Fri, 10:00–10:50 |
| `Advisor sync every other thu 3pm` | Every two weeks |
| `Read Smith 2019 paper by next mon` | Reading, due Monday of next week |
| `Essay draft due in 2 weeks !a1` | Deadline, already lettered A1 |
| `Study 2h for chem quiz oct 22` | 2 hours of prep for the quiz |

Dates: `today`, `tonight`, `tomorrow`, `fri`, `next fri`, `in 3 days`, `10/24`, `oct 24`, `24 oct`, `2026-10-24`.
Repeats: `daily`, `weekdays`, `weekly`, `every tue`, `every mon and wed`, `tuesdays`, `mwf`, `tth`, `every other thu`, `monthly`.

## Reminders

Browsers only allow notifications while the page is open, so WilList offers two options:

- **Tools → Add to calendar** downloads an `.ics` file containing repeating classes, exams, presentations
  and deadlines (with alarms), plus your study sessions and start days. Import it into Apple, Google or
  Outlook calendar for reminders you can rely on. It's a snapshot: export again after big changes.
- **Settings → Remind me while WilList is open** shows classes 15 minutes ahead, your evening plan time
  and your morning A1.

## Your data

Everything lives in your browser's local storage on your device. There is no account and no server.
Use **Tools → Backup & data** to download a backup or move to another device.

## Run it

No build step and no dependencies. Any static file server works:

```sh
npm start          # serves app/ on http://localhost:8080
npm test           # 48 unit tests (Node 18+), no install needed
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
  index.html, styles.css, sw.js, manifest.webmanifest, icons/
  src/
    parse.js          quick-add language → item
    plan.js           backward planning, spaced sessions, study-load balancing
    agenda.js         Today's lettered list, schedule, radar, vital few
    store.js          state, persistence, undo, actions
    ics.js            calendar export
    coach.js          Tracy's principles and tips
    views/            Today, Radar, Plan, Goals, Tools, item editor
tests/                node:test unit tests for the logic
docs/PRINCIPLES.md    every Tracy idea → where it lives in the app
briantracy.md         the seminar transcript
```
