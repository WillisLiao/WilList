# WilList handoff

The living snapshot of where WilList stands.
Read it first; update the top section at the end of every substantial session.

## Now (2026-10-22)

**Branch:** all work is on `claude/optimistic-ride-55ift9`, pushed, CI green.
`main` is 18 commits behind and still holds the older website-only version.
Merging into `main` also runs the GitHub Pages deploy (Pages isn't enabled on the repo yet), so the owner decides when; ask first.

**What the app is today:** a native SwiftUI iPhone and iPad app (iOS 18 and later), always light, with four tabs.

- **Today:** a quick checklist. Dates typed in a line are read ("Call mum tomorrow 6pm"). Sort five ways (by due date it groups into Overdue, Today, Tomorrow, This week, Later), hide completed, star important to-dos. Items from Goals and Study added to Today show below the to-dos.
- **Goals:** main goal at the top, the A1 as one large card with Mark done, the rest of today in ABCDE order with the letter on the right (tap it for a menu of all five with meanings), items needing a letter, then Plan tomorrow and Bring in a schedule (Claude reads any file, photo or text; calendar files and links need no AI).
- **Study:** today's study sessions, this week's load (red over budget), exams and deadlines coming up, with a status only when something needs attention.
- **More:** calendar links, to-do settings (new on top, starred on top, recognise dates, completion sound, confirm delete, app icon badge), study settings, planning time and reminder, the Claude API key (keychain), backup and restore.
- **Every to-do and item** has Microsoft To Do's task details: steps, Remind me (notifications with Mark done and snooze), due date and time, repeat (daily to yearly, or custom), a note, a star (to-dos) or Add to Today (items).
- Search on Today, Goals and Study. Siri and Shortcuts can add to-dos and items. Files shared to WilList open in Bring in a schedule. Press and hold the app icon for New to-do and Search.

**On the owner's devices:** the iPad (iOS 18.5) has the latest build (`016ef8b`).
The iPhone 15 Pro (iOS 18.7.8) still has `a6c1962` (before the Microsoft To Do features) because it was locked and unreachable; run `npm run ios -- iphone` with it unlocked on the same Wi-Fi.

**Checked:** 77 Swift core tests, website unit tests, lint, zero-warning release build, and every changed screen in the simulator (`npm run ios:shots`).

**Not yet checked on a real device:** a reminder actually arriving, the Mark done and snooze buttons on it, the app icon badge, the home-screen quick actions, the chime's volume.

## Open decisions for the owner

1. Merge into `main` (and switch on GitHub Pages for the website), or keep working on the branch.
2. Microsoft To Do's custom lists, list themes, sharing, categories, file attachments: wanted? Custom lists would change how the four tabs are organised.
3. The website: bring it up to the app (light theme, task details) or let it fall behind and say so in the README. Today it keeps the new to-do fields when it loads a backup but cannot show or edit them, and it doesn't understand yearly or every-N repeats.
4. Sync between the iPhone and the iPad (each device keeps its own plan today).

## Where things are

- `ios/WilList/`: the app. `TodayView`, `GoalsView` (with `PlanList`, `GoalsList`), `StudyView`, `MoreView`; `TodoEditor` and `ItemEditor` for details; `TaskFields` (steps, reminder, due, repeat, Add to Today rows); `Theme` (shared marks, formatting, chime, toast); `Reminders` (notifications and badge); `Store` (the one source of truth, saves on every change, undo); `ImportSheet`, `AddItemSheet`, `SearchView`, `Intents`.
- `ios/WilListCore/`: the Swift package with all logic and its tests: models (lenient decoding), parser, planner, agenda, timeline, insights, calendar import, files and the Claude request.
- `app/`: the website (plain JavaScript). `tests/`: its tests. `scripts/`: lint config, screenshots, device install.
- `docs/DESIGN.md`: the design system and SwiftUI pitfalls. `docs/PRINCIPLES.md`: Tracy's principles and where each lives.
- `.claude/skills/`: the two design skills used for every UI change.

## History

- 2026-10-22: iOS 18 target, the simplification and always-light green redesign, Microsoft To Do task details, handoff docs. See `devlogs/2026-10-22.md`.
- 2026-10-21: the native SwiftUI app and the tested Swift core replaced the web wrapper; Siri, Shortcuts and the share sheet.
- 2026-10-19 to 2026-10-21: the website: ABCDE planner, semester import, coach, redesigns, the Quick tab.
