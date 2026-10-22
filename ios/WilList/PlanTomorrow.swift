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
    @State private var sorting: LetterSorter.Batch?
    @FocusState private var typing: Bool

    private var today: Day { store.today }
    private var tomorrow: Day { addDays(today, 1) }
    /// Tomorrow's list worth doing yourself, A1 first.
    private var rows: [Row] { doRows(store.state.items, tomorrow, realToday: today) }
    private var waiting: [Item] { unsorted(store.state.items, today) }

    var body: some View {
        Group {
            if step < 3 {
                StepPage(step: step, of: 2, about: step == 1 ? recap : nil,
                         title: step == 1 ? "Anything new for tomorrow?" : "Which one first?",
                         subtitle: step == 1 ? "Write down what came up today, one thing per line. Dates are read for you."
                             : "If you could do only one thing tomorrow, which would it be? That's your A1.",
                         exit: "Close", back: { step = 1 }, leave: close,
                         button: step == 1 ? "Next" : "Make it my A1", enabled: step == 1 || pick != nil, next: next) {
                    if step == 1 {
                        LinesEntry(lines: $lines, draft: $draft, typing: $typing, placeholder: "Read chapter 5 by Friday")
                    } else {
                        choices
                    }
                }
            } else {
                finished
            }
        }
        .animation(.snappy, value: step)
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
        return "\(done) done today" + (store.state.meta.firstDone[today] == "A" ? ", starting with an A." : ".")
    }

    /// Tomorrow's list in ABCDE order, then the lines just written.
    private var choices: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                A1Choice(title: row.item.title, detail: Fmt.detail(row, today), letter: row.priority,
                         chosen: pick == .item(row.item.id)) { pick = .item(row.item.id) }
            }
            ForEach(lines.indices, id: \.self) { i in
                A1Choice(title: lines[i], chosen: pick == .line(i)) { pick = .line(i) }
            }
        }
    }

    private var finished: some View {
        FinishPage(symbol: "sunrise.fill", bounce: step) {
            if let a1 = rows.first {
                Text("Tomorrow starts with")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(a1.item.title)
                    .font(.title.bold())
                    .fontDesign(Look.current.titles)
                    .accessibilityAddTraits(.isHeader)
                Text("It'll be at the top of Today and on your widgets in the morning.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Nothing planned for tomorrow")
                    .font(.title.bold())
                    .fontDesign(Look.current.titles)
                    .accessibilityAddTraits(.isHeader)
                Text("Add what you need to do in Plan and give the most important an A.")
                    .foregroundStyle(.secondary)
            }
            if !waiting.isEmpty {
                Text("\(waiting.count) still \(waiting.count == 1 ? "waits" : "wait") for a letter.")
                    .foregroundStyle(.secondary)
            }
        } buttons: {
            if !waiting.isEmpty {
                Button { sorting = LetterSorter.Batch(ids: waiting.map(\.id)) } label: {
                    Text("Letter them").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
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
