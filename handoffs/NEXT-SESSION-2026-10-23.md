# Next session: keep raising the bar

The goal and the loop are in `handoffs/GOAL.md`; paste it to start.
Read `CLAUDE.md`, `handoffs/HANDOFF.md`, `docs/DESIGN.md` and `docs/PRINCIPLES.md` first.
Done since the last version of this file: the owner answered the open decisions.
`main` was merged at `5bd0878` and the website is live at https://willisliao.github.io/WilList/; Lagoon is the one look (teal `#057785`, system type, the A1 on a pale teal card); there are no custom lists for now; and the iPhone and iPad now sync through iCloud (`CloudSync`, `PlanMerge`), not yet tried with a real account.
Also: Mark done on a reminder no longer crashes the app (a UI test presses it on the Home Screen), and the Lock Screen widgets were checked on the real Lock Screen, where the ring now says what it counts.
Work at the default text size; the owner asked not to spend time on the largest accessibility sizes.

## Start here

1. Check out `claude/optimistic-ride-55ift9` and prove the baseline: `cd ios/WilListCore && swift test`, `npm test`, `npm run lint`, `npm run test:e2e` (needs `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i --no-save playwright` once; it uses the system Chrome, never `playwright install`), then the UI tests with `xcodebuild test -project ios/WilList.xcodeproj -scheme WilList -destination 'platform=iOS Simulator,name=iPhone 17'`.
2. Without the owner's Apple ID in Xcode, compile the release build with `CODE_SIGNING_ALLOWED=NO` added to the build command in `CLAUDE.md`.
3. `npm run ios:shots` plus the launch arguments at the top of `scripts/ios-shots.mjs`, and look at everything with fresh, picky eyes.
4. Widget changes need the real Home Screen as well as `-gallery`: `TEST_RUNNER_WIDGETS=1` runs `WidgetTests`, and `xcrun simctl io <device> recordVideo` catches the frames.

## Ask the owner first

- Merging what came after `5bd0878` (Lagoon, iCloud sync) into `main`: it publishes the website again.
- Installing on the devices (`npm run ios`) needs team `45MSS5RXML` signed in to Xcode (it had lost the credentials on 2026-10-23); this build registers the app group, the widget extension, Live Activities, the iCloud container and push.
- The iPad layout: a sidebar or two columns instead of a centred column.

## Work, roughly in order of value

- **iCloud sync on two real devices**, once the owner's Apple ID is back: install on the iPhone and the iPad, then check the first sync joins both plans, a tick on one shows on the other within seconds with the app in the background, and an edit made on both while offline merges.
  CloudKit's dashboard (icloud.developer.apple.com) shows the `Plan` record in the `WilList` zone of the private database.
  Push needs the `aps-environment` entitlement, already in `WilList.entitlements`.
- **Look at Lagoon on every screen with fresh eyes**: it replaced Meadow in one go on 2026-10-23, and Today's question and finished cards are new.
  Show the owner side by side when it's a taste call.
- **On a real device:** the widget tick's timing (the simulator holds a ticked line one to two seconds), Mark done and snooze on a reminder, the Live Activity.
- **VoiceOver order** on a device: the simulator can't run VoiceOver, and the audit doesn't check reading order.
- **The A1 card's height** changes in one step when the next A's title has another number of lines (DESIGN pitfalls 23 and 24); worth smoothing only if it reads as a flaw on a device.
- **The Lock Screen Live Activity** still shows a bar and the Dynamic Island a ring; ActivityKit can only animate system timer views.
- **The website,** only if the owner says so.

## Notes

- `testMarkDoneFromAReminder` waits for a real reminder (up to 80 seconds, reminders keep to the minute), so it is the slowest UI test.
- A probe can add widgets to the simulator's real Lock Screen: swipe down from the top, long-press, `posterboard-customize-button`, then `grouped-widgets-reticle-view` or `inline-widget-reticle-view`; reboot the simulator first (`xcrun simctl shutdown` and `boot`) so no half-finished editor is left over.
- The simulator used here is in Chinese (Taiwan), so SpringBoard's labels are Chinese; `WidgetTests` accepts both.
- The Claude Code iOS Simulator tool reports Xcode as not selected; the fix needs the owner's password (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`). XCUITest probes (a temporary test that attaches `XCUIScreen` shots, exported with `xcrun xcresulttool export attachments`) and `simctl` work meanwhile.
- `@AppStorage` values such as `plannedFor` live in the app's preferences on the simulator, not in the plan: pass `-plannedFor x` to shots that need tomorrow unplanned. UI tests start from default settings (`TestPlan` clears them) and never sync with iCloud.

## Before you finish

Check on a real device if one is connected: iCloud sync between two devices, a reminder arriving, Mark done from the notification, the badge, the quick actions, the widgets and their tick, the Live Activity.
Update `handoffs/HANDOFF.md`, append to `devlogs/<date>.md`, rewrite this file, commit and push the branch.
