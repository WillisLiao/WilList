# WilList design system (iPhone app)

This is how the iPhone app looks, reads and behaves, and why.
Change it deliberately: if a new screen needs something this file doesn't cover, add the rule here in the same change.
These are the app's current choices, not limits: on 2026-10-23 the owner said there are no rules for anything, and asked for a visually captivating experience.
Bold changes are welcome when they serve the student; show them side by side when it's a taste call.

## The idea

A student opens WilList and knows at once what to do first, ticks it off, and closes the app.
The owner's two strongest pieces of feedback were "I'm lost when I look at the app" and "not simple enough", and that the app "shouldn't be dark".
Everything below serves calm, obvious screens and a satisfying tick.

The accent is a bright green chosen for Tracy's *Eat That Frog*: do your biggest, most important task (your A1) first.

## Colour

The app is always light (`UIUserInterfaceStyle` is `Light` in `Info.plist`). There is no dark mode.

| Token | Value | Used for, and only for |
|---|---|---|
| Paper | system white (plain `List`), system grouped grey in `Form`s | Backgrounds. Main tabs use plain white lists; settings and detail sheets use grouped forms. |
| Ink | `Color.primary` | Titles and body text. |
| Grey | `Color.secondary`, `Color(.tertiaryLabel)` for empty circles and clear buttons | Secondary lines, metadata. |
| Green | `AccentColor` asset and `Look.accent`, `#12884A` (4.5:1 on white, so green words stay readable); `#0B6B39` with Increase Contrast | Ticks, the A letter, the one primary button per screen, set values (a reminder that is on), links and tappable rows. |
| Pale green | green at 9% (the A1 card in the Lagoon look), 12% (the Letter button) | Emphasis that must stay quiet. |
| Red | `Color.red` | Problems only: overdue, a day over the study budget, behind or short of time. |
| Course colours | `CourseColor.all` in `ios/Shared/Look.swift`: blue, tangerine, plum, teal, raspberry, ochre, slate, then the green; each holds white text at 4.5:1 | A course's own colour, like a highlighter per class. The plan keeps each course's number (`settings.courseColors`, given by `AppState.colorCourses`), so a course keeps its colour on every device and the website. |

Colour goes on things that mean something, never on decoration.
The A1 poster on Today, its widget and the Focus screen are drawn on the A1's course colour, or the green when it has no course; course names on rows are written in their colour.
A course colour never stands for a problem: overdue stays red.
Words on a field of colour are always pure white: white dimmed even to 85% falls below 4.5:1 on the green, so size and weight make the hierarchy there.
The guided flows open on a field too: the welcome's questions on the green, Plan tomorrow's on night (`PlanTomorrow.night`, `#262C66`), and Plan tomorrow's last page on the colour of tomorrow's A1, so it previews the morning's poster.

## Type

- Screen titles: New York (the system serif), bold. Set once for every navigation bar in `AppDelegate`, and used by hand for Today's date header.
- The A1 card title and the main goal also use the serif, so the most important words on the screen share one voice.
- Everything else: SF system text styles (`.body`, `.subheadline`, `.footnote`), so Dynamic Type works.
- Sentence case everywhere. No all-caps labels.

## Words

- Plain verbs, the user's words: "Remind me", "Add a due date", "Mark done", "Plan tomorrow", "Bring in a schedule".
- Tracy's terms keep a plain explanation beside them: "A  Must do: serious consequences if not done".
- No explanatory footers unless they help the user decide or act. Say a status only when it needs attention (no "On track").
- Errors say what happened and what to do: "Notifications are off for WilList. Turn them on in the Settings app to get reminders."
- Never the em dash.
- Typographic apostrophes and quotes in everything the app says: "What’s", “this”, never the typewriter ' and ".

## Layout and screens

Each screen has one job and one primary action.

