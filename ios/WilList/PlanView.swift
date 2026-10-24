import SwiftUI
import WilListCore

/// Plan: today in ABCDE order (the A1 first, the same A1 that leads Today), what comes later,
/// and a month showing what's planned on each day.
struct PlanView: View {
    var body: some View {
        NavigationStack { PlanList() }
    }
}

struct PlanList: View {
    @Environment(Store.self) private var store
    /// The day tapped on the calendar, listed in full under it.
    @State private var picked: Day?
    /// Which New sheet is open: a task, or a study block.
    @State private var adding: ItemType?
    @State private var editing: Item?
    @State private var ticking: Set<String> = []
    @State private var searching = false

    private var today: Day { store.today }
    private var rows: [Row] { dayRows(store.state.items, today) }
    private var later: [Item] { laterItems(store.state.items, today) }
    /// What's planned on each day: the open items due or set for it, by letter.
    private var byDay: [Day: [Item]] {
        Dictionary(grouping: store.state.items.filter { $0.recur == nil && $0.date != nil && isOpen($0, today) }) { $0.date! }
            .mapValues { $0.sorted { letterKey($0) < letterKey($1) } }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                dayHeader
                Section {
                    if rows.isEmpty {
                        Text("Nothing planned").foregroundStyle(.secondary).frame(minHeight: 44)
                    }
                    ForEach(rows) { itemRow($0) }
                        .onMove(perform: move)
                }
                // The rest of the plan: everything that isn't on today's list yet.
                if !later.isEmpty {
                    Section {
                        ForEach(later) { plainRow($0) }
                    } header: {
                        Text("Later").onGround()
                    }
                    .id("later")
                }
                let byDay = byDay
                Section {
                    MonthCalendar(selection: $picked, today: today) { d in
                        (byDay[d] ?? []).map { MonthCalendar.Mark(title: $0.title, fill: $0.priority?.color ?? Color(.systemGray5), ink: $0.priority?.ink ?? .primary) }
                    }
                    ForEach(picked.flatMap { byDay[$0] } ?? []) { plainRow($0) }
                }
                .id("calendar")
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .ground()
            .readableColumn()
            #if DEBUG
            // `-scroll later|calendar` or `-sheet add|study` on launch, for screenshots.
            .onAppear {
                UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) }
                switch UserDefaults.standard.string(forKey: "sheet") {
                case "add": adding = .task
                case "study": adding = .study
                default: break
                }
            }
            #endif
        }
        .navigationTitle("Plan")
        .profileButton()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Search", systemImage: "magnifyingglass") { searching = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Task", systemImage: "checklist") { adding = .task }
                    Button("Study block", systemImage: "book") { adding = .study }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuOrder(.fixed)
            }
        }
        .sheet(isPresented: $searching) { SearchView() }
        .sheet(item: $adding) { AddItemSheet(study: $0 == .study) }
        .onChange(of: store.opening, initial: true) {
            if let id = store.opening, let it = store.state.items.first(where: { $0.id == id }) {
                store.opening = nil
                editing = it
            }
        }
        .sheet(item: $editing) { ItemEditor(item: $0) }
        .toastHost()
    }

    // MARK: rows

    /// Today's date, straight on the ground under the tab's title.
    private var dayHeader: some View {
        Text(Fmt.long(today))
            .font(.title3.weight(.semibold))
            .onGround()
            .accessibilityAddTraits(.isHeader)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
    }

    private func itemRow(_ row: Row) -> some View {
        let done = ticking.contains(row.key)
        return HStack(spacing: 10) {
            CheckButton(done: done) { complete(row) }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.item.title)
                    .strikethrough(row.priority == .E || done, color: .secondary)
                    .foregroundStyle(row.priority == .E ? .secondary : .primary)
                if let line = line(row) { line.font(.footnote) }
            }
            .rowWords { editing = row.item }
            RowEnd {
                if row.priority != .E { PlayButton { store.startFocus(row, minutes: $0) } }
                letterMenu(row.item) { LetterMark(letter: row.priority, label: row.label) }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
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

    /// An item off today's list: its check, title, when, and its letter (without a number, which
    /// only the day's list has); nothing there without one.
    private func plainRow(_ item: Item) -> some View {
        let done = ticking.contains(item.id)
        return HStack(spacing: 10) {
            CheckButton(done: done) { finishLater(item) }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.priority == .E || done, color: .secondary)
                    .foregroundStyle(item.priority == .E ? .secondary : .primary)
                if let sub = Fmt.subline(item, today, in: store.state) { sub.font(.footnote).foregroundStyle(.secondary) }
            }
            .rowWords { editing = item }
            RowEnd {
                if item.priority != .E {
                    PlayButton(planned: item.type == .study ? item.durationMin : nil) {
                        store.startFocus(item, minutes: $0)
                    }
                }
                // In the same column as the letters above.
                if item.priority != nil { letterMenu(item) { LetterMark(letter: item.priority) } } else { MarkColumn {} }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(item.id) }
        }
    }

    /// Tapping a letter lists the five with what each one means, and None.
    private func letterMenu(_ item: Item, @ViewBuilder label: () -> some View) -> some View {
        Menu {
            LetterChoices(allowNone: true) { l in
                withAnimation(.snappy) { store.change { $0.setLetter(item.id, l) } }
            }
        } label: {
            label().frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: item.priority)
        .accessibilityLabel(item.priority.map { "Letter \($0.rawValue), \($0.name). Change" } ?? "Give it a letter")
    }

    /// The line under a row: its detail, then small marks for steps, a reminder and Today.
    private func line(_ row: Row) -> Text? {
        Fmt.meta([Fmt.detail(row, today, in: store.state)?.foregroundStyle(row.overdue ? Color.red : Color.secondary)]
                 + Fmt.marks(row.item.steps, remind: row.item.remindAt, today: row.item.myDay == today))
    }

    private func complete(_ row: Row) {
        ticking.insert(row.key)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "\u{201C}\(row.item.title)\u{201D} done") { $0.complete(row, today: today) }
                ticking.remove(row.key)
            }
        }
    }

    /// Ticks off something off today's list, as `complete` does a day's row.
    private func finishLater(_ item: Item) {
        ticking.insert(item.id)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "\u{201C}\(item.title)\u{201D} done") { $0.completeLater(item.id, today: today) }
                ticking.remove(item.id)
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
