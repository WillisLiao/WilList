import SwiftUI
import WilListCore

/// The day's first thing at the top of Today: its letter, what it is and what it's about, Mark
/// done, and how many days in a row started with an A. In Meadow it is the poster of the day, its
/// title set large on the green; the other looks draw it as a card. When it's done, the next one
/// moves up into its place, and the toast offers Undo.
struct A1Card: View {
    @Environment(Store.self) private var store
    let row: Row
    /// Opens the item's details.
    let open: (Item) -> Void
    /// The row marked done, and the row whose words have faded out after it, so they're gone before
    /// the next A moves up. Kept by row, so the next A arrives fresh.
    @State private var doneKey: String?
    @State private var faded: String?
    /// The last A of the day, faded out whole, buttons too, before the poster says the A's are done.
    /// Decided at Mark done: by the time it leaves, the plan no longer has it.
    @State private var gone: String?
    /// The streak as shown. It catches up once the card has settled, so a new line doesn't land on
    /// the buttons while they move.
    @State private var shownStreak = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The colour it sits on when filled: its course's.
    @Environment(\.field) private var field
    /// The poster's title: headline size on a poster, still growing with the text size setting.
    @ScaledMetric(relativeTo: .largeTitle) private var posterTitle: CGFloat = 44

    private var today: Day { store.today }
    private var done: Bool { doneKey == row.key }
    private var poster: Bool { Look.current.hero == .poster }
    // On a field of colour (the poster, the Frog look's solid card) every word is white: dimmed
    // white falls below 4.5:1 on the green, so size and weight make the difference instead.
    private var solid: Bool { Look.current.filled }
    private var ink: Color { solid ? .white : .primary }
    private var grey: Color { solid ? .white : .secondary }

    var body: some View {
        let streak = a1Streak(store.state.meta.firstDone, today)
        VStack(alignment: .leading, spacing: poster ? 12 : 10) {
            HStack(spacing: 10) {
                LetterMark(letter: row.priority, label: row.label, large: true, onBrand: solid)
                Text("Do this first")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(grey)
                Spacer()
                if row.overdue {
                    Text("Overdue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, solid ? 8 : 0)
                        .padding(.vertical, solid ? 3 : 0)
                        .background(solid ? Color.white : .clear, in: Capsule())
                }
            }
            // The words sit in a frame of their own, so the next A moves up into it without the two
            // titles crossing.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    title(struck: false)
                        .opacity(done ? 0.75 : 1)
                        // Mark done crosses it off: a line drawn through the title, left to right.
                        .overlay(alignment: .leading) {
                            title(struck: true)
                                .mask(alignment: .leading) {
                                    Rectangle().scaleEffect(x: done || reduceMotion ? 1 : 0, anchor: .leading)
                                }
                                .opacity(done ? 1 : 0)
                                .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.45), value: done)
                                .accessibilityHidden(true)
                        }
                        .padding(.bottom, poster ? 2 : 0)
                        .background {
                            // The Notebook look runs a highlighter over the one thing to do.
                            if Look.current.hero == .outline {
                                RoundedRectangle(cornerRadius: 4).fill(Color.brand.opacity(0.2)).padding(.horizontal, -4)
                            }
                        }
                    if let detail = Fmt.detail(row, today) {
                        Text(detail).foregroundStyle(grey)
                    }
                    // A session is part of something bigger: say what it is for and when that is due.
                    if row.session != nil, let due = Fmt.when(row.item, today) {
                        Text([due, row.item.course].compactMap { $0 }.joined(separator: ", ")).foregroundStyle(grey)
                    }
                }
                .opacity(faded == row.key ? 0 : 1)
                // The next A moves up into its place.
                .id(row.key)
                .transition(reduceMotion ? .opacity : .push(from: .bottom))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Room for the Notebook look's highlighter, which reaches past the words.
            .padding(.horizontal, 4)
            .clipped()
            .padding(.horizontal, -4)
            // Side by side; one above the other at the largest text sizes, so no word breaks.
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                // Start: a focus session on it, with the timer on the Lock Screen too.
                Button { store.startFocus(row) } label: {
                    Label("Start", systemImage: "play.fill")
                        .foregroundStyle(solid ? Color.white : Color.brand)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
                }
                .buttonStyle(.bordered)
                .tint(solid ? Color.white : Color.brand)
                .accessibilityHint("Starts a focus timer for \(Fmt.minutes(row.session?.minutes ?? store.state.settings.taskMin))")
                Button(action: finish) {
                    Label(done ? "Done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(solid ? field : Color.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(solid ? Color.white : Color.brand)
                .accessibilityIdentifier("markA1Done")
                .sensoryFeedback(.success, trigger: done) { _, new in new }
            }
            .controlSize(.large)
            .labelStyle(WordsWhenLarge())
            .padding(.top, poster ? 10 : 6)
            if shownStreak > 0 {
                Text("\(shownStreak) \(shownStreak == 1 ? "day" : "days") in a row you started with an A.")
                    .font(.footnote)
                    .foregroundStyle(grey)
                    .frame(maxWidth: .infinity, alignment: poster ? .leading : .center)
            }
        }
        .opacity(gone == row.key ? 0 : 1)
        .modifier(A1Ground(poster: poster))
        .contentShape(Rectangle())
        .onTapGesture { open(row.item) }
        // After Undo the same A comes back: it starts over rather than still saying Done.
        .onAppear { doneKey = nil; faded = nil; gone = nil; shownStreak = streak }
        .task(id: streak) {
            guard streak != shownStreak else { return }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.25)) { shownStreak = streak }
        }
        .onChange(of: row.key) { doneKey = nil; faded = nil; gone = nil }
    }

    private func title(struck: Bool) -> some View {
        Text(row.item.title)
            .font(poster ? .system(size: posterTitle, weight: .bold) : .title2.weight(.semibold))
            .fontDesign(Look.current.titles)
            .tracking(poster ? -0.6 : 0)
            .strikethrough(struck, color: ink)
            // The struck copy only draws its line over the title.
            .foregroundStyle(struck ? Color.clear : ink)
            // A long title shrinks a little before it runs past three lines.
            .lineLimit(poster ? 3 : nil)
            .minimumScaleFactor(poster ? 0.7 : 1)
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
            withAnimation(.snappy) {
                store.change(undo: "Marked \u{201C}\(title)\u{201D} done") { s in
                    if let r = dayRows(s.items, today, realToday: today).first(where: { $0.key == key }) { s.complete(r, today: today) }
                }
            }
        }
    }
}

/// The poster sits straight on the green that Today paints behind it; the other looks get a card.
private struct A1Ground: ViewModifier {
    let poster: Bool

    func body(content: Content) -> some View {
        if poster {
            content.padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 28)
        } else {
            content.heroCard()
        }
    }
}

/// After the day's last A, the poster stays to say so: finishing the most important thing is its
/// own reward. Green, the colour of everything done.
struct AsDone: View {
    /// Everything finished today.
    let done: Int
    let streak: Int
    @ScaledMetric(relativeTo: .largeTitle) private var posterTitle: CGFloat = 44
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .symbolEffect(.bounce, value: shown)
                .accessibilityHidden(true)
            Text("Your A’s are done.")
                .font(.system(size: posterTitle, weight: .bold))
                .fontDesign(Look.current.titles)
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text([done > 0 ? "\(done) done today." : nil,
                  streak > 0 ? "\(streak) \(streak == 1 ? "day" : "days") in a row you started with an A." : nil]
                .compactMap { $0 }.joined(separator: " "))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .onAppear { shown = true }
    }
}
