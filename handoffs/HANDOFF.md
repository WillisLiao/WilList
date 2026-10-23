# WilList handoff

The living snapshot of where WilList stands.
Read it first; update the top section at the end of every substantial session.

## Now (2026-10-23, evening)

**Branch:** all work is on `claude/optimistic-ride-55ift9`, pushed.
`main` was fast-forwarded to `5bd0878` on 2026-10-23 with the owner's OK, and again to `220027f` the same evening (Lagoon, iCloud sync, the cards on slate, the letter colours), also with the owner's OK; GitHub Pages is on and the website is live at https://willisliao.github.io/WilList/ (still the older website, as the owner chose; `app/` hasn't changed).
Anything after `220027f` is on the branch only; pushing it to `main` publishes the website again, so ask first.

**The owner's answers (2026-10-23):** merge into `main` with the website as it is; keep the Lagoon look; no custom lists for now; sync the iPhone and iPad through iCloud.
Later, shown the widget gallery, the owner said "i like this design more" and, asked which part, answered both: the app's parts on cards floating on a soft background, and the softer teal in that picture.
Then: "ABCDE can have different colors", and shown three palettes, "just the typical red most important, then orange yellow greeen blue"; "every tab should have the same dark background like this tab" (the widget gallery); and "background color should be slightly lighter".
These replace the goal file's "light, one bright colour, red only for problems": the owner's later words win.

**What the app is today:** a native SwiftUI iPhone and iPad app (iOS 18 and later), four tabs, light, in the Lagoon look laid out like its widgets: every part on a white card with rounded corners, every tab on the widget gallery's slate (`#667C8F` to `#52667A`, words on it white) and every sheet on a light blue-grey (`#DAE2E7`), one softer teal (`#347583`, `#285E69` with Increase Contrast), the system's own type, the letters in red, orange, yellow, green and blue from A to E, and a colour for each course.
The owner said on 2026-10-23 that there are no fixed rules, for anything, and asked for a visually captivating experience.