| Tab | Job | Primary action |
|---|---|---|
| Today | Your A1 as one large card under today's date, how many items wait for a letter (a tap letters them; in the evening, until tomorrow is planned, Plan tomorrow instead), then a quick checklist, plus anything added to Today from Plan and Study | "Mark done" on the A1 card; type a line in "Add a to-do" (dates in it are read: "Call mum tomorrow 6pm") |
| Plan | Your main goal, the day in ABCDE order with the A1 first, items needing a letter, then Plan tomorrow and Bring in a schedule | Give each item a letter |
| Study | Today's study sessions, this week's load, exams and deadlines coming up | Tick a session |
| More | Settings, calendar links, the Claude key, backups | (none) |

Search (magnifying glass) sits on Today, Plan and Study and covers everything.
It opens ready to type, keyboard up, and the X beside the field closes it.

On a wide screen (iPad) every list keeps to a centred 700 pt column (`readableColumn()`).
There the highlighted tab names the screen, so a tab's own title steps aside, and a pushed screen's title sits centred above the column.

## Components

All shared pieces live in `ios/WilList/Theme.swift`, `ios/WilList/TaskFields.swift` and `ios/WilList/Steps.swift` (the guided flows' page, line entry and A1 choice).

- **Row:** check on the left, title, one quiet line under it, and on the right a star (to-dos) or a letter (items). Tap the text to open details. Swipe right to finish, left to delete.
  On every tab the check sits in a 44-point column 12 points in and the words start 10 points after it, so lists line up as you switch tabs. Rows without a check (Needs a letter, Plan tomorrow) keep the words in that column.
- **The line under a title** (`Fmt.meta`, `Fmt.marks`): only what the task has, spaced apart: the due date ("Due tomorrow, 10:00 AM", green when today, red when overdue), "1 of 3" steps, a bell for a reminder still to come, a repeat arrow, a note mark, a sun when it's on Today.
- **CheckButton:** 44 pt, an empty grey circle that fills green with a bounce, throws off a ring and six sparks (not with Reduce Motion), a success haptic and the chime (`Chime.play()`, follows the silent switch, can be turned off in More). The row waits 450 ms filled, then glides away.
- **LetterMark:** letters differ by intensity, not hue. A is filled green with a white letter, B is outlined in ink, C is grey, D is dashed (someone else does it), E is struck through. Tapping a letter opens `LetterChoices`: all five with their meaning, the suggested one marked.
- **StarButton:** grey outline, filled green when important.
- **A1 poster** (`A1Card.swift`, at the top of Today, in Meadow): a field of the A1's course colour across the top of Today, running up under the status bar, with the date, the letter and "Do this first", the title in 44 pt bold serif, at most two lines under it, "Start" (white, bordered) beside a wide white "Mark done", and "3 days in a row you started with an A" when there is a streak.
  Mark done draws a line through the title left to right, its words fade, then the next A rises into the same place and the field blends into its course's colour; the toast offers Undo.
  After the day's last A (nothing lettered left for today), the poster stays, green, and says "Your A’s are done." with a check, how many things got done today and the streak; the last card fades out whole first, so nothing ghosts through.
  The A1 and this poster are one list row whose contents swap, so the field stays solid during the hand-over.
  The other looks draw it as a card, corner radius 22.
- **Focus** (`FocusView.swift`): the whole screen in the session's course colour, a white ring and timer, and white buttons.
- **Week chart** (`WeekChart` in `StudyView.swift`): each day's planned study stacked by course colour, palette order from the floor up, under a dashed line at the daily study time, with a key of the week's courses below.
  A day past the line shows its time in red under the bar; red is never stacked on the bars, where it would read as a course.
- **Focus** (`FocusView.swift`, from Start on the A1 card): one task, one timer, nothing else. The letter and the serif title, a ring that fills as the planned minutes pass (a study session's own length, or the usual task length), Pause or Resume, Mark done and Stop. At the end it says to take a break, with the chime. The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island (`FocusActivity.swift`, faces in `ios/Shared/FocusViews.swift`), with Mark done on it, and it says Break there too when the time is up. The real minutes are logged, as on the website.
- **Letter sorter** (`LetterSorter.swift`): letters the items waiting for one, one at a time. The item's title large at the top, the five letters as big rows with what each one means, the suggested one outlined and tagged, Skip for now, Back. It ends by naming your A1. Opened from Today's "2 waiting for a letter" and Plan's "Letter them".
- **Plan tomorrow** (`PlanTomorrow.swift`): the evening habit in two steps on the welcome's pages: "Anything new for tomorrow?" (lines, dates read, with "4 done today, starting with an A." above when something got done), then "Which one first?" (tomorrow's list with its letters, plus the new lines; the current A1 is chosen to start). It ends on a sunrise: "Tomorrow starts with" and the A1's title, with Letter them when anything waits. Opened from Plan's "Plan tomorrow", Today's evening nudge and the evening notification. Close keeps the lines written and changes no letters.
- **Widgets** (`ios/Shared/WidgetViews.swift`): Do this first (the A1 with Mark done) and Today (to-dos with a tick box each).
  A tick there shows the line done for a moment, as in the app: the A1's button says Done; a row's box fills green and its words turn grey, struck through.
  A second later it leaves (`TickMark` in `Glance.swift`: the timeline's first entry shows it done, the next one without it).
- **Task details** (`TaskFields.swift`), the same for to-dos and items:
  - Steps: tick, type to add (return adds the next), swipe to delete, drag to reorder.
  - Remind me: Later today (3 hours on, on the hour, until 10 PM), Tomorrow 9:00 AM, Next week (Monday 9:00 AM), Pick a date and time (a calendar sheet with Set). Set, it reads "Remind me at 9:00 AM" over "Tomorrow".
  - Due: Today, Tomorrow, Next week, Pick a date, then "Add a time" (5:00 PM to start).
  - Repeat: Daily, Weekdays, Weekly, Monthly, Yearly, Custom (every N days, weeks, months or years, weeks on chosen weekdays). A repeat needs a date, so setting one without a date starts it today.
  - Add to Today (items only), Note, Give it a letter (to-dos only: it moves into Plan with everything it has, and stays on Today for today), Delete at the bottom.
  - A menu in a form row answers a tap anywhere on the row (`fillsRow()`), not only on its words.
  - Every set value has a grey clear button on the right.
- **Sheets:** inline serif title. To-dos save as you type and close with Done. Items edit a copy and use Cancel and Save, because saving can re-plan the study sessions.
- **Toast:** at the bottom, with Undo after a delete or a tick. Liquid Glass on iOS 26, the regular material before.
  It stays long enough to read (five seconds, up to ten for a long message), and VoiceOver reads it out.
  With VoiceOver on, a toast with Undo stays until Undo is reached or something replaces it.

## Motion

Motion only answers an action: the tick, rows moving into place (`.snappy`), symbols replacing each other.
No decorative or entrance animation.

## Accessibility

- Every icon-only control has an accessibility label ("Mark done", "Mark as important", "Remove reminder").
- Touch targets are at least 44 pt.
- Text uses Dynamic Type styles. Only the letter marks, Today's tool icons and the circles beside the welcome's choices stop growing at the largest standard size, so they keep their shape and the words beside them line up.
- At the accessibility sizes, big buttons show only their words (`WordsWhenLarge` in `Theme.swift`), and buttons side by side stack.

## SwiftUI pitfalls already paid for

1. **Accent colour lost:** touching `UIAppearance` (for example `UINavigationBar.appearance()`) in `App.init` makes the whole app fall back to system blue. Do appearance setup in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
2. **Text inside a `Button` turns green:** hierarchical styles (`.primary`, `.secondary`, `.tint` as shape styles) take on the button's tint. Use fixed colours: `Color.primary`, `Color.secondary`. Likewise `.tint(.primary)` on a row turns green fills black.
3. **The type checker crashes** ("failed to produce diagnostic") on `.onMove(perform: flag ? method : nil)`. Write an explicit closure with typed parameters.
4. **"Expression too complex"**: split long expressions; do mutating calls before `#expect` or `#require`, never inside them.
5. **`store.change { $0.addTodo(...) }`** must discard results it doesn't use: `{ _ = $0.addTodo(...) }`.
6. **Joining `Text`:** use interpolation, `Text("\(a)   \(b)")`. `Text + Text` is deprecated on iOS 26.
7. **iOS 26 only APIs** (`glassEffect`, `tabBarMinimizeBehavior`) go through the gated helpers `floating()` and `minimizingTabBar()` in `Theme.swift`; the deployment target is iOS 18.
8. **Notifications:** iOS keeps at most 64 pending, so `Reminders.sync` schedules the soonest 60 and re-syncs whenever the plan changes (`.task(id: Reminders.due(...))` in `RootView`). Permission is asked only when someone sets a reminder or turns on the badge, never at launch.
9. **Simulator:** a permission prompt from an earlier run keeps reappearing even after reinstalling; `xcrun simctl erase <device>` clears it. The first launch after an install takes a few seconds; `npm run ios:shots` waits five.
10. **Wide-screen margins:** `.safeAreaPadding` on a `NavigationStack` reaches neither its bar nor its lists, so the column is `.contentMargins(.horizontal, ..., for: .scrollContent)` on each list.
    A margin of 0 there also strips a grouped list's card inset; pass `nil` for the system default.
11. **Tap areas:** a frame outside a bare button (`Button("Close") { }.frame(minWidth: 44, minHeight: 44)`) looks right but still answers only on its glyphs.
    Put `.tapArea()` (or a frame and `contentShape`) inside the label. `AuditTests` runs the system's accessibility audit on every screen and sheet and catches this.
12. **Colours that follow a trait:** a `UIColor` dynamic provider made in the app target is main-actor isolated by default, and SwiftUI resolves colours off the main thread, so the app stops with a breakpoint trap mid-render.
    Make the initializer that builds it `nonisolated` and the provider `@Sendable` (`Color(hex:highContrast:)`).
13. **Strikethrough on a widget:** WidgetKit drops `strikethrough(_:color:)` when it is given a colour, though the app's widget gallery still draws it.
    Use plain `strikethrough(_:)` and colour the words instead, and check widget changes on a real Home Screen, not only in the gallery.
    `WidgetTests` does that for a tick on the Today widget; it only runs with `TEST_RUNNER_WIDGETS=1`, as it ticks a real to-do on the simulator.
14. **A list row's state can come back:** after Undo, a `List` brought the A1 card back with its old `@State`, still saying Done, even though the card is keyed with `.id`.
    Reset a row's passing state when it appears (`A1Card`), or keep it in the screen above the list, as the `ticking` sets do.
15. **Labels at the largest text sizes:** in a list, a `Label` with two lines of text wraps them around its icon.
    Where that reads badly, lay the row out by hand and put the icon above the words at accessibility sizes (`ImportOption`), as the A1 card and the letter sorter do with their buttons and letters.
16. **Big buttons at the largest text sizes:** the round ends of a large button and its icon left "Mark done" so little room that it broke mid-word, "Ma / rk do…".
    `.labelStyle(WordsWhenLarge())` drops the icon at the accessibility sizes; the A1 card and Focus use it.
17. **A button centres the lines it wraps:** a row-like borderless button whose words wrap at a large size centres the second line under the first.
    Add `.multilineTextAlignment(.leading)` (Today's nudge).
18. **Line breaks after an apostrophe:** at the largest size on a 375 pt phone, iOS evened out a title's lines by breaking "What’s" after its apostrophe, curly or straight.
    Big titles avoid contractions ("What is your main goal?").
    Check titles on the iPhone SE simulator at the largest size.
