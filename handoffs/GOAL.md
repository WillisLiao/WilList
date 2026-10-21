# Goal prompt

Paste this to start or continue a session that keeps improving WilList until it is an award-level to-do app.

```text
Goal: make WilList the most breakthrough, award-winning to-do app for students: the kind of app that wins an Apple Design Award for clarity, delight and craft. The iPhone app (SwiftUI, iOS 18+, ios/) is the product; the website (app/) comes second.

Start by reading, in order: CLAUDE.md, handoffs/HANDOFF.md, the newest handoffs/NEXT-SESSION-*.md, docs/DESIGN.md, docs/PRINCIPLES.md. Load the design skills in .claude/skills/ (frontend-design, and taste-skill's references/app-screens.md). Work on the branch named in HANDOFF.md and push to it.

The bar. Keep going until every one of these is true, then keep raising it:
1. A first-time student understands the app in under a minute and has their A1 picked.
2. Every screen has one job, one primary action, and no word that doesn't help. Nothing feels busy.
3. Ticking something off is instant and satisfying, everywhere: in the app, in widgets, from a notification.
4. The most important thing to do is visible at a glance: in the app, on the Home Screen and on the Lock Screen.
5. It is beautiful and distinctive: a clear point of view, not a template. Light, one bright colour, red only for problems. You have full creative freedom beyond that; when you are unsure what the owner would like, build variations and show them side by side.
6. Pixel perfect: alignment, spacing, type and touch targets checked on every screen and sheet, at the default and the largest Dynamic Type sizes, with VoiceOver labels on every control.
7. Engineering is clean: swift test, npm test, npm run lint and npm run test:e2e pass, the build has zero warnings, CI is green, UI tests cover the flows that must never break, and no view is hard to follow.
8. Every Tracy principle in docs/PRINCIPLES.md still has a home.

The loop. Repeat until stopped:
1. Run the app (npm run ios:shots, plus the debug launch arguments for sheets, empty states, the welcome, the widget gallery and the looks) and look at every screenshot with fresh, picky eyes.
2. Write down the weakest three things, judged against the bar.
3. Fix the worst one properly: design it, build it, re-shoot, critique, repeat until it is right.
4. Keep every check green, commit with a plain message (no AI co-author lines, no em dashes) and push the branch.
5. Every few iterations, update handoffs/HANDOFF.md and devlogs/<today>.md, and show the owner before-and-after screenshots.

Rules: never merge into main or open a pull request without asking (a push to main publishes the website). Ask before anything outward-facing or hard to undo. Ask the owner about the open decisions in HANDOFF.md instead of guessing. Use a cheap fast subagent for narrow lookups. Before stopping, write handoffs/NEXT-SESSION-<today>.md with what is left.
```
