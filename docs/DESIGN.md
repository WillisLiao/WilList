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
| Ground | `LinearGradient.ground`, `#ECEDF2` at the top left through `#DEE0E8` to `#D0D3DE` at the bottom right, through `.ground()` in `Theme.swift` | What every tab is laid on (Today, Plan, Progress, Goals, Agent and Settings): a light galaxy silver, as the owner asked on 2026-10-25, a cool silver with a faint lavender cast lit from the top left like brushed metal (before it, a light slate). Words straight on it (large titles, section names, footers, Today's date) are in `Color.groundInk`, `#1E2B37`, 12:1 at the top and 10:1 at the foot. The widget gallery keeps the deep slate, as a Home Screen would. The guided flows and Focus keep their fields of colour. |
| Words on the ground | white, through `.onGround()` | Today's date and summary, large titles, section titles and footers. Never grey or teal there. |
| Sheet | `Color.sheet`, `#DAE2E7`, through `.sheetGround()` | What every sheet's cards lie on, so a sheet stands apart from the tab under it. |
| Card | white | Every part of a screen: lists are `.insetGrouped` with `.listSectionSpacing(.compact)`, so each section is a card; the Agent's title card and its finds are cards of their own. |
| Ink | `Color.primary` | Titles and body text. |
| Grey | `Color.secondary`, `Color(.tertiaryLabel)` for empty circles and clear buttons | Secondary lines, metadata. |
| Teal | `AccentColor` asset and `Color.brand` in `ios/Shared/Look.swift`, `#347583`, the softer teal the owner picked from the widget gallery (5.2:1 with white either way round, 4.6:1 on the A1's pale card); `#285E69` with Increase Contrast | Ticks, the A letter, the one primary button per screen, set values (a reminder that is on), links, tappable rows and toolbar buttons. |
| Deep teal | `Color.brandDeep`, `#285E69` (`#1F4B54` with Increase Contrast) | Teal words on a pale ground, where the teal itself falls under 4.5:1: on a sheet (5.5:1; the letter sorter's Close and Skip for now) on a bordered button's teal wash (5.1:1). |
| Outlined on a field | `.outlinedOnField()` in `Theme.swift` | The second button on a field of colour (Pause on Focus): white words in a white outline with no wash. On the system's white wash they read at 3.9:1; bare on the field they keep its 4.5:1 or better. |
| Letters | `Letter.color` and `Letter.ink` in `ios/Shared/Letters.swift`: A red `#D92D20`, B orange `#FF9500`, C yellow `#FFCC00`, D green `#34C759`, E blue `#2563EB` | Each letter's chip. The words on it are white on the red and the blue and a deep shade of the colour on the three light ones (`#4A2500`, `#4A3B00`, `#0A3316`), 4.8:1 or better. |
| Pale teal | teal at 9% over white (the A1 widgets, the chosen letter), 6% (the Agent's title card), 12% (the Letter button) | Emphasis that must stay quiet. |
| Red | `Color.red` | Problems: overdue, a day over the study budget, behind or short of time. The A's chip is red too, at the owner's ask; it is always a filled chip, never words, so it doesn't read as a problem. |
| Course colours | `CourseColor.all` in `ios/Shared/Look.swift`: blue, tangerine, plum, green, raspberry, ochre, slate, then the teal; each holds white text at 4.5:1 | A course's own colour, like a highlighter per class. The plan keeps each course's number (`settings.courseColors`, given by `AppState.colorCourses`), so a course keeps its colour on every device and the website. |

Colour goes on things that mean something, never on decoration.
The Focus screen and its Live Activity are drawn on the session's course colour, or the teal when it has no course; course names on rows are written in their colour.
A course colour never stands for a problem: overdue stays red.
Words on a field of colour are always pure white: white dimmed even to 85% falls below 4.5:1 on the teal, so size and weight make the hierarchy there.
Plan tomorrow's guided flow opens on a field too, on night (`PlanTomorrow.night`, `#262C66`), and Plan tomorrow's last page on the colour of tomorrow's A1, as its focus session will be.
That last page rises over the night like a sunrise, the list held still beneath it; between steps the band stays put while the new question rises in, and the step count sits in the middle and rolls on.
On 2026-10-24 the owner took the A1 card off Today, and every explanation off Plan: students know to letter what they add.
The A1 is now the first row of Today's first card; an empty Plan day says only "Nothing planned".
Later that night they asked for Play beside every task, and the Goals tab back between Progress and Agent; a time-ordered Today, tried that night, was taken back out at their ask ("no need time column").
Goals leads with the main goal set large in white on a teal card (just “Main goal” and a plus until there is one); a tap writes it, keyboard up.

## Type

- Screen titles: the system font, bold. Set once for every navigation bar in `AppDelegate`, and used by hand for Today's date header.
- Plan's day: `.title3`, semibold.
- A title set large never leaves its last word alone on a line: `Fmt.noWidow` joins the last two words with a no-break space ("Write the / essay intro").
  Don't add an accessibility label to fix the spoken text: VoiceOver reads the no-break space as a space, and a label on the Text splits it into two elements, read twice.
- Everything else: SF system text styles (`.body`, `.subheadline`, `.footnote`), so Dynamic Type works.
- Sentence case everywhere. No all-caps labels.

## Words

As few words as do the job: on 2026-10-23 the owner said "each item, thing, description should have minimal words as possible".

- Plain verbs, the user's words: "Remind me", "Add a due date", "Mark done", "Plan tomorrow", "Add 3".
- Labels drop what the screen already says: "Starred on top", not "Move starred to-dos to top"; "7 to do, 1 overdue, 1 done" on Today, not "1 done today.".
- Tracy's terms keep two plain words beside them: "A  Must do: serious consequences".
- No explanatory footers. A footer is there only when it changes what the user does next ("50 min short. Raise daily study in Settings.").
- Say a status only when it needs attention, in as few words as it takes: "Over your 2 h a day", "Missed yesterday", never "On track".
- An empty place says what is there in two or three words ("Nothing planned"), or gives its one button, never a paragraph or a lesson in the method.
- Errors say what to do: "Turn on notifications for WilList in Settings."
- Fragments, not sentences, in labels and statuses; no full stop after a fragment ("3-day streak", "Dashed line: 2 h a day").
- Never the em dash.
- Typographic apostrophes and quotes in everything the app says: "What’s", “this”, never the typewriter ' and ".

## Layout and screens

Each screen has one job and one primary action.

| Tab | Job | Primary action |
|---|---|---|
| Today | Under today's date, one card: the tasks added to Today first, in letter order (never one from Plan by itself), then the to-dos; Completed under it; Add a to-do in a bar at the foot, above the tab bar (the owner's calls, 2026-10-25, after Microsoft To Do); Play beside every task | Tick what's first; type a line in "Add a to-do" and tap Add (dates in it are read: "Call mum tomorrow 6pm") |
| Plan | Everything you plan: today's date, today in ABCDE order with the A1 first (drag to re-rank), everything that isn't on today's list under Later (soonest first, with or without a letter), a month calendar showing what's due each day in its letter's colour (tap a day to list it in full) | Give each item a letter |
| Progress | The last 7 days in three numbers (done, A's, focus time) over a chart of the same days stacked by letter, suggestions with at most one action each (Add to Today, Review), then the next 7 days' study blocks against the daily study time | Act on a suggestion |
| Goals | The main goal set large on the teal, the other goals, and the last 21 days as dots, filled where the day started with an A | Write the main goal |
| Agent | Not a chat: hand it a file or a photo and it lists the tasks it found, on a card to tick and Add. Behind a subscription, and it asks once before anything is sent to the AI model; files and photos are read to text on the phone | Send |

The profile picture at the top left of every tab opens **Settings** (a sheet): to-do and study settings, the planning time, calendar links the Agent followed, backups, the Trash (every deleted task and to-do for 30 days, newest first, each with Restore and how many days are left; swipe to delete one for good, Empty at the top right), and Delete progress (Progress and Goals' 21 days start from zero; finished tasks stay, so a mistaken tick can still be undone).
It will hold the account and sign-in once those exist.

The five tabs sit on a solid white capsule at the bottom of every tab, the iPad's included, and never change colour or shrink (pitfall 27).
The chosen tab is in the deep teal on a pale teal pill.

Every tab's bar holds the profile picture at the left and its tools at the right (Today: Search and Sort; Plan: Search and +, which asks Task or Study block), in the system's glass on iOS 26, so they look the same and sit in the same place on every tab.
Today has no title in its bar: its date sits in the list, in the large title's font and place, so a long date can wrap.

Search (magnifying glass) sits on Today and covers everything.
It opens ready to type, keyboard up, and the X beside the field closes it.

Today's date and its summary sit straight on the ground; everything under them is on cards: one card with the lettered tasks added to Today on top and the to-dos under them (sorted by due date, the to-dos take a card per day), then Completed.
Add a to-do is a white bar pinned at the foot, above the tab bar, with the tab bar's shadow so it floats over the cards that scroll under it; with the keyboard up it rides on the keyboard, the tab bar gone.
Tapping Add a to-do or its + starts a to-do, as in Microsoft To Do: the + turns into the to-do's empty circle, Add takes Search and Sort's place at the top right (grey until there are words), and only Add adds it; return just puts the keyboard away (the owner's call, 2026-10-25).
Plan's date sits on the ground the same way, under the tab's title.
Section titles and footers stay on the ground between the cards, in the ground's ink.

On a wide screen (iPad) every list keeps to a centred 700 pt column (`readableColumn()`).
There the highlighted tab names the screen, so a tab's own title steps aside, and a pushed screen's title sits centred above the column.

**On a Mac** (Mac Catalyst, the Mac idiom) the app is the same screens in a window: the column in the middle, the Mac's own smaller type, WilList's tab bar at the foot.
Buttons laid out by hand are borderless, since the Mac would otherwise draw them as push buttons, and a `Menu` hides its indicator, which the Mac would draw as a chevron.
There is no focus Live Activity on a Mac (it has no Lock Screen or Dynamic Island); the Focus screen still runs the session.
`-snapshot <path>` (debug) saves the window as a PNG, as the Mac build can't be shot from outside without screen recording access.

## Components

All shared pieces live in `ios/WilList/Theme.swift`, `ios/WilList/TaskFields.swift` and `ios/WilList/Steps.swift` (the guided flows' page, line entry and A1 choice).

- **Row:** check on the left, title, one quiet line under it in `.footnote`, and on the right Play, then a star (to-dos) or a letter (items) in a 44-point column (`MarkColumn`, empty when there is no letter), so the Play buttons line up down a list.
  Play and the star or letter sit side by side with no gap, up against the words (`RowEnd`): at Display Zoom's 320 points the words get about 126 points, so a to-do's due date stays on one line, at the owner's ask. Tap the text to open details. Swipe right to finish, left to delete.
  E items (dropped) have no Play.
- **PlayButton** (`TaskFields.swift`): a teal play mark; a tap opens "Focus for" with 15, 25, 45 minutes, 1 hour and 1 h 30 min, and a study block's planned time among them, marked "As planned". Choosing one starts focus.
  On every tab the check sits in a 44-point column 12 points in and the words start 10 points after it, so lists line up as you switch tabs. Rows without a check keep the words in that column.
- **The line under a title** (`Fmt.meta`, `Fmt.marks`): only what the task has, spaced apart: the due date beside a calendar icon, without the word Due, which the icon says ("Tomorrow, 10:00 AM", teal when today, red when overdue, "Yesterday"; the owner's call, 2026-10-24), "1 of 3" steps, a bell for a reminder still to come, a repeat arrow, a note mark, a sun when it's on Today.
- **CheckButton:** 44 pt, an empty grey circle that fills teal with a bounce, throws off a ring and six sparks (not with Reduce Motion), a success haptic and the chime (`Chime.play()`, follows the silent switch, can be turned off in Settings). The row waits 450 ms filled, then glides away.
- **LetterMark:** a chip filled in the letter's colour (red, orange, yellow, green, blue from A to E), with E struck through as well; an item without a letter has no mark at all, and nothing asks for one (the owner's call, 2026-10-24: "unlettered shouldn't be a problem"); its details give it one. On a field of colour (Focus, the Live Activity) the A is white with its letter in the field's colour and the others are white outlines. Tapping a letter opens `LetterChoices`: all five with their meaning, the suggested one marked.
  New task's letter row shows each letter as a pale wash of its colour with dark words, and in full once chosen; yellow and green words can't be read on white.
- **StarButton:** grey outline, filled teal when important.
- **MonthCalendar** (`MonthCalendar.swift`, under the rows of Plan): the month and year with a month back and on, the days of the week in single letters, and the days in rows of seven, today's number in the teal. Under each number, what's planned that day: up to two titles in small chips of their letter's colour, or one and "+2". Tapping a day fills its number teal and lists that day in full under the calendar; tapping it again lets it go.
- **Focus** (`FocusView.swift`): the whole screen in the session's course colour, with the time spent rising from the bottom in a deeper shade of it (the colour mixed with 24% black), like a glass filling, until it reaches the top when the planned minutes are up; the time left in 76 pt bold inside a thin white ring of the time spent (8 points, on a track of white at 30%, from the top clockwise, at most 300 points across), which closes at Break (the owner's ask, 2026-10-25); and one white button, Pause or Resume (Close at Break).
  Its Live Activity on the Lock Screen is drawn the same way, on the course colour (`FocusAttributes.color`).
  The Dynamic Island stays black: the letter is white with the course colour in it, and the time, bar and keyline use the course colour lifted with 35% white (`CourseColor.onDark`, 5.5:1 or better on black).
- **Done chart** (`DoneChart` in `ProgressTab.swift`): each of the last 7 days' finished items and to-dos stacked by letter in the letters' colours, A at the floor, to-dos and anything without a letter in grey on top, with the day and its count under it ("Today" in bold).
  It is drawn by hand like the week chart, not with Swift Charts, whose bars left out the empty days at either end; its scale starts at three, so one thing done doesn't fill the card.
- **Week chart** (`WeekChart` in `ProgressTab.swift`): each day's planned study stacked by course colour, palette order from the floor up, under a dashed line at the daily study time, with a key of the week's courses below.
  A day past the line shows its time in red under the bar; red is never stacked on the bars, where it would read as a course.
- **Focus** (`FocusView.swift`, from Play beside any task): one task, one timer, nothing else. The letter (when it has one) and the title, the time left in a ring that closes as the minutes pass, the screen filling from the bottom as the chosen minutes pass, Pause or Resume and, top right, a chevron (`chevron.down`) that lowers the screen while the timer runs on (no Mark done: only a task's own circle ticks it off, the owner's word); the task's Play button then shows the time left, and its menu has Open timer and Stop timer. At the end it says to take a break, with the chime, and Close takes Pause's place. Play's menu ends with Custom, which asks for minutes. The same timer runs as a Live Activity on the Lock Screen and in the Dynamic Island (`FocusActivity.swift`, faces in `ios/Shared/FocusViews.swift`), with Mark done on it, and it says Break there too when the time is up. The real minutes are logged, as on the website.
- **Agent** (`AgentView.swift`): not a chat, on purpose (the owner, 2026-10-28: a chat is not good practice security-wise): there is nothing to type, no questions and no analysis, so nothing a student writes can steer the model, and it is never sent their plan.
  Two white buttons, Choose a file and Choose a photo; what is picked shows as chips (five at most, a spinner while a photo or scan is read on the phone), and Find tasks sends their text.
  What it finds comes as a white card of rows to tick, each with its date and course, and one Add button; once added it says Added, and Undo brings the button back. Something it says (nothing found) is plain text (`Text(verbatim:)`, never Markdown or links). Clear at the top right empties the screen.
  Until the student has agreed, a title card asks whether to send what is read to the AI model, with Continue.
- **Letter sorter** (`LetterSorter.swift`): letters items one at a time. The item's title large at the top, the five letters as big rows with what each one means, the suggested one outlined and tagged, Skip for now, Back. It ends by naming your A1. Opened from Review in Progress, for C to E items over two weeks old.
- **Plan tomorrow** (`PlanTomorrow.swift`): the evening habit in two steps: "Anything new for tomorrow?" (lines, dates read, with "4 done today, starting with an A." above when something got done), then "Which one first?" (tomorrow's list with its letters, plus the new lines; the current A1 is chosen to start). It ends on a sunrise: "Tomorrow starts with" and the A1's title. Opened from Today's evening nudge and the evening notification. Close keeps the lines written and changes no letters.
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
- **Sheets:** inline bold title (`readableColumn(inline: true)`, see pitfall 30). To-dos save as you type and close with Done. Items edit a copy and use Cancel and Save, so a change can be thrown away.
- **Toast:** at the bottom, with Undo after a delete or a tick. Liquid Glass on iOS 26, the regular material before.
  It stays long enough to read (five seconds, up to ten for a long message), and VoiceOver reads it out.
  With VoiceOver on, a toast with Undo stays until Undo is reached or something replaces it.

## Motion

Motion only answers an action: the tick, rows moving into place (`.snappy`), symbols replacing each other.
No decorative or entrance animation.

## Accessibility

- Every icon-only control has an accessibility label ("Mark done", "Mark as important", "Remove reminder").
- Touch targets are at least 44 pt.
- Text uses Dynamic Type styles. Only the letter marks and Today's tool icons stop growing at the largest standard size, so they keep their shape and the words beside them line up.
- At the accessibility sizes, big buttons show only their words (`WordsWhenTight` in `Theme.swift`), and buttons side by side stack; a big button whose icon and words don't fit on one line (side by side at 320 points) shows only its words too.

## SwiftUI pitfalls already paid for

1. **Accent colour lost:** touching `UIAppearance` (for example `UINavigationBar.appearance()`) in `App.init` makes the whole app fall back to system blue. Do appearance setup in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
2. **Text inside a `Button` turns green:** hierarchical styles (`.primary`, `.secondary`, `.tint` as shape styles) take on the button's tint. Use fixed colours: `Color.primary`, `Color.secondary`. Likewise `.tint(.primary)` on a row turns green fills black.
3. **The type checker crashes** ("failed to produce diagnostic") on `.onMove(perform: flag ? method : nil)`. Write an explicit closure with typed parameters.
4. **"Expression too complex"**: split long expressions; do mutating calls before `#expect` or `#require`, never inside them.
5. **`store.change { $0.addTodo(...) }`** must discard results it doesn't use: `{ _ = $0.addTodo(...) }`.
6. **Joining `Text`:** use interpolation, `Text("\(a)   \(b)")`. `Text + Text` is deprecated on iOS 26.
7. **iOS 26 only APIs** (`glassEffect`, `scrollEdgeEffectStyle`) go through gated helpers (`floating()`, `HardTopEdge`) in `Theme.swift`; the deployment target is iOS 18.
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
    Reset a row's passing state when it appears, or keep it in the screen above the list, as the `ticking` sets do.
15. **Labels at the largest text sizes:** in a list, a `Label` with two lines of text wraps them around its icon.
    Where that reads badly, lay the row out by hand and put the icon above the words at accessibility sizes, as the letter sorter does with its letters.
16. **Big buttons at the largest text sizes:** the round ends of a large button and its icon left "Mark done" so little room that it broke mid-word, "Ma / rk do…".
    `.labelStyle(WordsWhenTight())` drops the icon at the accessibility sizes, and whenever icon and words wouldn't fit on one line (Mark done beside Pause at 320 points); Focus uses it.
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
27. **The system tab bar can't stay white:** on iOS 26 the floating glass tab bar takes on the colour of whatever is under it, the slate or a card, and changes as you press or scroll.
    `toolbarBackground(_:for: .tabBar)` and `UITabBarAppearance` backgrounds are ignored there.
    WilList draws its own `TabBar` (in `WilListApp.swift`), a solid white capsule laid over the `TabView`; each tab hides the system's with `underTabBar()`.
    The room for it is left by each screen's `toastHost()`, inside its navigation stack: a `safeAreaInset` outside a `NavigationStack` reaches neither its list nor its toast, so Undo sat behind the bar and the last rows couldn't scroll clear.
    UI tests tap its buttons by identifier (`tab-today`), not through `app.tabBars`.
28. **A lazy grid inside a list's row:** a `LazyVGrid` in a `List` row sent the collection view's layout round in a loop (`_updateVisibleCellsNow`) until an assertion stopped the app, as soon as the row came on screen.
    `MonthCalendar` lays its days out in plain `HStack` rows of seven instead.
29. **A text field above WilList's own tab bar:** the bar stays at the foot of the screen under the keyboard, so a field kept clear of the bar would float a bar's height above the keyboard.
    `ignoresSafeArea(.keyboard)` on the bar alone wasn't enough (on iOS 26.5 the bar rode on the keyboard, over Today's add line), so the bar also goes while the keyboard is up, read the same way as below.
    Today's add bar leaves the bar's room only while the keyboard is down, read from the screen's bottom safe area (over 150 points means the keyboard is up), which also holds with a hardware keyboard, where focus alone would mislead.
    Its toast host is told the bar takes no room (`tabBarRoom` 0), so Undo shows just above the field.
30. **A title mode set outside `readableColumn()` is lost:** the column sets the bar's title mode itself (large on a phone, inline beside the iPad's tabs), and a mode set closer to the content wins.
    So Settings and Your goals, which asked for an inline title, got a large one, and on Your goals it was drawn over the main goal; Today, with no title, kept an empty large title's room above its date.
    A screen that wants an inline title says so to the column: `readableColumn(inline: true)`.
31. **A row's line was a tap target of its own:** the accessibility audit flagged a line under a row's title (18 points tall) as a hit area too small, inside the row's tappable words.
    A row's title and line are now one element (`rowWords` in `Theme.swift`): a button at least 44 points tall that opens the details, read as "Read chapter 4, Due Fri".
    UI tests find a row by its title at the start of that label (`title(_:in:)` in `CoreFlowsTests`).
