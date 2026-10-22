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
/// steps, a reminder, a due date and time, a repeat and a note.
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
    /// The day's first thing, on its card at the top.
    private var first: Row? { doRows(store.state.items, today).first }
    /// Items from Plan and Study added to Today, still to do today. The A1 has its card.
    private func planItems(besides a1: Row?) -> [Item] {
        store.state.items.filter { $0.myDay == today && !$0.done && !$0.doneDates.contains(today) && $0.id != a1?.item.id }
            .sorted { letterKey($0) < letterKey($1) }
    }
    /// Items still waiting for a letter.
    private var waiting: Int { unsorted(store.state.items, today).count }

    var body: some View {
        let first = self.first, fromPlan = planItems(besides: first)
        // The A1 as the poster of the day: the header and the A1 share one field, in the colour of
        // its course.
        let poster = first != nil && Look.current.hero == .poster
        let field = CourseColor.of(store.state.courseColor(first?.item.course))
        NavigationStack {
            List {
                // The field is painted in the rows, not as their list backgrounds, which the list
                // doesn't repaint when the next A comes from another course.
                header(first: first, fromPlan: fromPlan, poster: poster)
                    .padding(EdgeInsets(top: 12, leading: 20, bottom: poster ? 0 : 16, trailing: 12))
                    // The field reaches up under the status bar, and shows when the list is pulled down.
                    .background { if poster { field.padding(.top, -1000) } }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                if let first {
                    A1Card(row: first) { editingItem = $0 }
                        .environment(\.field, field)
                        .padding(poster ? EdgeInsets() : EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                        .background { if poster { field } }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                // In the evening, until tomorrow is planned, planning comes first: it letters too.
                if store.evening && plannedFor != addDays(today, 1) {
                    nudge("Plan tomorrow", systemImage: "moon.fill") { store.planningTomorrow = true }
                } else if waiting > 0 {
                    nudge("\(waiting) waiting for a letter", action: letterThem)
                }
                Section {
                    addRow
                    // A list with no to-dos yet shows what a line can say.
                    if store.state.todos.isEmpty && readDates && draft.isEmpty {
                        Text("Dates are read for you: \u{201C}Call mum tomorrow 6pm\u{201D}.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 66, bottom: 4, trailing: 20))
                    }
                }
                if sort == .due {
                    ForEach(dueGroups, id: \.name) { group in
                        Section(group.name) { rows(group.todos, movable: false) }
                    }
                } else {
                    Section { rows(open, movable: sort == .manual) }
                }
                if !fromPlan.isEmpty {
                    Section("From Plan and Study") {
                        ForEach(fromPlan) { planRow($0) }
                    }
                }
                if showCompleted && !completed.isEmpty {
                    Section {
                        if completedOpen { rows(completed, movable: false) }
                    } header: {
                        Button { withAnimation(.snappy) { completedOpen.toggle() } } label: {
                            HStack(spacing: 6) {
                                Text("Completed")
                                Text("\(completed.count)").foregroundStyle(Color.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .rotationEffect(.degrees(completedOpen ? 90 : 0))
                            }
                            .foregroundStyle(Color.primary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .listStyle(.plain)
            .readableColumn()
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
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
                if UserDefaults.standard.string(forKey: "sheet") == "letters" { letterThem() }
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

    /// The date, how the day stands, Search and Sort. Above the poster it steps back to the date
    /// alone, small and white on the green, so the A1's title is the largest thing on the screen
    /// (the list below already shows what's left and what's overdue).
    @ViewBuilder
    private func header(first: Row?, fromPlan: [Item], poster: Bool) -> some View {
        // A new list has nothing to search or sort yet.
        let hasTools = !(store.state.todos.isEmpty && store.state.items.isEmpty)
        if poster {
            HStack(spacing: 0) {
                Text(Fmt.long(today))
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if hasTools { tools.tint(.white) }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.long(today))
                    .font(.largeTitle.bold())
                    .fontDesign(Look.current.titles)
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 0) {
                    Text(summary(open.count + fromPlan.count + (first == nil ? 0 : 1)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if hasTools { tools }
                }
            }
        }
    }

    /// A one-line nudge under the A1 card: what's waiting for a letter, or planning tomorrow.
    private func nudge(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.footnote) }
                Text(title)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.brand)
            .multilineTextAlignment(.leading)
            // The whole row answers a tap, not just the words.
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
    }

    private var tools: some View {
        HStack(spacing: 0) {
            Button { searching = true } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(TodoSort.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.inline)
                Toggle("Show completed", isOn: $showCompleted)
            } label: {
                Label("Sort and view", systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
            }
        }
        .font(.body.weight(.medium))
        // Bar buttons stop growing at the largest text sizes, as the system's do.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// Everything on Today still to do, A1 included; the overdue to-dos; all finished today.
    private func summary(_ toDo: Int) -> String {
        let overdue = open.filter { $0.date.map { diffDays(today, $0) < 0 } ?? false }.count
        let doneToday = completed.filter { $0.doneAt == today }.count + doneOn(store.state.items, today).count
        var parts = [toDo == 0 ? (doneToday == 0 ? "Add what you need to do, one line each" : "All clear") : "\(toDo) to do"]
        if overdue > 0 { parts.append("\(overdue) overdue") }
        if doneToday > 0 { parts.append("\(doneToday) done today") }
        return parts.joined(separator: ", ") + "."
    }

    private func letterThem() {
        sorting = LetterSorter.Batch(ids: unsorted(store.state.items, today).map(\.id))
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
                if let meta = meta(todo) { meta.font(.subheadline) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { editing = todo.id }
            StarButton(on: Binding(get: { todo.starred }, set: { v in
                withAnimation(.snappy) { store.change { s in
                    if let i = s.todos.firstIndex(where: { $0.id == todo.id }) { s.todos[i].starred = v }
                } }
            }))
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
    }

    /// An item added to Today from Plan or Study: tick it off here, or take it off Today.
    private func planRow(_ item: Item) -> some View {
        let checked = ticking.contains(item.id)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { finish(item) }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).strikethrough(checked, color: .secondary)
                if let line = Fmt.meta([Fmt.subline(item, today, in: store.state)?.foregroundStyle(Color.secondary)]
                                       + Fmt.marks(item.steps, remind: item.remindAt, today: false)) {
                    line.font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture { editingItem = item }
            if item.priority != nil {
                LetterMark(letter: item.priority, label: dayRows(store.state.items, today, realToday: today).first { $0.item.id == item.id }?.label)
                    .padding(.trailing, 8)
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
                store.change(undo: "Marked \u{201C}\(item.title)\u{201D} done") { s in
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
            parts.append(Text("\(t.steps.filter(\.done).count) of \(t.steps.count)").foregroundStyle(Color.secondary))
        }
        if let due = Fmt.dueLine(t.date, t.time, today) {
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
