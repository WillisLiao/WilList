import SwiftUI
import WilListCore

/// How Today's open to-dos are ordered.
enum TodoSort: String, CaseIterable, Identifiable {
    case manual, importance, due, alphabetical, created
    var id: Self { self }

    var name: String {
        switch self {
        case .manual: "My order"
        case .importance: "Importance"
        case .due: "Due date"
        case .alphabetical: "Alphabetically"
        case .created: "Creation date"
        }
    }
}

/// Today: the day's A1 on one card, then a plain checklist. Type a line, tick it off. Tap one for
/// steps, a reminder, a due date and time, a repeat and a note. Every task has Play, for a focus
/// session of the length you choose.
struct TodayView: View {
    @Environment(Store.self) private var store
    @AppStorage("todoSort") private var sort = TodoSort.manual
    @AppStorage("showCompleted") private var showCompleted = true
    @AppStorage("completedOpen") private var completedOpen = true
    @AppStorage("newOnTop") private var newOnTop = false
    @AppStorage("starredOnTop") private var starredOnTop = true
    @AppStorage("confirmDelete") private var confirmDelete = false
    @AppStorage("readDates") private var readDates = true
    @AppStorage("plannedFor") private var plannedFor = ""
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var ticking: Set<String> = []
    @State private var editing: String?
    @State private var searching = false
    @State private var deleting: Todo?
    @State private var editingItem: Item?
    @State private var sorting: LetterSorter.Batch?

    private var today: Day { store.today }
    private var open: [Todo] { ordered(store.state.todos.filter { !$0.done }) }
    private var completed: [Todo] {
        store.state.todos.filter(\.done).sorted { ($0.doneAt ?? "") > ($1.doneAt ?? "") }
    }
    /// The day's A1, first on Today, then the items from Plan added to Today, still to
    /// do today.
    private var planItems: [Item] {
        let a1 = doRows(store.state.items, today).first?.item
        let added = store.state.items.filter { $0.myDay == today && !$0.done && !$0.doneDates.contains(today) && $0.id != a1?.id }
            .sorted { letterKey($0) < letterKey($1) }
        return (a1.map { [$0] } ?? []) + added
    }

