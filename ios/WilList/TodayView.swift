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

/// Today: the tasks added to Today on one card, then a plain checklist. Type a line, tick it off. Tap one for
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
    @State private var draft = ""
    @FocusState private var typing: Bool
    // Chosen under the line before it's added; nil until then, so the words decide the date and repeat.
    @State private var letter: Letter?
    @State private var remindAt: String?
    @State private var chosenDate: Day??
    @State private var chosenRecur: Recur??
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
    /// The tasks added to Today (Add to Today, or a line given a letter here), still to do today.
    /// Nothing comes from Plan by itself (the owner's call, 2026-10-25).
    private var planItems: [Item] {
        store.state.items.filter { $0.myDay == today && !$0.done && !$0.doneDates.contains(today) }
            .sorted { letterKey($0) < letterKey($1) }
    }

    var body: some View {
        let fromPlan = planItems
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
                // The tasks added to Today, in letter order.
                if !fromPlan.isEmpty {
                    Section {
                        ForEach(fromPlan) { planRow($0) }
                    }
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
                // While a line is being written, Add takes Search and Sort's place, as in New task.
                if adding {
                    ToolbarItem(placement: .confirmationAction) { Button("Add", action: add).disabled(blank) }
                } else if hasTools {
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

    /// Everything on Today still to do; the overdue to-dos; all finished today.
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

    /// Add a to-do, as in Microsoft To Do: tapping the line or its + starts one, the + turns into the
    /// to-do's empty circle, and Add at the top right adds it (return only puts the keyboard away).
    /// While it's being written, the letters and Remind me, the date and Repeat sit under it; a letter
    /// makes it a task in Plan, on Today for today.
    private var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                // The field itself is the control for VoiceOver.
                Button { typing = true } label: {
                    Image(systemName: adding ? "circle" : "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(adding ? Color(.tertiaryLabel) : Color.brand)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Add a to-do", text: $draft)
                        .focused($typing)
                        .submitLabel(.done)
                    // What the line will be saved as: its day, repeat and reminder.
                    if let reads { reads.font(.footnote).foregroundStyle(Color.brand) }
                }
            }
            if adding {
                VStack(alignment: .leading, spacing: 4) {
                    LetterChips(letter: letter) { letter = $0 }
                    HStack(spacing: 0) {
                        // Not "Remind me": that's the row in a to-do's details, which can be open over this.
                        ReminderMenu(at: $remindAt, today: today) { option(remindAt == nil ? "bell" : "bell.fill", on: remindAt != nil) }
                            .accessibilityLabel("Reminder")
                            .accessibilityValue(Fmt.reminder(remindAt, today) ?? "None")
                        DateMenu(date: date, today: today) { option("calendar", on: date.wrappedValue != nil) }
                            .accessibilityLabel("Date")
                            .accessibilityValue(Fmt.dueLine(date.wrappedValue, nil, today, word: false) ?? "None")
                        RepeatMenu(recur: recur, date: date, today: today) { option("repeat", on: recur.wrappedValue != nil) }
                            .accessibilityLabel("Repeat")
                            .accessibilityValue(recur.wrappedValue.map(Fmt.recur) ?? "None")
                    }
                    .padding(.leading, -10) // the icons line up with the words, their frames reaching past
                }
                .padding(.leading, 54)
                .padding(.bottom, 6)
            }
        }
        // The line under it starts at the words, like every row's below.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + 54 }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 20))
    }

    private func option(_ symbol: String, on: Bool) -> some View {
        Image(systemName: symbol)
            .font(.body)
            .foregroundStyle(on ? Color.brand : Color.secondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private var blank: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// A to-do is being written: the line has the keyboard, words, or something chosen under it.
    private var adding: Bool { typing || !blank || letter != nil || remindAt != nil || chosenDate != nil || chosenRecur != nil }
    private var parsed: Parsed? {
        readDates && !blank ? quickAdd(draft, today: today, minute: nowMinutes(), dateOrder: store.dateOrder) : nil
    }
    private var date: Binding<Day?> {
        Binding(get: { chosenDate ?? parsed.flatMap { $0.date ?? ($0.recur != nil ? today : nil) } }, set: { chosenDate = .some($0) })
    }
    private var recur: Binding<Recur?> { Binding(get: { chosenRecur ?? parsed?.recur }, set: { chosenRecur = .some($0) }) }

    /// "Due Fri, 17:00, Every week, 🔔 Tomorrow, 9:00 AM": what the line will be saved as.
    private var reads: Text? {
        let d = date.wrappedValue
        let parts = [Fmt.dueLine(d, d == nil ? nil : parsed?.time, today), recur.wrappedValue.map(Fmt.recur)].compactMap { $0 }
        let words = parts.isEmpty ? nil : Text(parts.joined(separator: ", "))
        let bell = Fmt.reminder(remindAt, today).map { Text(Image(systemName: "bell")) + Text(" \($0)") }
        switch (words, bell) {
        case let (w?, b?): return w + Text(", ") + b
        case let (w, b): return w ?? b
        }
    }

    private func add() {
        guard !blank else { typing = false; return }
        let text = draft, letter = letter, remindAt = remindAt, recur = recur.wrappedValue, wasTyping = typing
        let date = date.wrappedValue, time = date == nil ? nil : parsed?.time
        withAnimation(.snappy) {
            store.change { s in
                guard let t = s.addTodo(text, today: today, minute: nowMinutes(), dateOrder: store.dateOrder,
                                        onTop: newOnTop, readDates: readDates),
                      let i = s.todos.firstIndex(where: { $0.id == t.id }) else { return }
                s.todos[i].date = date
                s.todos[i].time = time
                s.todos[i].recur = recur
                s.todos[i].remindAt = remindAt
                if let letter { s.letterTodo(t.id, letter, today: today) }
            }
        }
        draft = ""
        self.letter = nil
        self.remindAt = nil
        chosenDate = nil
        chosenRecur = nil
        typing = wasTyping // a keyboard that was up stays up for the next one
    }

    // MARK: rows

    private func rows(_ list: [Todo], movable: Bool) -> some View {
        let reorder: ((IndexSet, Int) -> Void)? = movable ? { (from: IndexSet, to: Int) in move(from, to) } : nil
        return ForEach(list) { todo in
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

    /// A task added to Today: tick it off here, Play it, or take it off Today.
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
                    PlayButton { m in
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