- **First run:** three short steps, each question in white on the teal field: what do you have to do (one line each, dates are read), which one matters most (that's your A1), what is your main goal. Skippable, under a minute.
  Between steps the band stays put and the new question rises in; the step count sits in the middle and rolls on.
- **Today:** the date in large bold type with how the day stands, then your A1 on a pale teal card: the letter and "Do this first", the title, Start (focus) and Mark done, and the streak.
  Mark done draws a line through the title, its words fade, and the next A rises into its place; Undo brings the last A back the same way.
  After the last one the card says "Your A’s are done.", with the tick's burst, what got done and the streak.
  Before anything has a letter, the card asks "What matters most today?", with Letter them or Add your A1 (the widgets ask too); in the evening, with nothing left for today, a pale night card asks "What matters most tomorrow?" with Plan tomorrow.
  Below: "N waiting for a letter" (one tap letters them); the quick checklist (typed dates are read, five sorts, stars, completed); then anything from Plan and Study added to Today.
- **Course colours:** each course keeps one of eight colours (blue, tangerine, plum, green, raspberry, ochre, slate, teal), stored in the plan (`settings.courseColors`) so it is the same on every device and the website keeps it.
  Course names on rows are written in their colour.
- **Plan** (was Goals): main goal (Your goals opens on it, large in white on a teal card), the day in ABCDE order with the A1 first, items needing a letter (**Letter them** opens the sorter), then Plan tomorrow and Bring in a schedule.
  An empty Plan says "Give everything a letter" and shows the five letters in their colours with their names.
- **Study:** today's sessions, this week's load stacked by course colour with a key, against a dashed daily-budget line (a day past it has its time in red), exams and deadlines coming up.
- **More:** calendar links, to-do and study settings, planning time, the Claude key (keychain), backup and restore.
- **Focus:** the whole screen in the task's course colour, the time spent rising from the bottom in a deeper shade like a glass filling, the time left in large bold type, with Pause, Mark done and Stop; the Lock Screen Live Activity and the Dynamic Island take the same colour.
  The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island, with Mark done on it.
  A notice says when to take a break, and the real minutes are logged.
- **Letter sorter:** one item at a time, the five letters with what each means, the suggested one marked; the last page names your A1.
- **Plan tomorrow:** Tracy's evening habit in two steps on a night-indigo field: anything new for tomorrow (one line each, dates read), then which one first.
  It ends on "Tomorrow starts with" and the A1's title, the whole page in that A1's course colour; that page rises over the night like a sunrise.
  Today offers it from the planning time (8:30 PM unless changed) until tomorrow is planned (with nothing left for today, the poster itself turns night and asks what matters most tomorrow), and the evening notification opens it.
- **Give it a letter:** a to-do that turns out to matter moves into Plan with its steps, dates and note.
- **Widgets:** Do this first (your A1 with Mark done, on the A1 card's pale teal: small, medium, Lock Screen rectangular and inline) and Today (to-dos with ticks: medium, large, Lock Screen circular), sharing the plan through the app group `group.com.lull.willist`.
- **Ticking off:** the box fills with a ring and six sparks, a chime and a haptic.
  Undo sits in a toast that stays long enough to read, and VoiceOver reads it out.
  On a widget, the ticked line shows done for a moment (the box fills, the words grey and are struck through), then leaves.
- **Accessibility:** every screen and sheet passes Apple's accessibility audit (`AuditTests`, 14 of them), every control is at least 44 points, words stay whole at the largest text sizes down to the iPhone SE (big buttons drop their icons there), and the teal deepens with Increase Contrast.
- **Search** opens ready to type, keyboard up; its X closes it.
- **iPad:** every list keeps to a centred readable column.
- **iCloud sync** (`CloudSync.swift`, `PlanMerge` in the core): the plan is one record in the student's private iCloud database, and CloudKit's sync engine sends and fetches it, waking the app when another device changed it.
  When both devices changed the plan, the two are merged against the copy both last agreed on: whatever only one side changed is kept, down to one field of one to-do; a delete goes unless the other side changed that thing; a field both changed keeps this device's change.
  More says whether the plan syncs ("Your plan is the same on every iPhone and iPad signed in to your iCloud") or how to turn it on.
  **Not yet tried with a real iCloud account:** it needs the owner's Apple ID in Xcode; the next `npm run ios` registers the container `iCloud.com.lull.willist` and push for the app.
- Still there: task details on every to-do and item (steps, Remind me with Mark done and snooze on the notification, due date and time, repeat, note), Search, Siri and Shortcuts, the share sheet, home-screen quick actions, and an app icon in the teal with dark and tinted versions.

**On the owner's devices:** the iPad (iOS 18.5) has `016ef8b` and the iPhone 15 Pro (iOS 18.7.8) has `a6c1962`; neither has anything from this evening.
The next `npm run ios` registers the app group, the widget extension (`com.lull.willist.widgets`), Live Activities, the iCloud container and push under team `45MSS5RXML`, so Xcode needs that team signed in.
On 2026-10-23 Xcode had lost the owner's credentials ("No Accounts"): sign in again in Xcode, Settings, Accounts, and accept Apple's latest Program License Agreement if Xcode still reports "PLA Update available"; compile checks use `CODE_SIGNING_ALLOWED=NO` meanwhile.
The iPad was paired and reachable then; the iPhone was not.

**Checked:** 91 Swift core tests (10 for the iCloud merge), 78 website unit tests, lint, the website end-to-end test, 12 UI tests (add and tick, adding the A1 from an empty Today, Plan tomorrow from the evening card, a reminder, Mark done on a reminder from the Home Screen, give a letter, Mark done and Undo through to "Your A’s are done.", focus, the first run, Plan tomorrow, Search, and the accessibility audit), a zero-warning build, and every changed screen in the simulator at the default text size (the owner asked not to spend time on the largest accessibility sizes), on the iPhone 17, the iPhone SE (375 points wide) and the iPad Pro 11-inch.
A tick on the Today widget was checked on the simulator's Home Screen with `WidgetTests` (opt-in: `TEST_RUNNER_WIDGETS=1`) and a screen recording.
Mark done on a reminder was checked there too, with the app closed: the plan and the widgets update within two seconds.
With the app open in the background it crashed the app until 2026-10-23 (the handler finished off the main thread); `testMarkDoneFromAReminder` now covers it.

The Lock Screen widgets were added to the simulator's real Lock Screen through its own editor and look right there.
Mark done on the Lagoon card was checked frame by frame in a screen recording.
The widget-style cards were shot and looked at on every tab, Today's empty and evening states, the first run, the welcome, Plan tomorrow, Focus, every sheet, the widgets, and Today, Plan, Study and More on the iPad.

**Not yet checked on a real device:** iCloud sync between two devices, reminders arriving and their buttons, the badge, quick actions, the chime's volume, the widgets on a real Home and Lock Screen (the simulator holds a ticked line one to two seconds; a device may differ), the Live Activity and its Mark done.

## Open decisions for the owner

Answered on 2026-10-23: `main` merged with the website as it is (done), Lagoon kept (done), no custom lists for now, iCloud sync wanted (built, untried on devices), the app laid out like its widgets in the softer teal (done).
Still open:

1. Merging anything after `220027f` into `main`: ask first, as it publishes the website.
2. The website stays the older version for now; bringing it up to the app (the A1 card, focus, the sorter, the welcome, sync, the cards on slate, the letter colours) is a later call.
3. iPad: a sidebar or two columns (Today beside Plan) would use the space better than a centred column.

The owner has said there are no fixed rules on what the app should be or which features it has.
The one hard limit kept is that saved plans (`willist.v1`) must keep loading.

## Where things are

- `ios/WilList/`: the app.
  Tabs: `TodayView` (with `A1Card`), `PlanView` (`PlanList`), `GoalsList`, `StudyView`, `MoreView`.
  Flows: `Welcome` and `PlanTomorrow` (sharing `Steps`), `LetterSorter`, `FocusView` (with `LiveFocus` and `FocusNotice`).
  Details: `TodoEditor`, `ItemEditor`, `TaskFields`.
  `Theme` holds the shared pieces (the check button and its burst, the toast, the A1 card's ground, the readable column, letter menus); `Store` is the one source of truth (saves on every change, undo).
  Also `CloudSync` (iCloud), `Reminders`, `ImportSheet`, `AddItemSheet`, `SearchView`, `Intents`; `TestPlan` and `WidgetGallery` are debug-only.
- `ios/Shared/`: code the app and the widgets share: `Look` (the teal and the course colours), `Fmt`, `Glance` (what the widgets show), `Focus` (the session and the Live Activity's data), `FocusViews`, `WidgetViews`, `WidgetIntents`, `PlanFile` (the save file in the app group), `Letters`.
- `ios/WilListWidgets/`: the widget extension: the two widgets and the focus Live Activity.
- `ios/WilListUITests/`: the UI tests (`CoreFlowsTests`, `AuditTests`, and `WidgetTests`, which runs only when asked). `ios/WilListCore/`: the Swift package with all logic and its tests.
- `app/`: the website (plain JavaScript). `tests/`: its tests.
- `scripts/`: lint config, screenshots (`ios-shots.mjs` lists the debug launch arguments that open every screen), device install, the app icon generator (`app-icon.swift`).
- `docs/DESIGN.md`: the design system and the SwiftUI pitfalls already paid for. `docs/PRINCIPLES.md`: Tracy's principles and where each lives.
- `.claude/skills/`: the two design skills used for every UI change.

## History

- 2026-10-23: the A1 as a poster with course colours, then the owner's answers: `main` merged and the website live, Lagoon as the one look, iCloud sync; Mark done on a reminder no longer crashes the app. See `devlogs/2026-10-23.md`.
- 2026-10-22 (night): Plan tomorrow, the accessibility audit and bigger tap areas, the green with Increase Contrast, the tick moment on widgets. See `devlogs/2026-10-22.md`.
- 2026-10-22 (evening): the welcome, widgets, CI and UI tests, the A1 on Today, Plan, the letter sorter, focus with a Live Activity, the tick burst, the app icon, the iPad column. See `devlogs/2026-10-22.md`.
- 2026-10-22: iOS 18 target, the simplification and always-light green redesign, Microsoft To Do task details, handoff docs.
- 2026-10-21: the native SwiftUI app and the tested Swift core replaced the web wrapper; Siri, Shortcuts and the share sheet.
- 2026-10-19 to 2026-10-21: the website: ABCDE planner, semester import, coach, redesigns, the Quick tab.
