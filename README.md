# WilList

**Willis's list:** a student planner for iPhone, built on Brian Tracy's ABCDE method.

1. **Write it down.** Type it the way you'd say it ("Chem quiz thu 2pm"), or hand the Agent a syllabus or a photo of a timetable.
2. **Give the things that matter a letter.** A means serious if skipped, B mild, C nothing happens, D someone else can, E it doesn't matter.
3. **Do the A1 first.** Today leads with the one thing to do first.

Every feature maps to an idea from Tracy's *Phoenix Seminar*: [docs/PRINCIPLES.md](docs/PRINCIPLES.md).

## Four tabs

| | |
|---|---|
| **Today** | Today's date, the A1 first with a play button for a focus session, what you added to Today from Plan, then a quick checklist. Type a line and press return; "Call mum tomorrow 6pm" is due tomorrow at 6. Under the line, a letter, a reminder, a date and a repeat. |
| **Plan** | Today in ABCDE order (drag to re-rank), everything later by date, and a month calendar showing what's due each day. |
| **Progress** | The last 7 days in numbers and a chart by letter, suggestions with one action each, and the next 7 days' study blocks. |
| **Agent** | A chat that reads files, photos and words and proposes what to add, on a card you tick; nothing goes in until you tap Add. It answers questions about your plan too. A subscription. |

The profile picture at the top left of every tab opens Settings: your main goal and goals, to-do and study settings, the day's clocks and backups.

Every to-do and item has steps, a reminder (with Mark done on the notification), a due date and time, a repeat and a note.
Ticking something off fills the circle with a burst, a chime and a haptic.
Focus sessions run as a Live Activity on the Lock Screen and in the Dynamic Island, and two widgets show your A1 and today's to-dos.

## Working on it

`ios/` is the SwiftUI app for iOS 18 and later; the planner, the parser and the Agent's requests live in `ios/WilListCore`, a Swift package with its own tests (`swift test` in that folder).
`npm run ios:shots` takes screenshots in the iOS Simulator with a sample week loaded, and `npm run ios` installs on every paired iPhone and iPad on this Mac's Wi-Fi.
With a coding agent, start from `CLAUDE.md`, then `handoffs/HANDOFF.md`.
