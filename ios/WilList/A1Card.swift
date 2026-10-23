import SwiftUI
import WilListCore

/// The day's first thing at the top of Today, on a pale teal card: its letter, what it is and
/// what it's about, Mark done, and how many days in a row started with an A. When it's done, the
/// next one moves up into its place, and the toast offers Undo.
struct A1Card: View {
    @Environment(Store.self) private var store
    let row: Row
    /// Opens the item's details.
    let open: (Item) -> Void
    /// The row marked done, and the row whose words have faded out after it, so they're gone before
    /// the next A moves up. Kept by row, so the next A arrives fresh.
    @State private var doneKey: String?
    @State private var faded: String?
    /// The last A of the day, faded out whole, buttons too, before the card says the A's are done.
    /// Decided at Mark done: by the time it leaves, the plan no longer has it.
    @State private var gone: String?
    /// The streak as shown. It catches up once the card has settled, so a new line doesn't land on
    /// the buttons while they move.
    @State private var shownStreak = 0
    /// The next A's words, about to rise into the card. The card moves them itself: the change that
    /// brings the next A isn't animated, since the list would animate everything in the row.
    @State private var rising = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var today: Day { store.today }
    private var done: Bool { doneKey == row.key }

    var body: some View {
        let streak = a1Streak(store.state.meta.firstDone, today)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LetterMark(letter: row.priority, label: row.label, large: true)
                Text("Do this first")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if row.overdue {
                    Text("Overdue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            // The words sit in a frame of their own, so the next A moves up into it without the two
            // titles crossing.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    title(struck: false)
                        .opacity(done ? 0.75 : 1)
                        // A tap on the card opens its details; with VoiceOver, the title does.
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Opens its details")
                        .accessibilityAction { open(row.item) }
                        // Mark done crosses it off: a line drawn through the title, left to right.
                        .overlay(alignment: .leading) {
                            title(struck: true)
                                .mask(alignment: .leading) {
                                    Rectangle().scaleEffect(x: done || reduceMotion ? 1 : 0, anchor: .leading)
                                }
                                .opacity(done ? 1 : 0)
                                .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.45), value: done)
                                // The next A's copy starts fresh, not reshaped from this one's line.
                                .id(row.key)
                                .transition(.identity)
                                .accessibilityHidden(true)
                        }
                    // Each line at its full height, so none is cut short and re-wrapped while the
                    // card changes size.
                    if let detail = Fmt.detail(row, today) {
                        Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    // A session is part of something bigger: say what it is for and when that is due.
                    if row.session != nil, let due = Fmt.when(row.item, today) {
                        Text([due, row.item.course].compactMap { $0 }.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .opacity(faded == row.key ? 0 : 1)
                // The next A moves up into its place.
                .opacity(rising ? 0 : 1)
                .offset(y: rising && !reduceMotion ? 28 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The next A's words rise from inside the card, not from over the buttons.
            .clipped()
            // Side by side; one above the other at the largest text sizes, so no word breaks.
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                // Start: a focus session on it, with the timer on the Lock Screen too.
                Button { store.startFocus(row) } label: {
                    Label("Start", systemImage: "play.fill")
                        .foregroundStyle(Color.brand)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
                }
                .buttonStyle(.bordered)
                .tint(Color.brand)
                .accessibilityHint("Starts a focus timer for \(Fmt.minutes(row.session?.minutes ?? store.state.settings.taskMin))")
                Button(action: finish) {
                    // The words change at once and the check fills; crossfaded, the two words overlap.
                    Label {
                        Text(done ? "Done" : "Mark done").contentTransition(.identity)
                    } icon: {
                        Image(systemName: done ? "checkmark.circle.fill" : "checkmark")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    // The next A's button starts fresh, without the last one's check fading where it was.
                    .id(row.key)
                    .transition(.identity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand)
                .accessibilityIdentifier("markA1Done")
                .sensoryFeedback(.success, trigger: done) { _, new in new }
            }
            .controlSize(.large)
            .labelStyle(WordsWhenLarge())
            // On an iPad the buttons stop at a phone's width rather than stretching across.
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.top, 6)
            if shownStreak > 0 {
                Text("\(shownStreak) \(shownStreak == 1 ? "day" : "days") in a row you started with an A.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(gone == row.key ? 0 : 1)
        // Another A arriving with an animation, as Undo brings one back, would cross the two titles
        // and buttons; the card brings the new one in itself.
        .transaction(value: row.key) { $0.animation = nil }
        .heroCard()
        .contentShape(Rectangle())
        .onTapGesture { open(row.item) }
        // After Undo the same A comes back: it starts over rather than still saying Done.
        .onAppear { doneKey = nil; faded = nil; gone = nil; shownStreak = streak }
        .task(id: streak) {
            guard streak != shownStreak else { return }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.25)) { shownStreak = streak }
        }
        .onChange(of: row.key) {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { doneKey = nil; faded = nil; gone = nil; rising = true }
            Task { @MainActor in withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.5)) { rising = false } }
        }
    }

    private func title(struck: Bool) -> some View {
        Text(Fmt.noWidow(row.item.title))
            .font(.title2.weight(.semibold))
            .strikethrough(struck, color: .primary)
            // The struck copy only draws its line over the title.
            .foregroundStyle(struck ? Color.clear : Color.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // The button fills and the title is crossed off, its words fade, then the next thing moves up.
    private func finish() {
        guard !done else { return }
        doneKey = row.key
        Chime.play()
        let key = row.key, title = row.item.title, today = today
        let last = doRows(store.state.items, today).count == 1
        Task {
            try? await Task.sleep(for: .milliseconds(520))
            withAnimation(.easeIn(duration: 0.14)) {
                faded = key
                if last { gone = key }
            }
            try? await Task.sleep(for: .milliseconds(140))
            // Not animated: the list would animate everything in the row, the old words back over
            // the new ones. The card takes its new height while its words are hidden, and the
            // next A's words rise in on their own.
            store.change(undo: "Marked \u{201C}\(title)\u{201D} done") { s in
                if let r = dayRows(s.items, today, realToday: today).first(where: { $0.key == key }) { s.complete(r, today: today) }
            }
        }
    }
}

/// After the day's last A, the card stays to say so: finishing the most important thing is its
/// own reward.
struct AsDone: View {
    /// Everything finished today.
    let done: Int
    let streak: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.brand)
                .symbolEffect(.bounce, value: shown)
                // The tick's ring and sparks, at the size of the day's biggest win.
                .background { if !reduceMotion { TickBurst(done: shown).scaleEffect(1.7) } }
                .accessibilityHidden(true)
            Text("Your A’s are done.")
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text([done > 0 ? "\(done) done today." : nil,
                  streak > 0 ? "\(streak) \(streak == 1 ? "day" : "days") in a row you started with an A." : nil]
                .compactMap { $0 }.joined(separator: " "))
                .foregroundStyle(.secondary)
                // Its full height from the start: otherwise, while the row grows, it is cut short
                // and re-wraps on the way, its words crossing.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard()
        .onAppear { shown = true }
    }
}

/// Before anything has a letter, the card asks the question the day turns on, with one way to
/// answer it: letter what's waiting, or add the one thing with its A.
struct NoA1: View {
    /// Items waiting for a letter.
    let waiting: Int
    let letterThem: () -> Void
    let add: () -> Void

    var body: some View {
        AskCard(question: "What matters most today?",
                detail: waiting > 0
                    ? "\(waiting) \(waiting == 1 ? "thing waits" : "things wait") for a letter. The most important one becomes your A1."
                    : "Add it and give it an A. It leads your day, here and on your widgets.",
                action: waiting > 0 ? "Letter them" : "Add your A1",
                color: .brand,
                perform: waiting > 0 ? letterThem : add) {
            // The empty slot: the A1 mark drawn dashed, as on Plan before anything is lettered.
            LetterMark(letter: nil, label: "A1", large: true)
                .accessibilityHidden(true)
            Text("Do this first")
        }
    }
}

/// In the evening, with nothing left for today and tomorrow not planned yet, the card turns to
/// the night and asks what matters most tomorrow.
struct Tonight: View {
    let plan: () -> Void

    var body: some View {
        AskCard(question: "What matters most tomorrow?",
                detail: "Two short steps tonight, and the morning starts with your A1.",
                action: "Plan tomorrow",
                color: PlanTomorrow.night,
                perform: plan) {
            Image(systemName: "moon.fill").foregroundStyle(PlanTomorrow.night).accessibilityHidden(true)
            Text("This evening")
        }
    }
}

/// A question in the A1's place, on a card of its colour, with the one button that answers it.
private struct AskCard<Label: View>: View {
    let question: String
    let detail: String
    let action: String
    let color: Color
    let perform: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) { label }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(question)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: perform) {
                Text(action).foregroundStyle(Color.white).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .controlSize(.large)
            // On an iPad the button stops at a phone's width, as the A1 card's do.
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCard(color)
    }
}