    var body: some View {
        let fromPlan = planItems
        let planned = plannedFor == addDays(today, 1)
        // A new list has nothing to search or sort yet.
        let hasTools = !(store.state.todos.isEmpty && store.state.items.isEmpty)
        NavigationStack {
            List {
                // The date sits straight on the ground; everything under it is on cards.
                header(fromPlan: fromPlan)
                    .padding(.bottom, 16)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                // The day's A1 leads, with what was added from Plan under it.
                if !fromPlan.isEmpty {
                    Section {
                        ForEach(fromPlan) { planRow($0) }
                    }
                }
                // In the evening, until tomorrow is planned.
                if store.evening && !planned {
                    Section { nudge("Plan tomorrow", systemImage: "moon.fill", tint: PlanTomorrow.night) { store.planningTomorrow = true } }
                }
                // The checklist on one card, Add a to-do at its top, as on the Today widget.
                Section {
                    addRow
                    if sort != .due { rows(open, movable: sort == .manual) }
                }
                if sort == .due {
                    ForEach(dueGroups, id: \.name) { group in
                        Section { rows(group.todos, movable: false) } header: { Text(group.name).onGround() }
                    }
                }
                if showCompleted && !completed.isEmpty {
                    Section {
                        if completedOpen { rows(completed, movable: false) }
                    } header: {
                        Button { withAnimation(.snappy) { completedOpen.toggle() } } label: {
                            HStack(spacing: 6) {
                                Text("Completed")
                                Text("\(completed.count)")
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .rotationEffect(.degrees(completedOpen ? 90 : 0))
                            }
                            .onGround()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .ground()
            // The profile picture, Search and Sort in the bar, as on every tab; the date is the
            // screen's title, set large in the list so a long one wraps.
            .readableColumn(inline: true)
            // The date where the other tabs have their large title.
            .contentMargins(.top, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .profileButton()
            .toolbar {
                if hasTools {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Search", systemImage: "magnifyingglass") { searching = true }
                    }
                    ToolbarItem(placement: .primaryAction) { sortMenu }
                }
            }
            .sheet(item: Binding(get: { editing.map(Opened.init) }, set: { editing = $0?.id })) { TodoEditor(id: $0.id) }
            .sheet(isPresented: $searching) { SearchView() }
            .sheet(item: $editingItem) { ItemEditor(item: $0) }
            .sheet(item: $sorting) { LetterSorter(ids: $0.ids) }
            .confirmationDialog("Delete \u{201C}\(deleting?.title ?? "")\u{201D}?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleting.map(delete) }
            }
            #if DEBUG
            // `-edit <id>` or `-sheet search|letters` on launch, for screenshots.
            .onAppear {
                editing = UserDefaults.standard.string(forKey: "edit")
                searching = UserDefaults.standard.string(forKey: "sheet") == "search"
                if UserDefaults.standard.string(forKey: "sheet") == "letters" {
                    sorting = LetterSorter.Batch(ids: unsorted(store.state.items, today).map(\.id))
                }
            }
            #endif
            // Home-screen quick actions: New to-do and Search.
            .onChange(of: store.quickAction, initial: true) {
                switch store.quickAction {
                case .add: typing = true
                case .search: searching = true
                case nil: return
                }
                store.quickAction = nil
            }
            .onChange(of: store.opening, initial: true) {
                if let id = store.opening, store.state.todos.contains(where: { $0.id == id }) {
                    store.opening = nil
                    editing = id
                }
            }
            .toastHost()
        }
    }

    // MARK: header

    /// The date and how the day stands.
    private func header(fromPlan: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.long(today))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(summary(open.count + fromPlan.count))
                .font(.subheadline)
        }
        .onGround()
    }

    /// A one-line nudge under the A1 card: Plan tomorrow, in the evening.
    private func nudge(_ title: String, systemImage: String? = nil, tint: Color = .brand, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.footnote) }
                Text(title)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .multilineTextAlignment(.leading)
            // The whole row answers a tap, not just the words.
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sort) {
                ForEach(TodoSort.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.inline)
            Toggle("Show completed", isOn: $showCompleted)
        } label: {
            Label("Sort and view", systemImage: "arrow.up.arrow.down")
        }
    }

    /// Everything on Today still to do, A1 included; the overdue to-dos; all finished today.
    private func summary(_ toDo: Int) -> String {
        let overdue = open.filter { $0.date.map { diffDays(today, $0) < 0 } ?? false }.count
        let doneToday = completed.filter { $0.doneAt == today }.count + doneOn(store.state.items, today).count
        // An empty day says so plainly.
        var parts = [toDo == 0 ? (doneToday == 0 ? "Nothing yet" : "All clear") : "\(toDo) to do"]
        if overdue > 0 { parts.append("\(overdue) overdue") }
        if doneToday > 0 { parts.append("\(doneToday) done") }
        return parts.joined(separator: ", ")
    }

    // MARK: adding

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.brand)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Add a to-do", text: $draft)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(add)
                // What the line will be saved as, when it names a day or a repeat.
                if let reads = reads {
                    Text(reads).font(.footnote).foregroundStyle(Color.brand)
                }
            }
            // The line under it starts at the words, like every row's below.
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 20))
    }

    private var reads: String? {
        let t = draft.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        guard readDates else { return nil }
        let p = quickAdd(t, today: today, minute: nowMinutes(), dateOrder: store.dateOrder)
        let parts = [Fmt.dueLine(p.date ?? (p.recur != nil ? today : nil), p.date == nil ? nil : p.time, today), p.recur.map(Fmt.recur)]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private func add() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { typing = false; return }
        let text = draft
        withAnimation(.snappy) {
            store.change { _ = $0.addTodo(text, today: today, minute: nowMinutes(), dateOrder: store.dateOrder,
                                          onTop: newOnTop, readDates: readDates) }
        }
        draft = ""
        typing = true // keep the keyboard up for the next one
    }

    // MARK: rows

    private func rows(_ list: [Todo], movable: Bool) -> some View {
        let reorder: ((IndexSet, Int) -> Void)? = movable ? { (from: IndexSet, to: Int) in move(from, to) } : nil
        return 
ForEach(list) { todo in
            row(todo)
                .swipeActions(edge: .leading) {
                    if !todo.done {
                        Button("Done", systemImage: "checkmark") { tick(todo) }.tint(.brand)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: confirmDelete ? nil : .destructive) {
                        if confirmDelete { deleting = todo } else { delete(todo) }
                    }
                    .tint(.red)
                }
        }
        .onMove(perform: reorder)
    }

    private func row(_ todo: Todo) -> some View {
        let checked = todo.done || ticking.contains(todo.id)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { todo.done ? untick(todo) : tick(todo) }
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(todo.done ? .secondary : .primary)
                if let meta = meta(todo) { meta.font(.footnote) }
            }
            .rowWords { editing = todo.id }
            RowEnd {
                if !todo.done { PlayButton { store.startFocus(todo, minutes: $0) } }
                StarButton(on: Binding(get: { todo.starred }, set: { v in
                    withAnimation(.snappy) { store.change { s in
                        if let i = s.todos.firstIndex(where: { $0.id == todo.id }) { s.todos[i].starred = v }
                    } }
                }))
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
    }

    /// The A1, or an item added to Today from Plan: tick it off here, Play it, or take it off Today.
    private func planRow(_ item: Item) -> some View {
        let checked = ticking.contains(item.id)
        let row = dayRows(store.state.items, today, realToday: today).first { $0.item.id == item.id }
        return HStack(spacing: 10) {
            CheckButton(done: checked) { finish(item) }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).strikethrough(checked, color: .secondary)
                if let line = Fmt.meta([Fmt.subline(item, today, in: store.state)?.foregroundStyle(Color.secondary)]
                                       + Fmt.marks(item.steps, remind: item.remindAt, today: false)) {
                    line.font(.footnote)
                }
            }
            .rowWords { editingItem = item }
            RowEnd {
                // A focus session on it, with the timer on the Lock Screen too; nothing to focus on
                // in something dropped.
                if item.priority != .E {
                    PlayButton(planned: row?.session?.minutes) { m in
                        if let row { store.startFocus(row, minutes: m) } else { store.startFocus(item, minutes: m) }
                    }
                }
                MarkColumn { if item.priority != nil { LetterMark(letter: item.priority, label: row?.label) } }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { finish(item) }.tint(.brand)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove from Today", systemImage: "sun.max") {
                withAnimation { store.change { s in if let i = s.index(of: item.id) { s.items[i].myDay = nil } } }
            }
            .tint(.gray)
        }
    }

    /// Ticks off today's part of an item: its session or its occurrence if it has one today.
    private func finish(_ item: Item) {
        ticking.insert(item.id)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "\u{201C}\(item.title)\u{201D} done") { s in
                    if let row = dayRows(s.items, today, realToday: today).first(where: { $0.item.id == item.id }) {
                        s.complete(row, today: today)
                    } else {
                        s.complete(itemId: item.id, today: today)
                    }
                }
                ticking.remove(item.id)
            }
        }
    }

    /// The small line under a to-do: steps, due, reminder, repeat and note, only what it has.
    private func meta(_ t: Todo) -> Text? {
        var parts: [Text] = []
        if !t.steps.isEmpty {
            parts.append(Text("\(t.steps.filter(\.done).count)\u{00A0}of\u{00A0}\(t.steps.count)").foregroundStyle(Color.secondary))
        }
        // Red says it's overdue, as the calendar icon says it's due.
        if let due = Fmt.dueLine(t.date, t.time, today, word: false) {
            let late = !t.done && diffDays(today, t.date ?? today) < 0
            parts.append(Text("\(Image(systemName: "calendar")) \(due)").foregroundStyle(late ? Color.red : t.date == today && !t.done ? Color.brand : Color.secondary))
        }
        // With a due date shown, the bell alone says there's a reminder; without one, it says when.
        if !t.done, let r = Fmt.reminder(t.remindAt, today) {
            parts.append(Text(t.date == nil ? "\(Image(systemName: "bell")) \(r)" : "\(Image(systemName: "bell"))").foregroundStyle(Color.secondary))
        }
        if t.recur != nil { parts.append(Text(Image(systemName: "repeat")).foregroundStyle(Color.secondary)) }
        if !t.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(Text(Image(systemName: "note.text")).foregroundStyle(Color.secondary))
        }
        return Fmt.meta(parts)
    }

    // MARK: order

    private func ordered(_ list: [Todo]) -> [Todo] {
        let indexed = Array(list.enumerated())
        func by(_ before: (Todo, Todo) -> Bool) -> [Todo] {
            indexed.sorted { a, b in before(a.element, b.element) || (!before(b.element, a.element) && a.offset < b.offset) }.map(\.element)
        }
        var out: [Todo] = switch sort {
        case .manual, .importance: list
        case .due: by { ($0.date ?? "9999", $0.time ?? "99:99") < ($1.date ?? "9999", $1.time ?? "99:99") }
        case .alphabetical: by { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .created: by { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        }
        if sort == .importance || (starredOnTop && sort != .due) {
            out = out.filter(\.starred) + out.filter { !$0.starred }
        }
        return out
    }

    private struct DueGroup { let name: String; let todos: [Todo] }

    /// Sorted by due date, the list falls into Overdue, Today, Tomorrow, This week, Later and No due date.
    private var dueGroups: [DueGroup] {
        let names = ["Overdue", "Today", "Tomorrow", "This week", "Later", "No due date"]
        func name(_ t: Todo) -> String {
            guard let d = t.date else { return names[5] }
            let n = diffDays(today, d)
            return n < 0 ? names[0] : n == 0 ? names[1] : n == 1 ? names[2] : n < 7 ? names[3] : names[4]
        }
        let all = open
        return names.map { n in DueGroup(name: n, todos: all.filter { name($0) == n }) }.filter { !$0.todos.isEmpty }
    }

    // MARK: actions

    // The circle fills first, then the row glides down to Completed.
    private func tick(_ todo: Todo) {
        ticking.insert(todo.id)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change { $0.toggleTodo(todo.id, today: today) }
                ticking.remove(todo.id)
            }
        }
    }

    private func move(_ from: IndexSet, _ to: Int) {
        var list = open
        list.move(fromOffsets: from, toOffset: to)
        store.change { s in s.todos = list + s.todos.filter(\.done) }
    }

    private func untick(_ todo: Todo) {
        withAnimation(.snappy) { store.change { $0.toggleTodo(todo.id, today: today) } }
    }

    private func delete(_ todo: Todo) {
        withAnimation { store.change(undo: "Deleted \u{201C}\(todo.title)\u{201D}") { $0.removeTodo(todo.id) } }
    }
}

/// A sheet's subject by id.
struct Opened: Identifiable { let id: String }
