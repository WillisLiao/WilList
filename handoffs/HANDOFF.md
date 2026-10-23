# WilList handoff

The living snapshot of where WilList stands.
Read it first; update the top section at the end of every substantial session.

## Now (2026-10-24)

**Branch:** all work is on `claude/optimistic-ride-55ift9`, pushed.
`main` was fast-forwarded to `5bd0878` on 2026-10-23 with the owner's OK, and again to `220027f` the same evening (Lagoon, iCloud sync, the cards on slate, the letter colours), also with the owner's OK; GitHub Pages is on and the website is live at https://willisliao.github.io/WilList/ (still the older website, as the owner chose; `app/` hasn't changed).
On 2026-10-24 the owner asked to push to `main` again, and it was fast-forwarded to `8a23b92` (the white tab bar, the words pass, A ordering, Later in Plan, the one-row due date); `app/` hadn't changed.
Anything after `8a23b92` is on the branch only (a check on every Plan row, the short date chip, Plan's day and calendar, Study's calendar, Today without the A1 card, the lighter ground, a CI flake fix); pushing it to `main` publishes the website again, so ask first.

**The owner's new direction (2026-10-24, late):** iPhone and Mac App Store only (the website is to be deleted), no iCloud (sign in with Google or Facebook, plus Apple as the App Store requires), a profile picture at the top left opening Settings, More becomes an Agent tab (a chat that logs anything from any file, with guardrails, as a subscription), every import option and the Claude key field go, and Study becomes Progress (analytics, forecasts, suggestions).
Every request and its status is in `handoffs/OWNER-REQUESTS.md`; work through it in that order.

**The owner's asks on 2026-10-24 (later):** Plan opens on today's date instead of the main goal (first with arrows to pick another day, then, "we already choose date when we enter task", without them); no Plan tomorrow row; a simple calendar under the rows in Plan and in Study; exams and deadlines added in Study must show in Study; no explanations ("give everything a letter", "no more cramming"); no A1 card on Today; and the background "at least 50% lighter".
All done; see the devlog for how.

**The owner's answers (2026-10-23):** merge into `main` with the website as it is; keep the Lagoon look; no custom lists for now; sync the iPhone and iPad through iCloud.
Later, shown the widget gallery, the owner said "i like this design more" and, asked which part, answered both: the app's parts on cards floating on a soft background, and the softer teal in that picture.
Then: "ABCDE can have different colors", and shown three palettes, "just the typical red most important, then orange yellow greeen blue"; "every tab should have the same dark background like this tab" (the widget gallery); and "background color should be slightly lighter".
These replace the goal file's "light, one bright colour, red only for problems": the owner's later words win.
Then, on 2026-10-23: "the app has too many words, each item, thing, description should have minimal words as possible", and "white nav bar keeps changing to background color when pressed or scrolled".
So every visible string in the app was cut to the fewest words (the rules are in `docs/DESIGN.md`, Words), and the tab bar is now WilList's own solid white capsule: iOS 26's glass tab bar can't be made solid (pitfall 27).

