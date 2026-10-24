# The owner's requests

Every request the owner (Willis) has made, newest direction first, with where it stands.
The owner's later words always win over earlier ones and over `handoffs/GOAL.md`.
Read this with `HANDOFF.md` before starting; add to it whenever the owner asks for something.

## Night of 2026-10-24: Today in time order, Play, study blocks, Goals

| Request (the owner's words, lightly trimmed) | Status |
|---|---|
| "for my app's today tab I want it to also be like the website, being a column of organized tasks based on time" | Done on the branch: Today runs in time order from now (classes and study blocks at their times, the lettered work in the free time, A's first, timed to-dos, free time, the end of the day, what won't fit), with the checklist under it. |
| "next to the add to favorites icon there should also be a play button that we can start tackling those tasks ... after clicking play you should also be able to choose the countdown duration"; "the play button ... must also be put in tasks in plan tab, basically all tasks should have a play button" | Done on the branch: Play beside every task on Today (to-dos too) and in Plan, asking "Focus for" 15, 25, 45 minutes, 1 hour, 1 h 30 min, or the session's or block's planned time. E items (dropped) have none. |
| "coming up section should also be added to today, so you not only have today's task, but have a sense of future tasks" | Done on the branch: Coming up under the checklist, the next week's deadlines and exams and every to-do due later. |
| "let's bring the goal tab back, but it between progress and agent" | Done on the branch: Today, Plan, Progress, Goals, Agent; the goals left Settings. |
| Study blocks: "study blocks you add by hand, can repeat each week option" | Done on the branch: Plan's + asks Task or Study block; New study block reads "Organic chem tue 7pm 2h" and has Every week. Play counts down the block's length. |
| "yes, kind picker is useless" (item details) | Done on the branch. |
| The Agent's price: "any price ... see if you can integrate [Claude Code Pro, ChatGPT Plus, OpenCode Go] via api key, would suggest opencode go" | Answered: none of them can power the Agent for other students. OpenCode Go's terms allow only "your own internal use", not "for the benefit of any third party"; Claude Pro and ChatGPT Plus include no API access. The plan stays a pay-as-you-go Anthropic key on WilList's server; the price is to be set once a live test shows what a conversation costs. Offered: debug builds on the owner's own phone could use their OpenCode Go key, as that is their own use (no answer yet). |
| "yes merge" | Done: `main` fast-forwarded to `d911eac`. |
| Worry Buster, 20 Ideas, Pre-game, the seven questions: "those aren't needed, we are already reintroducing the goal tab" | Done: they stay on the website only (`docs/PRINCIPLES.md`). |
| "what letter sorter?" | Explained with a screenshot: the one-item-at-a-time A to E screen, opened only by Review on Progress for C to E items over two weeks old. The owner: "Keep the letter sorter: Review on Progress opens it for old C to E tasks." Kept as it is. |
| A privacy policy URL | Left blank; still needed for App Store review. |

## Direction from 2026-10-24 (the big change)

| Request (the owner's words, lightly trimmed) | Status |
|---|---|
| "discard the website version then, in future we only want ios app, as well as mac app store app as your platforms" | Done on the branch (2026-10-24, night): `app/`, its tests, the e2e test and the Pages deploy are gone; the shots' sample week lives in the app (`-plan sample`). The live site at https://willisliao.github.io/WilList/ stays up until GitHub Pages is turned off in the repository's settings: the owner's call. Merging no longer redeploys it. |
| A Mac App Store app | Builds on the branch: Mac Catalyst on the same target, Mac idiom, same bundle id, sandboxed; Live Activities are left out on the Mac. Looked at through the app's own snapshots; the title bar's buttons still need a look on screen. Needs the owner's Apple team to sign and the Mac app in App Store Connect. |
| "icloud sync is not what we want, drop icloud, if people wanna sync progresses on different devices, then they sign in using google or facebook" | iCloud: done on the branch (`CloudSync.swift`, the iCloud and push entitlements and the background mode are gone; `PlanMerge` stays, it merges any two copies of a plan). Sign-in: to do. Sign in with Google and Facebook; Apple's App Store rules (guideline 4.8) also require Sign in with Apple whenever those are offered. Default service: Firebase (Auth plus the plan stored per account). Needs the owner to create a Firebase project and a Facebook developer app. |
| "top left should be our 大頭貼 (profile picture); when pressed on it there will be options of settings, more, and other things" | Done on the branch: a profile picture at the top left of every tab opens Settings (everything that was in More; the goals moved to their own tab again later that night). The account and sign-in join it once they exist. |
| "for the more tab, change it to agent tab" | Done on the branch: the tabs are Today, Plan, Progress, Goals, Agent. |
| "get rid of all the import schedule options, or import api key options in our app" | Done on the branch: Bring in a schedule, the Claude key field (and its keychain item) are gone, and files shared to WilList open in the Agent. A calendar link can still be followed, but only when the student types it to the Agent and taps Follow; Settings lists those links. |
| "get rid of the needs a letter, letter them lines"; "unlettered, shouldnt be a problem, get rid of all things that notify some task needing a letter"; "i also dont like the no letters task having the blank icon, it shouldnt have icon, if it's no letter" | Done on the branch: nothing asks for a letter any more (Today, Plan, Progress, Plan tomorrow), and an item without one has no mark; it sits under Later in Plan by date. Its details still give it a letter. |
| "our agent tab is just a chatbot that you can give it any file of your schedule or activity, anything that can tell it to log it in; it must have guardrails and all that standard AI security stuff" | Done in the app on the branch: a chat that takes files, photos and words, proposes what to log on a card to tick, and adds nothing without the student's tap. Guardrails are listed in `devlogs/2026-10-24.md`. Its AI is meant to run on WilList's own server (no key ships in the app); its contract is in `docs/AGENT-SERVER.md`, but the server doesn't exist yet, so a release build shows Coming soon. Not yet tried against the live API (no key on this Mac). |
| "for business use we will let users subscribe to have this feature" | Done in the app on the branch: StoreKit 2's subscription page for `com.lull.willist.agent.monthly`, with Restore; `ios/Agent.storekit` tries it from Xcode at a placeholder 4.99 a month. Needs the owner: the price, the product in App Store Connect, and a privacy policy URL. The server is to check the subscription. |
| "the agent can also analyze and stuff" | Done on the branch: the Agent reads the plan (`read_plan`) and answers questions about it and about progress. |
| "get rid of the study tab as a whole, and change it to progress; that tab has all the analytics of the tasks you've done and some suggestions, forecasts, or anything" | Done on the branch: Progress replaces Study: the last 7 days in numbers, the same days done by letter, suggestions with one action each, the next 7 days' load (the This week chart), and exams and deadlines coming up. |
| "for the this week chart ... i dont think we have option to enter what we gonna study at what time block so that should be added" | Done on the branch: study blocks added by hand (see the night of 2026-10-24). |
| "when adding tasks, dont matter in study tab or today or plan, get rid of the kind dropdown, that is useless" | Done on the branch: neither New task nor item details has Kind; the kind is read from the words. |
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
