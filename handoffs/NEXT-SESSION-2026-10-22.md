# Next session: from good to breakthrough

The owner's goal for the next stretch: make WilList a breakthrough app that is easy to use, easy to see, easy to act on, and easy to maintain.
Read `CLAUDE.md`, `handoffs/HANDOFF.md` and `docs/DESIGN.md` first.

## Start here

1. Check out the branch and prove the baseline on this machine:
   `git checkout claude/optimistic-ride-55ift9`, `cd ios/WilListCore && swift test`, `npm test`, `npm run lint`, then `npm run ios:shots` and look at all four tabs.
2. Write down, in a few lines, what a first-time student would find confusing on each screen. Be specific and picky. That list drives the work below.

## Work, roughly in order of value

### Easy to see and use

- **First run and empty states.** Launch with no data (delete the app's save file in the simulator) and walk through it as a new student. Every empty screen should say in one line what to do and offer the one button to do it. A short first-run path (main goal, first to-do, first A) may be worth it; keep it skippable and under a minute.
- **Fresh-eyes audit of every screen and sheet**, using the design skills in `.claude/skills/` and `docs/DESIGN.md`. Fix the top problems, re-shoot, repeat. Include the Add sheet, item and to-do details, Import, Search, Plan tomorrow, Your goals, and More.
- **Dynamic Type and VoiceOver pass:** largest text sizes must not clip or overlap; every control reads well.

### Easy to act on

- **Home Screen and Lock Screen widgets** (a WidgetKit extension): today's A1 with a tick button, and the Today list, using interactive App Intents. Needs an App Group so the widget reads the same save file.
- **Sync between the owner's iPhone and iPad** (they already use both). Propose the approach first (CloudKit or iCloud Drive document), because it touches the save format; ask the owner before building.

### Easy to maintain

- **CI for the app:** add a macOS job to `.github/workflows/pages.yml` that runs `swift test` and builds the app for the simulator, so Swift breakage shows on every push. Keep the deploy job gated to `main`.
- **A UI test** (XCUITest) for the three flows that must never break: add a to-do and tick it off, set a reminder on a to-do, Mark done on the A1 card.
- **Split the biggest views** (`GoalsView.swift`, `TodayView.swift`) where a piece is reused or hard to follow; keep behaviour identical and prove it with screenshots before and after.

### Needs the owner's answer first

- Merging into `main` and switching on GitHub Pages.
- Microsoft To Do's custom lists, sharing, categories and attachments.
- Whether the website should catch up with the app.

## Before you finish

Check on a real device if one is connected (`npm run ios`): a reminder arriving, Mark done from the notification, the badge, the quick actions.
Update `handoffs/HANDOFF.md`, add `devlogs/<date>.md`, write the next `NEXT-SESSION-*.md` if work remains, commit and push the branch.
