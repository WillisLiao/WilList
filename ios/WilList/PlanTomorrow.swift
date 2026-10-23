import SwiftUI
import WilListCore

/// Plan tomorrow the night before, Tracy's habit, in two short steps: write down anything new,
/// then pick the one thing that matters most. The last page says what tomorrow starts with.
/// Close keeps what's been written and changes no letters.
struct PlanTomorrow: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// The day last planned, so Today stops asking once tomorrow is planned.
    @AppStorage("plannedFor") private var plannedFor = ""

    /// Tomorrow's A1: something already on tomorrow's list, or a line written here.
    enum Pick: Hashable { case item(String), line(Int) }

    #if DEBUG
    // `-evening 2` or `-evening 3` on launch opens that step with a line written (screenshots).
    @State private var step = UserDefaults.standard.integer(forKey: "evening").clamped(1, 3)
    @State private var lines = UserDefaults.standard.integer(forKey: "evening") == 2 ? ["Buy a lab notebook"] : []
    #else
    @State private var step = 1
    @State private var lines: [String] = []
    #endif
    @State private var draft = ""
    @State private var pick: Pick?
    /// Tomorrow's list as it was chosen from, kept still while the last page rises over it.
    @State private var chosenFrom: [Row]?
    @State private var sorting: LetterSorter.Batch?
    @FocusState private var typing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var today: Day { store.today }
    private var tomorrow: Day { addDays(today, 1) }
    /// Tomorrow's list worth doing yourself, A1 first.
    private var rows: [Row] { doRows(store.state.items, tomorrow, realToday: today) }
    private var waiting: [Item] { unsorted(store.state.items, today) }

    var body: some View {
        // The last page rises over the night like the sun, so the list never shows through it.
        ZStack {
            StepPage(field: Self.night, step: min(step, 2), of: 2, about: step == 1 ? recap : nil,
                     title: step == 1 ? "Anything new for tomorrow?" : "Which one first?",
                     subtitle: step == 1 ? "One thing per line."
                         : "If you could do only one, that’s your A1.",
                     exit: "Close", back: { step = 1 }, leave: close,
                     button: step == 1 ? "Next" : "Make it my A1", enabled: step == 1 || pick != nil, next: next) {
                if step == 1 {
                    LinesEntry(lines: $lines, draft: $draft, typing: $typing, placeholder: "Read chapter 5 by Friday")
                } else {
                    choices
                }
            }
            .accessibilityHidden(step == 3)
            if step == 3 {
                finished.transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(step == 3 ? .smooth(duration: 0.6) : .snappy, value: step)
        .sensoryFeedback(.selection, trigger: pick)
        .onAppear {
            if step == 1 { typing = true }
            pick = pick ?? rows.first.map { .item($0.item.id) }
        }
        .sheet(item: $sorting) { LetterSorter(ids: $0.ids) }
    }

    /// How today went, when something got done: "4 done today, starting with an A."
    private var recap: String? {
        let done = store.state.todos.filter { $0.done && $0.doneAt == today }.count + doneOn(store.state.items, today).count
        guard done > 0 else { return nil }
        return "\(done) done today" + (store.state.meta.firstDone[today] == "A" ? ", an A first" : "")
    }

    /// Tomorrow's list in ABCDE order, then the lines just written.
    private var choices: some View {
        VStack(spacing: 0) {
            ForEach(chosenFrom ?? rows) { row in
                A1Choice(title: row.item.title, detail: Fmt.detail(row, today), letter: row.priority,
                         chosen: pick == .item(row.item.id)) { pick = .item(row.item.id) }
            }
            ForEach(lines.indices, id: \.self) { i in
                A1Choice(title: lines[i], chosen: pick == .line(i)) { pick = .line(i) }
            }
        }
    }

    /// The evening's colour: planning happens at night.
    static let night = Color(hex: 0x262C66)

    /// The last page is drawn on the A1's course colour, as its focus session will be.
    private var finished: some View {
        let field = rows.first.map { CourseColor.of(store.state.courseColor($0.item.course)) } ?? Self.night
        return FinishPage(field: field, symbol: "sunrise.fill") {
            if let a1 = rows.first {
                Text("Tomorrow starts with")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(Fmt.noWidow(a1.item.title))
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text("Nothing for tomorrow")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
            }
            if !waiting.isEmpty {
                Text("\(waiting.count) \(waiting.count == 1 ? "needs" : "need") a letter")
                    .foregroundStyle(.white)
            }
        } buttons: {
            if !waiting.isEmpty {
                Button { sorting = LetterSorter.Batch(ids: waiting.map(\.id)) } label: {
                    Text("Letter them").foregroundStyle(.white).frame(maxWidth: .infinity)
                }
                .outlinedOnField()
            }
            Button { dismiss() } label: { Text("Done").foregroundStyle(field).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
                .tint(.white)
        }
    }

    // MARK: actions

    private func next() {
        guard step == 1 else { return finish() }
        LinesEntry.keep(&draft, in: &lines)
        typing = false
        if pick == nil && rows.isEmpty && lines.count == 1 { pick = .line(0) }
        if rows.isEmpty && lines.isEmpty { finish() } else { step = 2 }
    }

    private func finish() {
        chosenFrom = rows
        save(pick)
        plannedFor = tomorrow
        step = 3
    }

    private func close() {
        LinesEntry.keep(&draft, in: &lines)
        save(nil)
        dismiss()
    }

    /// Adds the lines written (waiting for a letter, unless one is the pick) and makes the pick
    /// tomorrow's A1.
    private func save(_ pick: Pick?) {
        let today = today, order = store.dateOrder, lines = lines
        guard !lines.isEmpty || pick != nil else { return }
        store.change { s in
            var added: [String] = []
            for line in lines {
                let it = makeItem(Item(quickAdd(line, today: today, minute: nowMinutes(), dateOrder: order)), s.settings, today, s.items)
                s.items.append(it)
                added.append(it.id)
            }
            switch pick {
            case .item(let id): s.makeA1(id, today: today)
            case .line(let i) where added.indices.contains(i): s.makeA1(added[i], today: today)
            default: break
            }
        }
    }
}

extension Store {
    /// From the planning time on (8:30 PM unless changed in More), it's time to plan tomorrow.
    var evening: Bool {
        #if DEBUG
        // `-night YES` or `-night NO` on launch fixes it, so tests and screenshots don't depend on the clock.
        if UserDefaults.standard.object(forKey: "night") != nil { return UserDefaults.standard.bool(forKey: "night") }
        #endif
        return nowMinutes() >= (timeToMin(state.settings.planTime) ?? 1230)
    }
}
