# WilList handoff

The living snapshot of where WilList stands.
Read it first; update the top section at the end of every substantial session.

## Now (2026-10-23, morning)

**Branch:** all work is on `claude/optimistic-ride-55ift9`, pushed, CI green (Swift core tests, the app build with its UI tests, the website tests).
`main` is 38 commits behind and still holds the older website-only version.
Merging into `main` also runs the GitHub Pages deploy (Pages isn't enabled on the repo yet), so the owner decides when; ask first.

**What the app is today:** a native SwiftUI iPhone and iPad app (iOS 18 and later), four tabs, light, with a green accent (`#12884A`) and a colour for each course.
The owner said on 2026-10-23 that there are no fixed rules, for anything, and asked for a visually captivating experience; the colour work below is the first answer.

- **First run:** three short steps, each question in white on the green field: what do you have to do (one line each, dates are read), which one matters most (that's your A1), what is your main goal. Skippable, under a minute.
- **Today:** your A1 as the poster of the day: a field of its course's colour (green without a course) across the top, running up under the status bar, with the date, the title in 44 pt bold serif, **Start** (focus) and **Mark done**.
  Mark done draws a line through the title, its words fade, and the next A rises into its place while the field blends into the next course's colour.
  After the last one the poster stays green and says "Your A’s are done.", with what got done and the streak.
  Below: "N waiting for a letter" (one tap letters them); the quick checklist (typed dates are read, five sorts, stars, completed); then anything from Plan and Study added to Today.
- **Course colours:** each course keeps one of eight colours (blue, tangerine, plum, teal, raspberry, ochre, slate, green), stored in the plan (`settings.courseColors`) so it is the same on every device and the website keeps it.
  Course names on rows are written in their colour.
- **Plan** (was Goals): main goal, the day in ABCDE order with the A1 first, items needing a letter (**Letter them** opens the sorter), then Plan tomorrow and Bring in a schedule.
- **Study:** today's sessions, this week's load stacked by course colour with a key, against a dashed daily-budget line (a day past it has its time in red), exams and deadlines coming up.
- **More:** calendar links, to-do and study settings, planning time, the Claude key (keychain), backup and restore.
- **Focus:** the whole screen in the task's course colour, one white ring timer, with Pause, Mark done and Stop; the Lock Screen Live Activity takes the same colour.
  The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island, with Mark done on it.
  A notice says when to take a break, and the real minutes are logged.
- **Letter sorter:** one item at a time, the five letters with what each means, the suggested one marked; the last page names your A1.
- **Plan tomorrow:** Tracy's evening habit in two steps on a night-indigo field: anything new for tomorrow (one line each, dates read), then which one first.
  It ends on "Tomorrow starts with" and the A1's title, the whole page in that A1's course colour, as Today will look in the morning.
  Today offers it from the planning time (8:30 PM unless changed) until tomorrow is planned, and the evening notification opens it.
- **Give it a letter:** a to-do that turns out to matter moves into Plan with its steps, dates and note.
- **Widgets:** Do this first (your A1 with Mark done, on its course colour: small, medium, Lock Screen rectangular and inline) and Today (to-dos with ticks: medium, large, Lock Screen circular), sharing the plan through the app group `group.com.lull.willist`.
- **Ticking off:** the box fills with a ring and six sparks, a chime and a haptic.
  Undo sits in a toast that stays long enough to read, and VoiceOver reads it out.
  On a widget, the ticked line shows done for a moment (the box fills, the words grey and are struck through), then leaves.
- **Accessibility:** every screen and sheet passes Apple's accessibility audit (`AuditTests`, 14 of them), every control is at least 44 points, words stay whole at the largest text sizes down to the iPhone SE (big buttons drop their icons there), and the green deepens with Increase Contrast.
- **Search** opens ready to type, keyboard up; its X closes it.
- **iPad:** every list keeps to a centred readable column.
- Still there: task details on every to-do and item (steps, Remind me with Mark done and snooze on the notification, due date and time, repeat, note), Search, Siri and Shortcuts, the share sheet, home-screen quick actions, and an app icon in the green with dark and tinted versions.

**Four looks to choose from (debug builds only):** `meadow` (the default: serif titles, the A1 as a poster), `frog` (deeper green, solid A1 card), `notebook` (rounded type, outlined card with a highlighter) and `lagoon` (teal, system type).
Shoot one with `LOOK=frog npm run ios:shots`.
Once the owner picks, delete the others from `ios/Shared/Look.swift`.

**On the owner's devices:** the iPad (iOS 18.5) has `016ef8b` and the iPhone 15 Pro (iOS 18.7.8) has `a6c1962`; neither has anything from this evening.
The next `npm run ios` registers the app group, the widget extension (`com.lull.willist.widgets`) and Live Activities under team `45MSS5RXML`, so Xcode needs that team signed in.
Signing is blocked until the owner accepts Apple's latest Program License Agreement in the developer account (Xcode reports "PLA Update available"); compile checks use `CODE_SIGNING_ALLOWED=NO` meanwhile.

**Checked:** 81 Swift core tests, 78 website unit tests, lint, the website end-to-end test, 9 UI tests (add and tick, a reminder, give a letter, Mark done and Undo, focus, the first run, Plan tomorrow, Search, and the accessibility audit), a zero-warning build, and every changed screen in the simulator at the default text size (the owner asked not to spend time on the largest accessibility sizes), on the iPhone 17, the iPhone SE (375 points wide) and the iPad Pro 11-inch.
The poster's Mark done and the colour change to the next course were checked frame by frame in screen recordings.
A tick on the Today widget was checked on the simulator's Home Screen with `WidgetTests` (opt-in: `TEST_RUNNER_WIDGETS=1`) and a screen recording.
Mark done on a reminder was checked there too, with the app closed: the plan and the widgets update within two seconds.

**Not yet checked on a real device:** reminders arriving and their buttons, the badge, quick actions, the chime's volume, the widgets on a real Home and Lock Screen (the simulator holds a ticked line one to two seconds; a device may differ), the Live Activity and its Mark done.

## Open decisions for the owner

1. Merge into `main` (and switch on GitHub Pages for the website), or keep working on the branch.
2. Which look to keep (above).
3. Microsoft To Do's custom lists, list themes, sharing, categories, file attachments: wanted? Custom lists would change how the four tabs are organised.
4. The website: bring it up to the app, or let it fall behind and say so in the README.
   It is still teal and has none of this evening's features (the A1 on Today, focus with the Live Activity, the sorter, the welcome); it keeps the newer fields when it loads a backup but can't show or edit them.
5. Sync between the iPhone and the iPad (each device keeps its own plan today).

The owner has said there are no fixed rules on what the app should be or which features it has.
The one hard limit kept is that saved plans (`willist.v1`) must keep loading.

## Where things are

- `ios/WilList/`: the app.
  Tabs: `TodayView` (with `A1Card`), `PlanView` (`PlanList`), `GoalsList`, `StudyView`, `MoreView`.
  Flows: `Welcome` and `PlanTomorrow` (sharing `Steps`), `LetterSorter`, `FocusView` (with `LiveFocus` and `FocusNotice`).
  Details: `TodoEditor`, `ItemEditor`, `TaskFields`.
  `Theme` holds the shared pieces (the check button and its burst, the toast, the readable column, letter menus); `Store` is the one source of truth (saves on every change, undo).
  Also `Reminders`, `ImportSheet`, `AddItemSheet`, `SearchView`, `Intents`; `TestPlan` and `WidgetGallery` are debug-only.
- `ios/Shared/`: code the app and the widgets share: `Look` (the looks), `Fmt`, `Glance` (what the widgets show), `Focus` (the session and the Live Activity's data), `FocusViews`, `WidgetViews`, `WidgetIntents`, `PlanFile` (the save file in the app group), `Letters`.
- `ios/WilListWidgets/`: the widget extension: the two widgets and the focus Live Activity.
- `ios/WilListUITests/`: the UI tests (`CoreFlowsTests`, `AuditTests`, and `WidgetTests`, which runs only when asked). `ios/WilListCore/`: the Swift package with all logic and its tests.
- `app/`: the website (plain JavaScript). `tests/`: its tests.
- `scripts/`: lint config, screenshots (`ios-shots.mjs` lists the debug launch arguments that open every screen), device install, the app icon generator (`app-icon.swift`).
- `docs/DESIGN.md`: the design system and the SwiftUI pitfalls already paid for. `docs/PRINCIPLES.md`: Tracy's principles and where each lives.
- `.claude/skills/`: the two design skills used for every UI change.

## History

- 2026-10-22 (night): Plan tomorrow, the accessibility audit and bigger tap areas, the green with Increase Contrast, the tick moment on widgets. See `devlogs/2026-10-22.md`.
- 2026-10-22 (evening): the welcome, widgets, CI and UI tests, the A1 on Today, Plan, the letter sorter, focus with a Live Activity, the tick burst, the app icon, the iPad column. See `devlogs/2026-10-22.md`.
- 2026-10-22: iOS 18 target, the simplification and always-light green redesign, Microsoft To Do task details, handoff docs.
- 2026-10-21: the native SwiftUI app and the tested Swift core replaced the web wrapper; Siri, Shortcuts and the share sheet.
- 2026-10-19 to 2026-10-21: the website: ABCDE planner, semester import, coach, redesigns, the Quick tab.
