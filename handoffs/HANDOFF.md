# WilList handoff

The living snapshot of where WilList stands.
Read it first; update the top section at the end of every substantial session.

## Now (2026-10-25)

**Branch:** still `claude/optimistic-ride-55ift9`, pushed; nothing merged into `main` since `d911eac`.

**This session (after the owner tried `5e7b89f`):**
- Today: Plan tomorrow is no longer offered there (the evening notification still opens it); an empty main goal reads "Main goal" with a plus; the + on the add line works; and while a line is typed, the letters and Reminder, Date and Repeat menus sit under it, so a to-do can be lettered, reminded, dated and repeated before it is added (a lettered one goes to Plan, on today's list). The tab bar hides while the keyboard is up. Committed as `726c551`.
- Then, at the owner's ask, Today's add line works as in Microsoft To Do: tapping the line or its + turns the + into the to-do's empty circle, Add takes Search and Sort's place at the top right, and only Add adds the line; return just puts the keyboard away.
- No more kinds, at the owner's word ("listing them is enough, organizing them based on those kinds are useless"): every item is a task or a study block, from typed words, the Agent and calendar links alike. The study planner (prep sessions, start dates, pace calibration, replanning), Progress's exams and deadlines, grade weights, effort and the suggested letter are gone; older saves still load, any old kind read as a task. Progress is the last 7 days, the suggestions and the next 7 days' study blocks.

- Then, at the owner's asks: Today shows only what is added to it (no A1 comes up from Plan by itself; the A1 picked in the first run or in Plan tomorrow is added for its day); Settings has Delete progress (Progress and Goals' 21 days from zero, finished tasks kept so a misclick can be undone); Progress lost "A first"; every tab lies on a light galaxy silver. On this Mac, outside the repo, taste-skill became the default design skill and ui-ux-pro-max went to the Trash.
- Then: a Trash in Settings keeps every deleted task and to-do for 30 days (`AppState.trash`, optional in the save file), with Restore; Today is one card (lettered tasks on top, to-dos under them) with Add a to-do in a bar at the foot, as in Microsoft To Do; and the Agent runs on Claude Haiku 5.5 (`claude-haiku-5-5`), not Opus 5.5, at the owner's word ("it's a simple task agent"), without the server-side fallback Haiku doesn't have.
- Then, at the owner's word ("it should be key agnostic so the api key just provides the model, but the agent framework should be the same"): the Agent speaks the chat completions format nearly every provider takes and sends only text, so any provider's key works with the same prompt, tools and cards. Photos and scanned PDF pages are read on the phone (Apple's text recognition, rows kept); PDFs give their own text. The provider, key and model are the server's settings; debug builds use `AGENT_URL`, `AGENT_KEY` and `AGENT_MODEL`. Nothing names Anthropic in the app any more.
- CI failed once on `56af015`: the accessibility audit caught an empty keyboard suggestion slot that came back with no element; the audit now skips that too.

**Checked (latest round, `a824d01`):** 77 core tests (two read a rendered timetable photo and a scanned PDF page through the real recognizer), lint, every UI test (17: 16 passed, `WidgetTests` skipped as usual), a zero-warning release build, and the Agent's screens in the simulator (demo). Never tried against a live provider: no key on this Mac.
**Checked before:** 73 core tests (the planner's went with it), lint, the UI tests (16: 15 passed, `WidgetTests` skipped as usual) and a zero-warning release build; Progress, Plan, Later, a task's and a study block's details, Settings, the Agent's card (demo), Today and New task looked at in the simulator (iPhone 17).
**On the owner's devices:** the iPhone and the iPad both have `4de1d6d` (installed 2026-10-25).
**To ask the owner:** which provider and model the Agent's server should use (their terms must allow serving students), and the open questions in `handoffs/NEXT-SESSION-2026-10-25.md`.

## Before that (2026-10-24, after the owner tried the build)

**Branch:** still `claude/optimistic-ride-55ift9`, pushed; nothing merged into `main` since `d911eac`.

**This session (the owner's two bugs from the build on their iPhone, and one direction):**
- New task in Plan now has Remind me, the date and time, and Repeat under the letters, the item details' own rows (`ReminderRow`, `DueRow`, `RepeatRow`), so nothing waits until the task is a row. The words' read-back (title, course) moved below them so all four fit above the keyboard. `testSetAReminderWhileAddingInPlan` covers it.
- "After 8 tasks the 9th moved to Later": the ninth was "ML test". "test" made it an exam with no day; New exam picked A for it, so tapping A, as the owner did, took the letter off; and an exam with no day never made a day's list anyway. Not the count.
- At the owner's word ("our study tab has already been dropped so all those academic detection shouldn't remain"), typed words no longer pick a kind, a letter or a grade share: `quickAdd` returns no type or `weightPct`, everything typed (New task, to-dos, first run, Plan tomorrow, Siri) is a task, and New study block sets its own kind. `detectType` stays for calendar links only.
- A lettered exam or presentation with no day (the Agent can still make one) is now on the day's list like any task (`dayRows`), with a test.

**Checked:** 103 core tests, lint, the UI tests (15: 14 passed, the widget test skipped as usual) and a zero-warning release build; New task looked at in the simulator. The code is `5e7b89f`, installed on the owner's iPhone (`npm run ios -- iphone`); the iPad was asleep and still has `fbe9251`.
**To ask the owner:** whether the Agent and calendar links should stop setting kinds too (they feed Progress's exams and deadlines and the study sessions); plus the four open questions in `handoffs/NEXT-SESSION-2026-10-25.md`.

## Before that (2026-10-24, late night)

**Branch:** all work is on `claude/optimistic-ride-55ift9`, pushed; CI ("Test") is green on its last code commit, `fbe9251`.
`main` is at `d911eac` (fast-forwarded with the owner's OK, "yes merge", on 2026-10-24); everything after it is on the branch only, and each merge is the owner's call.
The older website is still live at https://willisliao.github.io/WilList/ from `main`; the branch has removed it from the code and from CI, so merging no longer redeploys it, and it goes for good only when GitHub Pages is turned off in the repository's settings (the owner's call).

**This session, in order:**
- The screens the last session hadn't looked at were reviewed and fixed (Today's bar matches the other tabs; Settings has its inline title, which `readableColumn()` had overridden; a due time no longer breaks across lines).
- Every prompt to letter an item is gone, and an item without a letter has no mark (the owner's call).
- The website is gone from the code, with the shots' sample week moved into the app (`-plan sample`); the Agent's server contract is written (`docs/AGENT-SERVER.md`); the Mac app (Mac Catalyst) builds.
- **Play** beside every task on Today and in Plan (not on E's) asks how long (15, 25, 45 min, 1 h, 1 h 30 min, or the planned time) and starts focus, on to-dos too.
- **Study blocks** are added by hand from Plan's + (Task or Study block), with Every week; they are listed under Later in Plan and count in Progress's week chart, but don't show on Today.
- The **Goals tab** is back between Progress and Agent; Settings no longer holds the goals. Item details lost the Kind picker. The letter sorter stays behind Review on Progress (the owner's answer).
- A time-ordered Today (the website's column, with Coming up) was built and then **taken back out** at the owner's ask: "revert all and not use the time column ... just include play button". Today is as it was, plus Play. Lesson: build only what the owner names, and ask which part before reshaping a screen.
- At the owner's ask, the line under a row's title is a size smaller (`.footnote`), Play sits up against the star or letter (`RowEnd`), and a to-do's date beside the calendar icon drops the word Due ("Today, 17:00", "Tomorrow, 10:00", "Yesterday" in red), so it fits on one line at their Display Zoom (320 points).
- The research on the Agent's price: OpenCode Go's terms allow only "your own internal use", and Claude Pro and ChatGPT Plus have no API access, so the Agent stays on a pay-as-you-go Anthropic key behind WilList's server.

**Still to do:** the owner's answers in `handoffs/NEXT-SESSION-2026-10-25.md`; sign-in and account sync (Firebase, needs the owner's Firebase project and Facebook app); the Agent's server itself (until then a release build shows Coming soon); the subscription and its price in App Store Connect, and a privacy policy URL; signing and shipping the Mac app; a live test of the Agent with a key.

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

**What the app is today:** a native SwiftUI iPhone and iPad app (iOS 18 and later), five tabs (Today, Plan, Progress, Goals, Agent) and Settings behind the profile picture at the top left, light, in the Lagoon look laid out like its widgets: every part on a white card with rounded corners, every tab on a light galaxy silver (`#ECEDF2` to `#D0D3DE`, the owner's ask on 2026-10-25, words on it in a deep slate ink, `#1E2B37`) and every sheet on a light blue-grey (`#DAE2E7`), one softer teal (`#347583`, `#285E69` with Increase Contrast), the system's own type, the letters in red, orange, yellow, green and blue from A to E, and a colour for each course.
The owner said on 2026-10-23 that there are no fixed rules, for anything, and asked for a visually captivating experience.

- **First run:** three short steps, each question in white on the teal field: what do you have to do (one line each, dates are read), which one matters most (that's your A1), what is your main goal. Skippable, under a minute.
  Between steps the band stays put and the new question rises in; the step count sits in the middle and rolls on.
- **Today:** the date in large bold type with how the day stands, then a card with the tasks added to Today (Add to Today, a line given a letter here, or the A1 picked in the first run or in Plan tomorrow); nothing comes from Plan by itself (the owner's call, 2026-10-25).
  Below: the quick checklist (typed dates are read, five sorts, stars, completed); while a line is typed, the letters and Reminder, Date and Repeat menus sit under it, and a lettered line goes to Plan, on today's list.
  Every task has Play (a teal triangle) beside its star or letter: it asks how long, then starts focus.
  The line under each title is `.footnote`; a to-do's date sits beside a calendar icon without the word Due.
  No time column and no Coming up (the owner's call, 2026-10-24).
  The profile picture, Search and Sort sit in the navigation bar as on every tab, and the date takes the large title's place.
- **Course colours:** each course keeps one of eight colours (blue, tangerine, plum, green, raspberry, ochre, slate, teal), stored in the plan (`settings.courseColors`) so it is the same on every device and the website keeps it.
  Course names on rows are written in their colour.
- **Plan:** everything planned: today's date, today in ABCDE order with the A1 first (drag to re-rank; a new A comes after the A's already there), everything that isn't on today's list under **Later** (soonest first, the letter without a number, nothing at all for an item without a letter), and a month calendar showing what's due each day as small titles in their letter's colours (tap a day to list it).
  An empty day says "Nothing planned". Every row has Play except E's. Its + asks Task or Study block; neither has a Kind picker, and nor do item details.
  New task has the letters, Remind me, the date (with its time) and Repeat, the same rows as the item's details, so all of it is set before Add; the words still fill in the date, time and repeat.
  Every item is a task or a study block: nothing tells exams, deadlines, readings or classes apart, whether typed, from the Agent or from a calendar link, and nothing plans study sessions (the owner's calls, 2026-10-24 and 2026-10-25: "listing them is enough").
  A study block is a set time to study something ("Organic chem tue 7pm 2h", from Plan's + only), once or every week; it is listed under Later in Plan with Play (its own length offered) and counts in Progress's week chart. It doesn't show on Today.
  The owner's rule (2026-10-24): all plans in Plan, only today's in Today.
- **Progress:** the last 7 days in three numbers (done, A's, focus time) over a chart of the same days stacked by letter, suggestions (start an A early: Add to Today; old C to E items: Review; a day over the daily study time), and the next 7 days' study blocks by course colour against the daily study time.
- **Agent:** a chat that takes files, photos and words, proposes what to add on a card to tick and Add (Undo works), follows a calendar link the student types, and answers questions about the plan; plain text only, guardrails in the devlog. Behind a StoreKit 2 subscription (`com.lull.willist.agent.monthly`), and it asks once before sending anything to Anthropic. Requests go to WilList's server (`WLAgentServer` in Info.plist, empty for now, so release builds show Coming soon); debug builds use `ANTHROPIC_API_KEY` or `-agentDemo YES`. Not yet tried against the live API.
- **Goals** (a tab again, between Progress and Agent, at the owner's ask): the main goal large on teal, the other goals, the last 21 days.
- **Settings** (the profile picture on every tab): to-do settings, the daily study time, the planning time and its reminder, calendar links the Agent followed, backup and restore, the Trash (deleted tasks and to-dos, 30 days, Restore), and Delete progress (Progress and Goals' 21 days start from zero; finished tasks and to-dos stay and stop counting).
- **Focus** (from Play, for 15 minutes to an hour and a half or the planned time): the whole screen in the task's course colour, the time spent rising from the bottom in a deeper shade like a glass filling, the time left in large bold type, with Pause, Mark done and Stop; the Lock Screen Live Activity and the Dynamic Island take the same colour.
  The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island, with Mark done on it.
  A notice says when to take a break, and the real minutes are logged.
- **Letters are optional** (the owner's call, 2026-10-24): nothing asks for one, and an item without one has no mark. Its details give it one.
- **Letter sorter:** one item at a time, the five letters with what each means; the last page names your A1. Opened from Review in Progress.
- **Plan tomorrow:** Tracy's evening habit in two steps on a night-indigo field: anything new for tomorrow (one line each, dates read), then which one first.
  It ends on "Tomorrow starts with" and the A1's title, the whole page in that A1's course colour; that page rises over the night like a sunrise.
  The optional evening notification, at the planning time (8:30 PM unless changed), opens it; Today no longer offers it (the owner's call, 2026-10-25).
- **Give it a letter:** a to-do that turns out to matter moves into Plan with its steps, dates and note.
- **Widgets:** Do this first (your A1 with Mark done, on a pale teal: small, medium, Lock Screen rectangular and inline) and Today (to-dos with ticks: medium, large, Lock Screen circular), sharing the plan through the app group `group.com.lull.willist`.
- **Ticking off:** the box fills with a ring and six sparks, a chime and a haptic.
  Undo sits in a toast that stays long enough to read, and VoiceOver reads it out.
  On a widget, the ticked line shows done for a moment (the box fills, the words grey and are struck through), then leaves.
- **Accessibility:** every screen and sheet passes Apple's accessibility audit (`AuditTests`, 18 of them), every control is at least 44 points, a row's title and line are one element that opens it (`rowWords`), words stay whole at the largest text sizes down to the iPhone SE (big buttons drop their icons there), and the teal deepens with Increase Contrast.
- **Search** opens ready to type, keyboard up; its X closes it.
- **iPad:** every list keeps to a centred readable column, the Agent's message field too.
- **Mac:** the same app through Mac Catalyst, with the Mac idiom, in a window; no focus Live Activity there. It builds and was looked at through its own snapshots; it hasn't been signed or shipped.
- **No sync for now:** iCloud sync was removed at the owner's ask (2026-10-24); sync comes back with sign-in. `PlanMerge` in the core still merges two copies of a plan against the one both last agreed on.
- Still there: task details on every to-do and item (steps, Remind me with Mark done and snooze on the notification, due date and time, repeat, note), Search, Siri and Shortcuts, the share sheet, home-screen quick actions, and an app icon in the teal with dark and tinted versions.

**On the owner's devices:** the iPhone 15 Pro and the iPad Pro 12.9-inch both have `4de1d6d` (installed with `npm run ios`, at the owner's ask); Xcode is signed in to team `45MSS5RXML`.
The iPhone drops off the Wi-Fi tunnel when it sleeps (`xcrun devicectl list devices` shows it "unavailable"): ask the owner to unlock it, then `npm run ios -- iphone`.

**Checked (2026-10-24, late night):** 102 Swift core tests, lint, all 14 UI tests on `4909d65` (13 pass, `WidgetTests` skipped as usual), a zero-warning release build on `fbe9251` (its one-word change wasn't UI-tested locally; CI is green), and Today at 320 points by narrowing the simulator's window, plus the iPhone SE and iPhone 17.
The Play menu itself was never seen on screen: the desktop app's simulator panel can't tap until `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` is run on this Mac; `testFocusOnTheA1` goes through it.
Earlier: the iPhone SE (375 points wide) and the iPad Pro 11-inch.
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

1. Merging the branch into `main`: ask first.
2. Turning GitHub Pages off, which takes the old website down (repository Settings, Pages).
3. iPad and Mac: a sidebar or two columns (Today beside Plan) would use the space better than a centred column.
4. Worry Buster, 20 Ideas, Pre-game and the seven questions lived only on the website: bring them to the app, or let them go.

The owner has said there are no fixed rules on what the app should be or which features it has.
The one hard limit kept is that saved plans (`willist.v1`) must keep loading.

## Where things are

- `ios/WilList/`: the app.
  Tabs: `TodayView`, `PlanView` (`PlanList`, `MonthCalendar`), `ProgressTab` (`DoneChart`, `WeekChart`), `AgentView` (the chat, `AgentPass` for the subscription, `AgentDemo` in debug). `Settings` holds the profile picture and the Settings sheet; `GoalsList` opens from it.
  Flows: `Welcome` and `PlanTomorrow` (sharing `Steps`), `LetterSorter`, `FocusView` (with `LiveFocus` and `FocusNotice`).
  Details: `TodoEditor`, `ItemEditor`, `TaskFields`.
  `Theme` holds the shared pieces (the check button and its burst, the toast, the hero card, the readable column, letter menus); `Store` is the one source of truth (saves on every change, undo).
  Also `Reminders`, `AddItemSheet`, `SearchView`, `Intents`; `TestPlan` and `WidgetGallery` are debug-only.
- `ios/Agent.storekit`: the Agent's subscription for trying it from Xcode (the scheme's Run action uses it).
- `ios/Shared/`: code the app and the widgets share: `Look` (the teal and the course colours), `Fmt`, `Glance` (what the widgets show), `Focus` (the session and the Live Activity's data), `FocusViews`, `WidgetViews`, `WidgetIntents`, `PlanFile` (the save file in the app group), `Letters`.
- `ios/WilListWidgets/`: the widget extension: the two widgets and the focus Live Activity.
- `ios/WilListUITests/`: the UI tests (`CoreFlowsTests`, `AuditTests`, and `WidgetTests`, which runs only when asked). `ios/WilListCore/`: the Swift package with all logic and its tests; `Agent.swift` is the Agent's prompt, tools, requests and guardrails, `Files.swift` turns any file into what Claude reads.
- `scripts/`: lint config, screenshots (`ios-shots.mjs` lists the debug launch arguments that open every screen; the sample week is `-plan sample` in `TestPlan.swift`), device install, the app icon generator (`app-icon.swift`).
- `docs/AGENT-SERVER.md`: the contract for the Agent's server, which doesn't exist yet.
- The Mac app is the same target built for Mac Catalyst (`WilList-Mac.entitlements`, `WilListWidgets-Mac.entitlements`).
- `docs/DESIGN.md`: the design system and the SwiftUI pitfalls already paid for. `docs/PRINCIPLES.md`: Tracy's principles and where each lives.
- `.claude/skills/`: the two design skills used for every UI change.

## History

- 2026-10-23: the A1 as a poster with course colours, then the owner's answers: `main` merged and the website live, Lagoon as the one look, iCloud sync; Mark done on a reminder no longer crashes the app. See `devlogs/2026-10-23.md`.
- 2026-10-22 (night): Plan tomorrow, the accessibility audit and bigger tap areas, the green with Increase Contrast, the tick moment on widgets. See `devlogs/2026-10-22.md`.
- 2026-10-22 (evening): the welcome, widgets, CI and UI tests, the A1 on Today, Plan, the letter sorter, focus with a Live Activity, the tick burst, the app icon, the iPad column. See `devlogs/2026-10-22.md`.
- 2026-10-22: iOS 18 target, the simplification and always-light green redesign, Microsoft To Do task details, handoff docs.
- 2026-10-21: the native SwiftUI app and the tested Swift core replaced the web wrapper; Siri, Shortcuts and the share sheet.
- 2026-10-19 to 2026-10-21: the website: ABCDE planner, semester import, coach, redesigns, the Quick tab.
