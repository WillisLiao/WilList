# WilList design system (iPhone app)

This is how the iPhone app looks, reads and behaves, and why.
Change it deliberately: if a new screen needs something this file doesn't cover, add the rule here in the same change.
These are the app's current choices, not limits: on 2026-10-23 the owner said there are no rules for anything, and asked for a visually captivating experience.
Bold changes are welcome when they serve the student; show them side by side when it's a taste call.

## The idea

A student opens WilList and knows at once what to do first, ticks it off, and closes the app.
The owner's two strongest pieces of feedback were "I'm lost when I look at the app" and "not simple enough", and that the app "shouldn't be dark".
Everything below serves calm, obvious screens and a satisfying tick.

The look is Lagoon, the owner's pick of four on 2026-10-23 (Meadow, Frog, Notebook and Lagoon, shown side by side): one teal, the system's own type, and the A1 on a pale teal card.
Later that day the owner said they liked the widget gallery better than the app, so the app is laid out like its widgets: every part on a white card of its own with rounded corners, in the softer teal from that picture.
Then they asked for every tab to have the gallery's dark background, so the tabs lie on its deep slate and sheets on a light blue-grey; and for the letters to take the usual colours of urgency, red for A through orange, yellow and green to blue for E.

## Colour

The app is always light (`UIUserInterfaceStyle` is `Light` in `Info.plist`). There is no dark mode.