**What the app is today:** a native SwiftUI iPhone and iPad app (iOS 18 and later), four tabs, light, in the Lagoon look laid out like its widgets: every part on a white card with rounded corners, every tab on a light slate (`#BAC5CD` to `#B1BAC3`, the widget gallery's mixed 55% with white, words on it in a deep slate ink, `#1E2B37`) and every sheet on a light blue-grey (`#DAE2E7`), one softer teal (`#347583`, `#285E69` with Increase Contrast), the system's own type, the letters in red, orange, yellow, green and blue from A to E, and a colour for each course.
The owner said on 2026-10-23 that there are no fixed rules, for anything, and asked for a visually captivating experience.

- **First run:** three short steps, each question in white on the teal field: what do you have to do (one line each, dates are read), which one matters most (that's your A1), what is your main goal. Skippable, under a minute.
  Between steps the band stays put and the new question rises in; the step count sits in the middle and rolls on.
- **Today:** the date in large bold type with how the day stands, then a card with the A1 first (its check, its title, a play button for a focus session, and its A1 mark) and anything from Plan and Study added to Today under it.
  Below: "N need a letter" (one tap letters them), or Plan tomorrow in the evening until it's done; then the quick checklist (typed dates are read, five sorts, stars, completed).
  There is no A1 card any more (the owner's call, 2026-10-24).
- **Course colours:** each course keeps one of eight colours (blue, tangerine, plum, green, raspberry, ochre, slate, teal), stored in the plan (`settings.courseColors`) so it is the same on every device and the website keeps it.
  Course names on rows are written in their colour.
- **Plan:** everything planned: today's date, today in ABCDE order with the A1 first (drag to re-rank; a new A comes after the A's already there), items needing a letter (**Letter them** opens the sorter), everything lettered that isn't on today's list under **Later** (soonest first, the letter without a number), a month calendar showing what's due each day as small titles in their letter's colours (tap a day to list it), then Bring in a schedule.
  An empty day says "Nothing planned". New task has no Kind picker: the kind is read from the words (the owner's call).
  The owner's rule (2026-10-24): all plans in Plan, only today's in Today, and whatever has study in Study.
- **Study:** today's sessions, this week's load stacked by course colour with a key, against a dashed daily-budget line (a day past it has its time in red), exams and deadlines coming up (undated ones too, last, saying "No date"), then a month calendar with each exam and deadline on its day as a small title in its course's colour, and a tapped day listed under it.
- **More:** your main goal first (it opens Your goals: the main goal large on teal, the other goals, the last 21 days), then calendar links, to-do and study settings, planning time, the Claude key (keychain), backup and restore.
- **Focus:** the whole screen in the task's course colour, the time spent rising from the bottom in a deeper shade like a glass filling, the time left in large bold type, with Pause, Mark done and Stop; the Lock Screen Live Activity and the Dynamic Island take the same colour.
  The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island, with Mark done on it.
  A notice says when to take a break, and the real minutes are logged.
- **Letter sorter:** one item at a time, the five letters with what each means, the suggested one marked; the last page names your A1.
- **Plan tomorrow:** Tracy's evening habit in two steps on a night-indigo field: anything new for tomorrow (one line each, dates read), then which one first.
  It ends on "Tomorrow starts with" and the A1's title, the whole page in that A1's course colour; that page rises over the night like a sunrise.
  Today offers it from the planning time (8:30 PM unless changed) until tomorrow is planned, and the evening notification opens it.
- **Give it a letter:** a to-do that turns out to matter moves into Plan with its steps, dates and note.
- **Widgets:** Do this first (your A1 with Mark done, on a pale teal: small, medium, Lock Screen rectangular and inline) and Today (to-dos with ticks: medium, large, Lock Screen circular), sharing the plan through the app group `group.com.lull.willist`.
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
2. The website stays the older version for now; bringing it up to the app (focus, the sorter, the calendars, the welcome, sync, the cards on slate, the letter colours) is a later call.
3. iPad: a sidebar or two columns (Today beside Plan) would use the space better than a centred column.

The owner has said there are no fixed rules on what the app should be or which features it has.
The one hard limit kept is that saved plans (`willist.v1`) must keep loading.

## Where things are

- `ios/WilList/`: the app.
  Tabs: `TodayView` (with `A1Card`), `PlanView` (`PlanList`), `GoalsList`, `StudyView`, `MoreView`.
  Flows: `Welcome` and `PlanTomorrow` (sharing `Steps`), `LetterSorter`, `FocusView` (with `LiveFocus` and `FocusNotice`).
  Details: `TodoEditor`, `ItemEditor`, `TaskFields`.
  `Theme` holds the shared pieces (the check button and its burst, the toast, the hero card, the readable column, letter menus); `Store` is the one source of truth (saves on every change, undo).
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
