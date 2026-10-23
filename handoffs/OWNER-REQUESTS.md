# The owner's requests

Every request the owner (Willis) has made, newest direction first, with where it stands.
The owner's later words always win over earlier ones and over `handoffs/GOAL.md`.
Read this with `HANDOFF.md` before starting; add to it whenever the owner asks for something.

## Direction from 2026-10-24 (the big change)

| Request (the owner's words, lightly trimmed) | Status |
|---|---|
| "discard the website version then, in future we only want ios app, as well as mac app store app as your platforms" | To do: delete `app/`, its tests, the e2e test and the Pages workflow on the branch. The live site at https://willisliao.github.io/WilList/ stays up until the owner OKs the next push to `main`. The shot script still reads its sample plan from `app/src/sample.js`, so that moves into the iOS app first. |
| A Mac App Store app | To do, after the restructure: the same SwiftUI code with a Mac target (Mac Catalyst, Mac idiom) unless the owner says otherwise. |
| "icloud sync is not what we want, drop icloud, if people wanna sync progresses on different devices, then they sign in using google or facebook" | To do: remove `CloudSync.swift` and the iCloud entitlements; keep `PlanMerge` (it merges any two copies of a plan). Sign in with Google and Facebook; Apple's App Store rules (guideline 4.8) also require Sign in with Apple whenever those are offered. Default service: Firebase (Auth plus the plan stored per account). Needs the owner to create a Firebase project and a Facebook developer app. |
| "top left should be our 大頭貼 (profile picture); when pressed on it there will be options of settings, more, and other things" | To do: an avatar at the top left of every tab opening Settings: the account and sign-in, your main goal and goals, and everything that was in More. |
| "for the more tab, change it to agent tab" | To do: tabs become Today, Plan, Progress, Agent. |
| "get rid of all the import schedule options, or import api key options in our app" | To do: remove Bring in a schedule (Plan, Study, More), the share sheet's import (files shared to WilList go to the Agent instead), calendar links, and the Claude key field. |
| "our agent tab is just a chatbot that you can give it any file of your schedule or activity, anything that can tell it to log it in; it must have guardrails and all that standard AI security stuff" | To do: a chat that takes files and text, proposes what to log, and adds nothing without the student's OK. Files are data, never instructions; sizes and types are limited; its answers are checked before anything is saved. Its AI runs on a server so no key ships in the app. |
| "for business use we will let users subscribe to have this feature" | To do: the Agent behind an App Store subscription (StoreKit 2); the server checks the subscription. Needs the product set up in App Store Connect. |
| "the agent can also analyze and stuff" | To do: the Agent answers questions about the student's own plan and progress. |
| "get rid of the study tab as a whole, and change it to progress; that tab has all the analytics of the tasks you've done and some suggestions, forecasts, or anything" | To do: Progress replaces Study: what got done (by day, by letter, A first), the next days' load (the This week chart the owner liked moves here), and suggestions. |
| "for the this week chart ... i dont think we have option to enter what we gonna study at what time block so that should be added" | Open: asked before the Study tab was dropped. Likely a time on study sessions, or study blocks added by hand, shown in the load chart. Confirm with the owner once Progress exists. |
| "when adding tasks, dont matter in study tab or today or plan, get rid of the kind dropdown, that is useless" | Done on the branch: New task has no Kind; the kind is read from the words. The item details sheet still has Kind, to fix a wrong guess; ask the owner whether that should go too. |
| "for the plan date at the top we dont need to choose date there since we already choose date when we enter task, so remove the arrows of changing date" | Done on the branch. |
| "for the calendars I was thinking like showing what are planned in each day on the calendar" | Done on the branch: each day shows up to two titles in their colours, or one and "+2"; a tapped day is listed in full. |
| "give me the website url" | Answered: https://willisliao.github.io/WilList/ (the older website). |
| "record all of my requests" | This file. |

## Earlier on 2026-10-24

| Request | Status |
|---|---|
| "get rid of the set main goal section in plan, and replace it with the current date" | Done; the main goal is now in More (moving to Settings under the avatar). |
| "delete the plan tomorrow row" | Done; Plan tomorrow stays on Today's evening nudge and the evening notification. |
| An exam or deadline added in Study didn't show in Study, only in Plan | Fixed: undated exams and deadlines show in Coming up. Study itself is going (see above). |
| A simple calendar in Study and in Plan, under the task rows | Done (the Study one moves to Progress or goes with Study). |
| "get rid of the give everything a letter section in plan ... no need explanation" | Done. |
| "get rid of the do this first add your a1 block in today" (the A1 card) | Done: the A1 is Today's first row, with a play button for focus. |
| "remove \"no more cramming\"" | Done. |
| "the background color should be lighter, at least 50% lighter" | Done: the slate mixed 55% with white, dark words on it. |
| "this is also good" (Study's This week chart) | Kept; moves to Progress. |
| Display Zoom (Larger Text) jumbled the A1 buttons; some rows had a gap instead of a circle | Done (the buttons went with the card; every Plan row has its circle). |
| "see all plans in plans, and only todays in today, and whichever of those two include study then they will be in study tab"; date and time picked in one row | Done (Later in Plan, one-row due date). |
| A new A comes after the A's already there; dragging re-ranks | Done. |
| "just deploy now" / "deploy now" | Done: installed on the iPhone and iPad, and `main` fast-forwarded to `8a23b92` with the owner's OK. |

## Earlier (2026-10-23)

| Request | Status |
|---|---|
| "the app has too many words, each item, thing, description should have minimal words as possible" | Done (rules in `docs/DESIGN.md`, Words). |
| "white nav bar keeps changing to background color when pressed or scrolled" | Done: WilList's own white tab bar. |
| The widget gallery's look: parts on cards on a soft background, the softer teal; letters red, orange, yellow, green, blue | Done (the Lagoon look on cards). |
| "there are no rules, for anything"; a visually captivating experience | Standing. |
| Don't spend time on the largest accessibility text sizes; the owner uses Display Zoom set to Larger Text (about 320 points wide) | Standing. |

## Standing rules

- Work on a branch and push it; ask before merging into `main` (it publishes the website while the Pages workflow exists) or opening a pull request.
- Ask before anything outward-facing or hard to undo.
- Commit messages are plain, with no AI co-author or agent attribution.
- No em dashes anywhere.
- Never commit API keys or personal data.
