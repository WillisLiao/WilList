import SwiftUI
import WilListCore

/// Plan: your main goal, the day in ABCDE order (A1 first, the same A1 that tops Today), and
/// anything still waiting for a letter. Plan tomorrow and the full list of goals are one tap away.
struct PlanView: View {
    // `-open goals` on launch opens Your goals (screenshots).
    @State private var path = UserDefaults.standard.string(forKey: "open") == "goals" ? [PlanPage.goals] : []

    var body: some View {
        NavigationStack(path: $path) {
            PlanList()
                .navigationDestination(for: PlanPage.self) { _ in GoalsList() }
        }
    }
}

enum PlanPage: Hashable { case goals }

/// The main goal, the day in ABCDE order with the A1 first, what's waiting for a letter, and the
/// ways to plan ahead.
struct PlanList: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var importing = false
    @State private var editing: Item?
    @State private var ticking: Set<String> = []
    @State private var searching = false
    @State private var sorting: LetterSorter.Batch?

    private var today: Day { store.today }
    private var rows: [Row] { dayRows(store.state.items, today) }
    private var waiting: [Item] { unsorted(store.state.items, today) }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                goalRow
                Section {
                    if rows.isEmpty { emptyCard }
                    ForEach(rows) { itemRow($0) }
                        .onMove(perform: move)
                }
                if !waiting.isEmpty {
                    Section {
                        ForEach(waiting) { waitingRow($0) }
                    } header: {
                        HStack {
                            Text("Needs a letter")
                            Spacer()
                            Button { sorting = LetterSorter.Batch(ids: waiting.map(\.id)) } label: {
                                Text("Letter them").tapArea()
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.brand)
                            .buttonStyle(.borderless)
                        }
                    }
                    .id("letters")
                }
                Section { planningRows }
                    .id("bottom")
            }
            .listStyle(.plain)
            .readableColumn()
            #if DEBUG
            // `-scroll letters` or `-sheet add|import` on launch, for screenshots.
            .onAppear {
                UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) }
                adding = UserDefaults.standard.string(forKey: "sheet") == "add"
                importing = UserDefaults.standard.string(forKey: "sheet") == "import"
            }
            #endif
        }
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Search", systemImage: "magnifyingglass") { searching = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { adding = true }
            }
        }
        .sheet(isPresented: $searching) { SearchView() }
        .sheet(isPresented: $adding) { AddItemSheet() }
        .sheet(isPresented: $importing) { ImportSheet() }
        .onChange(of: store.incomingFile, initial: true) { if store.incomingFile != nil { importing = true } }
        .onChange(of: store.opening, initial: true) {
            if let id = store.opening, let it = store.state.items.first(where: { $0.id == id }) {
                store.opening = nil
                editing = it
            }
        }
        .sheet(item: $editing) { ItemEditor(item: $0) }
        .sheet(item: $sorting) { LetterSorter(ids: $0.ids) }
        .toastHost()
    }

    // MARK: rows

    private var goalRow: some View {
        let goal = store.state.mdp, others = store.state.goals.count
        return NavigationLink(value: PlanPage.goals) {
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.isEmpty ? "Set your main goal" : goal)
                    .font(.headline)
                    .fontDesign(Look.current.titles)
                    .foregroundStyle(goal.isEmpty ? Color.brand : .primary)
                    .lineLimit(2)
                Text(goal.isEmpty ? "The one goal that would change the most for you"
                     : others == 0 ? "Your main goal" : "Your main goal and \(others) more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listRowSeparator(.hidden)
    }

    /// The A1's place when there is nothing to do first: what goes here, and the one way to fill it.
    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                LetterMark(letter: nil, label: "A1", large: true)
                Text("Do this first")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(emptyMessage)
                .fixedSize(horizontal: false, vertical: true)
            // With items waiting below, their Letter buttons are the way to fill this card.
            if waiting.isEmpty {
                Button { adding = true } label: {
                    Text("Add a task").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .heroCard(empty: true)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
    }

    private var emptyMessage: String {
        if !waiting.isEmpty { return "Give the items below a letter. Your most important one becomes your A1, at the top of Today." }
        if let next = nextUp { return "Nothing to do today. Next: \(next.title), \(Fmt.day(next.day, today, inSentence: true))." }
        return "Add what you need to do and give each one a letter. Your A1 goes to the top of Today, so you always know what to do first."
    }

    /// The soonest lettered thing still to come, for a day with nothing on it.
    private var nextUp: (title: String, day: Day)? {
        store.state.items
            .filter { isOpen($0, today) && ($0.priority.map { $0 <= .C } ?? false) }
            .compactMap { it in (it.sessions.first { !$0.done }?.date ?? it.date).map { (title: it.title, day: $0) } }
            .filter { diffDays(today, $0.day) > 0 }
            .min { $0.day < $1.day }
    }

    private func itemRow(_ row: Row) -> some View {
        let done = ticking.contains(row.key)
        return HStack(spacing: 8) {
            CheckButton(done: done) { complete(row) }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.item.title)
                    .strikethrough(row.priority == .E || done, color: .secondary)
                    .foregroundStyle(row.priority == .E ? .secondary : .primary)
                if let line = line(row) { line.font(.subheadline) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
            letterMenu(row.item) { LetterMark(letter: row.priority, label: row.label) }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.brand)
            addToToday(row.item)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(row.item.id) }
        }
    }

    /// Puts an item on the Today tab too, for today.
    private func addToToday(_ item: Item) -> some View {
        let on = item.myDay == today
        return Button(on ? "Remove from Today" : "Add to Today", systemImage: on ? "sun.max.fill" : "sun.max") {
            withAnimation { store.change { s in if let i = s.index(of: item.id) { s.items[i].myDay = on ? nil : today } } }
        }
        .tint(.gray)
    }

    private func waitingRow(_ item: Item) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                let sub = Fmt.subline(item, today)
                if !sub.isEmpty { Text(sub).font(.subheadline).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { editing = item }
            letterMenu(item) {
                Text("Letter")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 30)
                    .background(Color.brand.opacity(0.12), in: Capsule())
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 16))
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(item.id) }
        }
    }

    /// Tapping a letter (or "Letter") lists the five with what each one means.
    private func letterMenu(_ item: Item, @ViewBuilder label: () -> some View) -> some View {
        Menu {
            LetterChoices(suggested: item.priority == nil ? suggestedLetter(item.type, weightPct: item.weightPct) : nil,
                          allowNone: item.priority != nil) { l in
                withAnimation(.snappy) { store.change { $0.setLetter(item.id, l, today: today) } }
            }
        } label: {
            label().frame(minWidth: 44, minHeight: 44, alignment: .trailing).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: item.priority)
        .accessibilityLabel(item.priority.map { "Letter \($0.rawValue), \($0.name). Change" } ?? "Give it a letter")
    }

    private var planningRows: some View {
        Group {
            Button { store.planningTomorrow = true } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plan tomorrow").foregroundStyle(Color.primary)
                        if store.evening {
                            Text("It's evening. Pick tomorrow's first thing now.").font(.subheadline).foregroundStyle(Color.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "moon").foregroundStyle(.secondary)
                }
            }
            Button { importing = true } label: {
                Label {
                    Text("Bring in a schedule").foregroundStyle(Color.primary)
                } icon: {
                    Image(systemName: "square.and.arrow.down").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// The line under a row: its detail, then small marks for steps, a reminder and Today.
    private func line(_ row: Row) -> Text? {
        Fmt.meta([Fmt.detail(row, today).map { Text($0).foregroundStyle(row.overdue ? Color.red : Color.secondary) }]
                 + Fmt.marks(row.item.steps, remind: row.item.remindAt, today: row.item.myDay == today))
    }

    private func complete(_ row: Row) {
        ticking.insert(row.key)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "Marked \u{201C}\(row.item.title)\u{201D} done") { $0.complete(row, today: today) }
                ticking.remove(row.key)
            }
        }
    }

    // Reordering only moves within a letter: A2 can become A1, not B1.
    private func move(from: IndexSet, to: Int) {
        let shown = rows
        guard let i = from.first else { return }
        let target = to > i ? to - 1 : to
        guard shown.indices.contains(target), shown[target].priority == shown[i].priority else { return }
        withAnimation {
            store.change { s in
                var current = dayRows(s.items, today)
                let key = shown[i].key
                for _ in 0..<abs(target - i) {
                    s.move(current, key: key, by: target > i ? 1 : -1)
                    current = dayRows(s.items, today)
                }
            }
        }
    }
}
