# Next session: keep raising the bar

The goal and the loop are in `handoffs/GOAL.md`; paste it to start.
Read `CLAUDE.md`, `handoffs/HANDOFF.md`, `docs/DESIGN.md` and `docs/PRINCIPLES.md` first.
Done since the last version of this file: the A1 as the poster of the day, a colour for each course (the poster, Focus and its Live Activity, the widget, course names, the week chart), the welcome and Plan tomorrow on fields of colour, "Your A’s are done." after the last A, the field reaching the edges on an iPad, and the owner's word that there are no fixed rules.
Later the same day: step pages that change cleanly and a sunrise into Plan tomorrow's last page, Your goals led by the main goal on a green card, Today asking "What matters most today?" before anything has a letter (and turning night in the evening to ask about tomorrow), a deeper green (`#0F8044`) that holds 5:1 and gets a white status bar, no lone word on a large title's last line, Focus filling like a glass instead of a ring, and the tick's burst on "Your A’s are done.".
Then: the next course's colour wipes up the poster instead of blending (and Undo brings an A back the same way), study sessions name their course on Plan and Study, the iPad poster's field no longer hangs below it, the paused Lock Screen clock and the widget's checks are pure white, the icon is on the deeper green, Plan tomorrow's controls are night indigo, and two CI flakes are fixed (a 15-second wait in the core flow tests, keyboard slots that vanish during the audit).
Work at the default text size; the owner asked not to spend time on the largest accessibility sizes.

## Start here

1. Check out `claude/optimistic-ride-55ift9` and prove the baseline: `cd ios/WilListCore && swift test`, `npm test`, `npm run lint`, `npm run test:e2e` (needs `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i --no-save playwright` once; it uses the system Chrome, never `playwright install`), then the UI tests with `xcodebuild test -project ios/WilList.xcodeproj -scheme WilList -destination 'platform=iOS Simulator,name=iPhone 17'`.
2. Without the owner's Apple ID in Xcode, or until the owner accepts Apple's latest Program License Agreement, compile the release build with `CODE_SIGNING_ALLOWED=NO` added to the build command in `CLAUDE.md`.
3. `npm run ios:shots` plus the launch arguments at the top of `scripts/ios-shots.mjs`, and look at everything with fresh, picky eyes.
4. Widget changes need the real Home Screen as well as `-gallery`: `TEST_RUNNER_WIDGETS=1` runs `WidgetTests`, and `xcrun simctl io <device> recordVideo` catches the frames.

## Ask the owner first

- Which look to keep (`meadow`, `frog`, `notebook`, `lagoon`); then delete the others.
- Merging into `main`, custom lists, the website catching up, iPhone and iPad sync (see HANDOFF.md).
- Installing on the devices (`npm run ios`) needs team `45MSS5RXML` signed in to Xcode; this build registers the app group, the widget extension and Live Activities.

## Work, roughly in order of value

- **Ask the owner how the colour, the evening poster, the focus tide and the colour wipe land** (before-and-after pictures were sent on 2026-10-23), then keep going where colour means something.
  Shoot every change and look at it; show the owner side by side when it's a taste call.
- **The A1 card's height** changes in one step when the next A's title has another number of lines (the list only animates a row's height with an animated data change, which animates everything inside it; DESIGN pitfalls 23 and 24).
  A smooth change would need the poster out of the `List`'s sizing, for example drawn over a top content margin that follows the scroll; worth it only if the step reads as a flaw on a device.

- **On a real device:** the widget tick's timing (the simulator holds a ticked line one to two seconds), Mark done and snooze on a reminder, the Live Activity.
  In the simulator, `xcrun simctl push <device> com.lull.willist payload.json` with `"category": "task"` and an `"id"` delivers a reminder, and XCUITest on SpringBoard can press its buttons.
- **VoiceOver order** on a device: the simulator can't run VoiceOver, and the audit doesn't check reading order.
- **iPad:** a sidebar or two columns (Today beside Plan) would use the space far better than a centred column; ask the owner.
- **The Lock Screen Live Activity** still shows a bar and the Dynamic Island a ring; ActivityKit can only animate system timer views, so the focus tide can't follow there as it is.
- **The website,** only if the owner says so.

## Notes

- Simulators: the iPhone SE and iPad made on 2026-10-22 were gone the next morning; an iPad Pro 11-inch (M4) was made again for the iPad check. An unfamiliar "Under Question Small Phone" simulator was left alone.
- Course colours are stored in the plan (`settings.courseColors`); `AppState.colorCourses` runs on every change and when a plan is loaded, so a plan from the website gets colours on its first load.

- The simulator used here is in Chinese (Taiwan), so SpringBoard's buttons have Chinese labels; `WidgetTests` accepts both.
- The Claude Code iOS Simulator tool reports Xcode as not selected; the fix needs the owner's password (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`). XCUITest probes (a temporary test that attaches `XCUIScreen` shots, exported with `xcrun xcresulttool export attachments`) and `simctl` work meanwhile.
- `@AppStorage` values such as `plannedFor` live in the app's preferences on the simulator, not in the plan: pass `-plannedFor x` to shots that need tomorrow unplanned. UI tests start from default settings (`TestPlan` clears them).

## Before you finish

Check on a real device if one is connected: a reminder arriving, Mark done from the notification, the badge, the quick actions, the widgets and their tick, the Live Activity.
Update `handoffs/HANDOFF.md`, append to `devlogs/<date>.md`, rewrite this file, commit and push the branch.
