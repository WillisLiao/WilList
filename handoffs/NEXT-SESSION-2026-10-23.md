# Next session: keep raising the bar

The goal and the loop are in `handoffs/GOAL.md`; paste it to start.
Read `CLAUDE.md`, `handoffs/HANDOFF.md`, `docs/DESIGN.md` and `docs/PRINCIPLES.md` first.
Done since the last version of this file: the A1 as the poster of the day, a colour for each course (the poster, Focus, the widget, course names, the week chart), and the owner's word that there are no fixed rules.
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

- **Keep the colour going where it means something:** the Live Activity and Lock Screen widget could carry the course colour; Plan's A rows could show their course colour; the welcome could end on a first poster.
  Shoot every change and look at it; show the owner side by side when it's a taste call.
- **The colour change between courses** blends through a muddy middle for a tenth of a second (the colours mix in RGB); a quicker hand-over or a different blend may look cleaner.

- **On a real device:** the widget tick's timing (the simulator holds a ticked line one to two seconds), Mark done and snooze on a reminder, the Live Activity.
  In the simulator, `xcrun simctl push <device> com.lull.willist payload.json` with `"category": "task"` and an `"id"` delivers a reminder, and XCUITest on SpringBoard can press its buttons.
- **VoiceOver order** on a device: the simulator can't run VoiceOver, and the audit doesn't check reading order.
- **iPad:** a sidebar or two columns (Today beside Plan) would use the space far better than a centred column; ask the owner.
- **The website,** only if the owner says so.

## Notes

- The simulator used here is in Chinese (Taiwan), so SpringBoard's buttons have Chinese labels; `WidgetTests` accepts both.
- The Claude Code iOS Simulator tool reported Xcode as not selected although `xcode-select -p` was right; XCUITest and `simctl` worked instead.

## Before you finish

Check on a real device if one is connected: a reminder arriving, Mark done from the notification, the badge, the quick actions, the widgets and their tick, the Live Activity.
Update `handoffs/HANDOFF.md`, append to `devlogs/<date>.md`, rewrite this file, commit and push the branch.