| Token | Value | Used for, and only for |
|---|---|---|
| Ground | `LinearGradient.ground`, `#667C8F` at the top to `#52667A` at the bottom, through `.ground()` in `Theme.swift` | What every tab is laid on (Today, Plan, Study, More, Your goals): the widget gallery's slate, a shade deeper so white words hold 4.5:1 from Today's summary line down (4.3:1 at the very top, where only large titles sit, which need 3:1). The owner asked for it a little lighter than the first `#5F768A` to `#3D4E5F`; any lighter and small white words fall under 4.5:1. The guided flows and Focus keep their fields of colour. |
| Words on the ground | white, through `.onGround()` | Today's date and summary and its tools, large titles, section titles and footers, "Letter them". Never grey or teal there. |
| Sheet | `Color.sheet`, `#DAE2E7`, through `.sheetGround()` | What every sheet's cards lie on, so a sheet stands apart from the tab under it. |
| Card | white | Every part of a screen: lists are `.insetGrouped` with `.listSectionSpacing(.compact)`, so each section is a card, and the A1 card and the question cards are opaque cards of their own. |
| Ink | `Color.primary` | Titles and body text. |
| Grey | `Color.secondary`, `Color(.tertiaryLabel)` for empty circles and clear buttons | Secondary lines, metadata. |
| Teal | `AccentColor` asset and `Color.brand` in `ios/Shared/Look.swift`, `#347583`, the softer teal the owner picked from the widget gallery (5.2:1 with white either way round, 4.6:1 on the A1's pale card); `#285E69` with Increase Contrast | Ticks, the A letter, the one primary button per screen, set values (a reminder that is on), links, tappable rows and toolbar buttons. |
| Deep teal | `Color.brandDeep`, `#285E69` (`#1F4B54` with Increase Contrast) | Teal words on a pale ground, where the teal itself falls under 4.5:1: on a sheet (5.5:1; the letter sorter's Close and Skip for now) and on a bordered button's teal wash (5.1:1; Start on the A1 card, Bring in a schedule on Study). |
| Outlined on a field | `.outlinedOnField()` in `Theme.swift` | The second button on a field of colour (Pause on Focus, Letter them on Plan tomorrow's last page): white words in a white outline with no wash. On the system's white wash they read at 3.9:1; bare on the field they keep its 4.5:1 or better. |
| Letters | `Letter.color` and `Letter.ink` in `ios/Shared/Letters.swift`: A red `#D92D20`, B orange `#FF9500`, C yellow `#FFCC00`, D green `#34C759`, E blue `#2563EB` | Each letter's chip. The words on it are white on the red and the blue and a deep shade of the colour on the three light ones (`#4A2500`, `#4A3B00`, `#0A3316`), 4.8:1 or better. |
| Pale teal | teal at 9% over white (the A1 card, the A1 widgets, the chosen letter), 6% (an empty card), 12% (the Letter button) | Emphasis that must stay quiet. |
| Red | `Color.red` | Problems: overdue, a day over the study budget, behind or short of time. The A's chip is red too, at the owner's ask; it is always a filled chip, never words, so it doesn't read as a problem. |
| Course colours | `CourseColor.all` in `ios/Shared/Look.swift`: blue, tangerine, plum, green, raspberry, ochre, slate, then the teal; each holds white text at 4.5:1 | A course's own colour, like a highlighter per class. The plan keeps each course's number (`settings.courseColors`, given by `AppState.colorCourses`), so a course keeps its colour on every device and the website. |

Colour goes on things that mean something, never on decoration.
The Focus screen and its Live Activity are drawn on the session's course colour, or the teal when it has no course; course names on rows are written in their colour.
A course colour never stands for a problem: overdue stays red.
Words on a field of colour are always pure white: white dimmed even to 85% falls below 4.5:1 on the teal, so size and weight make the hierarchy there.
The guided flows open on a field too: the welcome's questions on the teal, Plan tomorrow's on night (`PlanTomorrow.night`, `#262C66`), and Plan tomorrow's last page on the colour of tomorrow's A1, as its focus session will be.
That last page rises over the night like a sunrise, the list held still beneath it; between steps the band stays put while the new question rises in, and the step count sits in the middle and rolls on.
Before anything has a letter, Today's card asks "What matters most today?" under a dashed A1 mark, with one button: Letter them when things wait for a letter, otherwise Add your A1 (New task opens with A chosen).
A Plan with nothing in it says "Give everything a letter" in the same place and type, with "Your A1 leads Today." under it and the five letters in their colours with their names: the method at a glance instead of a paragraph about it.
In the evening, with nothing left for today and tomorrow not planned, the card turns pale night and asks "What matters most tomorrow?", with Plan tomorrow in the night colour.
Your goals leads with the main goal set large in white on a teal card (or the question that asks for one); a tap writes it, keyboard up.

## Type

- Screen titles: the system font, bold. Set once for every navigation bar in `AppDelegate`, and used by hand for Today's date header.
- The A1 card's title: `.title2`, semibold.
- A title set large never leaves its last word alone on a line: `Fmt.noWidow` joins the last two words with a no-break space ("Write the / essay intro").
  Don't add an accessibility label to fix the spoken text: VoiceOver reads the no-break space as a space, and a label on the Text splits it into two elements, read twice.
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
| Today | Your A1 as one large card under today's date (or, before anything has a letter, the question what matters most today), how many items wait for a letter (a tap letters them; in the evening, until tomorrow is planned, Plan tomorrow instead), then a quick checklist, plus anything added to Today from Plan and Study | "Mark done" on the A1 card; type a line in "Add a to-do" (dates in it are read: "Call mum tomorrow 6pm") |
| Plan | Your main goal, the day in ABCDE order with the A1 first, items needing a letter, then Plan tomorrow and Bring in a schedule | Give each item a letter |
| Study | Today's study sessions, this week's load, exams and deadlines coming up | Tick a session |
| More | Settings, calendar links, the Claude key, backups | (none) |

Search (magnifying glass) sits on Today, Plan and Study and covers everything.
It opens ready to type, keyboard up, and the X beside the field closes it.

Today's date and its summary sit straight on the ground; everything under them is on cards: the A1 card, each nudge (letters waiting, Plan tomorrow) on a card of its own, then the to-dos with Add a to-do at their top, then each group.
Section titles and footers stay on the ground between the cards, in the system grey.

On a wide screen (iPad) every list keeps to a centred 700 pt column (`readableColumn()`).
There the highlighted tab names the screen, so a tab's own title steps aside, and a pushed screen's title sits centred above the column.

## Components

All shared pieces live in `ios/WilList/Theme.swift`, `ios/WilList/TaskFields.swift` and `ios/WilList/Steps.swift` (the guided flows' page, line entry and A1 choice).

- **Row:** check on the left, title, one quiet line under it, and on the right a star (to-dos) or a letter (items). Tap the text to open details. Swipe right to finish, left to delete.
  On every tab the check sits in a 44-point column 12 points in and the words start 10 points after it, so lists line up as you switch tabs. Rows without a check (Needs a letter, Plan tomorrow) keep the words in that column.
- **The line under a title** (`Fmt.meta`, `Fmt.marks`): only what the task has, spaced apart: the due date ("Due tomorrow, 10:00 AM", teal when today, red when overdue), "1 of 3" steps, a bell for a reminder still to come, a repeat arrow, a note mark, a sun when it's on Today.
- **CheckButton:** 44 pt, an empty grey circle that fills teal with a bounce, throws off a ring and six sparks (not with Reduce Motion), a success haptic and the chime (`Chime.play()`, follows the silent switch, can be turned off in More). The row waits 450 ms filled, then glides away.
- **LetterMark:** a chip filled in the letter's colour (red, orange, yellow, green, blue from A to E), with E struck through as well; an item with no letter yet has a dashed grey outline. On a field of colour (Focus, the Live Activity) the A is white with its letter in the field's colour and the others are white outlines. Tapping a letter opens `LetterChoices`: all five with their meaning, the suggested one marked.
  New task's letter row shows each letter as a pale wash of its colour with dark words, and in full once chosen; yellow and green words can't be read on white.
- **StarButton:** grey outline, filled teal when important.
- **A1 card** (`A1Card.swift`, at the top of Today under the date): pale teal over white (`heroCard()`), corner radius 22, with the letter and "Do this first", the title in `.title2` semibold, at most two lines under it, "Start" (bordered) beside a wide "Mark done", and "3 days in a row you started with an A" when there is a streak.
  Mark done fills the button's check and says Done at once, draws a line through the title left to right, and fades its words.
  Then the card takes the next A's height in one step while it is empty, and the next A's words rise into place; the toast offers Undo, which brings the last A back the same way.
  After the day's last A (nothing lettered left for today), the card stays and says "Your A’s are done." with a check and its burst, how many things got done today and the streak; the last card fades out whole first, so nothing ghosts through.
  The question cards (what matters most today, and tomorrow in the evening) take the A1's place the same way, each with one button.
- **Focus** (`FocusView.swift`): the whole screen in the session's course colour, with the time spent rising from the bottom in a deeper shade of it (the colour mixed with 24% black), like a glass filling, until it reaches the top when the planned minutes are up; the time left in 96 pt bold, and white buttons.
  Its Live Activity on the Lock Screen is drawn the same way, on the course colour (`FocusAttributes.color`).
  The Dynamic Island stays black: the letter is white with the course colour in it, and the time, bar and keyline use the course colour lifted with 35% white (`CourseColor.onDark`, 5.5:1 or better on black).
- **Week chart** (`WeekChart` in `StudyView.swift`): each day's planned study stacked by course colour, palette order from the floor up, under a dashed line at the daily study time, with a key of the week's courses below.
  A day past the line shows its time in red under the bar; red is never stacked on the bars, where it would read as a course.
- **Focus** (`FocusView.swift`, from Start on the A1 card): one task, one timer, nothing else. The letter and the title, the time left, the screen filling from the bottom as the planned minutes pass (a study session's own length, or the usual task length), Pause or Resume, Mark done and Stop. At the end it says to take a break, with the chime. The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island (`FocusActivity.swift`, faces in `ios/Shared/FocusViews.swift`), with Mark done on it, and it says Break there too when the time is up. The real minutes are logged, as on the website.
- **Letter sorter** (`LetterSorter.swift`): letters the items waiting for one, one at a time. The item's title large at the top, the five letters as big rows with what each one means, the suggested one outlined and tagged, Skip for now, Back. It ends by naming your A1. Opened from Today's "2 waiting for a letter" and Plan's "Letter them".
- **Plan tomorrow** (`PlanTomorrow.swift`): the evening habit in two steps on the welcome's pages: "Anything new for tomorrow?" (lines, dates read, with "4 done today, starting with an A." above when something got done), then "Which one first?" (tomorrow's list with its letters, plus the new lines; the current A1 is chosen to start). It ends on a sunrise: "Tomorrow starts with" and the A1's title, with Letter them when anything waits. Opened from Plan's "Plan tomorrow", Today's evening nudge and the evening notification. Close keeps the lines written and changes no letters.
- **Widgets** (`ios/Shared/WidgetViews.swift`): Do this first (the A1 with Mark done) and Today (to-dos with a tick box each).
  A tick there shows the line done for a moment, as in the app: the A1's button says Done; a row's box fills teal and its words turn grey, struck through.
  A second later it leaves (`TickMark` in `Glance.swift`: the timeline's first entry shows it done, the next one without it).
- **Task details** (`TaskFields.swift`), the same for to-dos and items:
  - Steps: tick, type to add (return adds the next), swipe to delete, drag to reorder.
  - Remind me: Later today (3 hours on, on the hour, until 10 PM), Tomorrow 9:00 AM, Next week (Monday 9:00 AM), Pick a date and time (a calendar sheet with Set). Set, it reads "Remind me at 9:00 AM" over "Tomorrow".
  - Due: Today, Tomorrow, Next week, Pick a date, then "Add a time" (5:00 PM to start).
  - Repeat: Daily, Weekdays, Weekly, Monthly, Yearly, Custom (every N days, weeks, months or years, weeks on chosen weekdays). A repeat needs a date, so setting one without a date starts it today.
  - Add to Today (items only), Note, Give it a letter (to-dos only: it moves into Plan with everything it has, and stays on Today for today), Delete at the bottom.
  - A menu in a form row answers a tap anywhere on the row (`fillsRow()`), not only on its words.
  - Every set value has a grey clear button on the right.
- **Sheets:** inline bold title. To-dos save as you type and close with Done. Items edit a copy and use Cancel and Save, because saving can re-plan the study sessions.
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
19. **Words that re-wrap while a row grows:** when a list row changes size inside an animation (the A1 handing over to "Your A’s are done."), a `Text` without a fixed height is first cut short ("started with…") and then re-wraps on the way, its words crossing.
    Give every line on a poster `.fixedSize(horizontal: false, vertical: true)`.
20. **Repainting a list row's colour:** a `List` doesn't repaint `listRowBackground` when only its colour changes, so the poster's field stayed blue when the next A belonged to another course.
    Paint the field inside the row with `.background`, padded out past the row's edges.
21. **A label on a `Text` splits it:** `.accessibilityLabel` on a `Text` that also has traits or actions gave two elements, a button and the text, which VoiceOver reads twice.
    Leave the text as it is when it reads right (a no-break space reads as a space).
22. **An animation on a whole screen:** `.animation(_:value:)` on a screen's root animates everything that changes in the same update as its value.
    The toast host had it, so Mark done's Undo toast animated Today's list too, and the poster crossfaded; keep such modifiers on the piece they are for.
23. **A list row's height animates only with its data:** a `List` resizes a row smoothly only when the change that resized it was an animated change to the list's data.
    A state change inside the row, or a value the parent passes in, resizes it at once, and the row's contents sit centred in the new height while they animate, so everything in the row jumps halfway.
24. **An animated data change animates everything in the row:** with the next A's arrival inside `withAnimation`, the old and new titles crossfaded, the old one coming back from transparent, and the field's blue went orange through a vivid blue and a grey mauve.
    The poster's change isn't animated; the card brings its words in itself, `.transaction(value: row.key) { $0.animation = nil }` keeps any other animated change (Undo) off them, and the field's colours never animate.
25. **An async notification delegate off the main actor:** a `nonisolated async` `userNotificationCenter(_:didReceive:)` finishes off the main thread, and UIKit stops the app when the completion handler it calls then runs there.
    Mark done on a reminder crashed WilList whenever it was running in the background; the method stays on the main actor, and `testMarkDoneFromAReminder` presses the reminder's Mark done on the simulator's Home Screen.
26. **A see-through card on the ground:** a wash of teal laid straight on the blue-grey ground turns muddy, and painting white over the wash hides it.
    `HeroCard` paints the wash first and white behind it (`.background(wash).background(.white)`), so the card is opaque and pale teal everywhere.
