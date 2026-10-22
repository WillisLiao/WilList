# Next session: keep raising the bar

The goal and the loop are in `handoffs/GOAL.md`; paste it to start.
Read `CLAUDE.md`, `handoffs/HANDOFF.md`, `docs/DESIGN.md` and `docs/PRINCIPLES.md` first.
Everything the previous next-session file asked for is done: first run, empty states, widgets, CI, UI tests, cleaner views.

## Start here

1. Check out `claude/optimistic-ride-55ift9` and prove the baseline: `cd ios/WilListCore && swift test`, `npm test`, `npm run lint`, `npm run test:e2e` (needs `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i --no-save playwright` once; it uses the system Chrome, never `playwright install`), then the UI tests with `xcodebuild test -project ios/WilList.xcodeproj -scheme WilList -destination 'platform=iOS Simulator,name=iPhone 17'`.
2. `npm run ios:shots` plus the launch arguments at the top of `scripts/ios-shots.mjs`, and look at everything with fresh, picky eyes.

## Ask the owner first

- Which look to keep (`meadow`, `frog`, `notebook`, `lagoon`); then delete the others.
- Merging into `main`, custom lists, the website catching up, iPhone and iPad sync (see HANDOFF.md).
- Installing on the devices (`npm run ios`) needs team `45MSS5RXML` signed in to Xcode; this build registers the app group, the widget extension and Live Activities.

## Work, roughly in order of value

- **Plan tomorrow tonight, as a ritual:** at the planning time, one flow that walks tomorrow's list (letters through the sorter, the A1 picked) and ends with "Tomorrow starts with ...". Tracy's most-repeated habit deserves more than a row at the bottom of Plan.
- **VoiceOver pass:** every control on every screen and sheet, in reading order, with hints where a gesture isn't obvious. The simulator can't run VoiceOver; use the Accessibility Inspector or a device.
- **Fresh-eyes audit of the sheets not yet polished this round:** Search, Bring in a schedule, the Add sheet, item and to-do details, Plan tomorrow, Your goals; default and largest text.
- **Ticking off from a notification:** check Mark done and snooze on a real device and make the result visible when the app opens.
- **iPad:** a sidebar or two columns (Today beside Plan) would use the space far better than a centred column.
- **The website,** only if the owner says so.

## Before you finish

Check on a real device if one is connected: a reminder arriving, Mark done from the notification, the badge, the quick actions, the widgets, the Live Activity.
Update `handoffs/HANDOFF.md`, append to `devlogs/<date>.md`, rewrite this file, commit and push the branch.
