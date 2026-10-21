import SwiftUI
import WilListCore

/// The day's first thing, as one card at the top of Today: its letter, what it is and what it's
/// about, Mark done, and how many days in a row started with an A. When it's done, the next one
/// moves up into the card, and the toast offers Undo.
struct A1Card: View {
    @Environment(Store.self) private var store
    let row: Row
    /// Opens the item's details.
    let open: (Item) -> Void
    @State private var done = false

    private var today: Day { store.today }
    // On a card filled with the brand colour (the Frog look) the words turn white.
    private var solid: Bool { Look.current.hero == .solid }
    private var ink: Color { solid ? .white : .primary }
    private var grey: Color { solid ? .white.opacity(0.85) : .secondary }

    var body: some View {
        let streak = a1Streak(store.state.meta.firstDone, today)
        VStack(alignment: .leading, spacing: 10) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(row.item.title)
                    .font(.title2.weight(.semibold))
                    .fontDesign(Look.current.titles)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
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
            HStack(spacing: 10) {
                // Start: a focus session on it, with the timer on the Lock Screen too.
                Button { store.startFocus(row) } label: {
                    Label("Start", systemImage: "play.fill")
                        .foregroundStyle(solid ? Color.white : Color.brand)
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.bordered)
                .tint(solid ? Color.white : Color.brand)
                .accessibilityHint("Starts a focus timer for \(Fmt.minutes(row.session?.minutes ?? store.state.settings.taskMin))")
                Button(action: finish) {
                    Label(done ? "Done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "checkmark")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(solid ? Color.brand : Color.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(solid ? Color.white : Color.brand)
                .accessibilityIdentifier("markA1Done")
                .sensoryFeedback(.success, trigger: done) { _, new in new }
            }
            .controlSize(.large)
            .padding(.top, 6)
            if streak > 0 {
                Text("\(streak) \(streak == 1 ? "day" : "days") in a row you started with an A.")
                    .font(.footnote)
                    .foregroundStyle(grey)
                    .frame(maxWidth: .infinity)
            }
        }
        .heroCard()
        .contentShape(Rectangle())
        .onTapGesture { open(row.item) }
    }

    // The button fills first, then the next thing moves up.
    private func finish() {
        guard !done else { return }
        done = true
        Chime.play()
        let key = row.key, title = row.item.title, today = today
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "Marked \u{201C}\(title)\u{201D} done") { s in
                    if let r = dayRows(s.items, today, realToday: today).first(where: { $0.key == key }) { s.complete(r, today: today) }
                }
            }
        }
    }
}
