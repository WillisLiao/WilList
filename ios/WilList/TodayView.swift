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

/// Today: the day in time order (classes and study blocks at their times, the lettered work fitted
/// into the free time between them, A's first, and to-dos due at a time), then a plain checklist,
/// then what's coming up. Every task has Play, for a focus session of the length you choose.
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
    /// The minute it is now, which places the line for now and the work after it.
    @State private var minute = nowMinutes()

    private var today: Day { store.today }
    /// The to-dos for the checklist: no date, overdue, or due today at no set time.
    private var open: [Todo] {
        ordered(store.state.todos.filter { t in !t.done && t.date.map { diffDays(today, $0) < 0 || ($0 == today && t.time == nil) } ?? true })
    }
    private var completed: [Todo] {
        store.state.todos.filter(\.done).sorted { ($0.doneAt ?? "") > ($1.doneAt ?? "") }
    }
    /// The day's work, A to C, and anything else added to Today from Plan.
    private var rows: [Row] {
        let listed = Set(dayRows(store.state.items, today).map(\.item.id))
        let added = store.state.items
            .filter { $0.myDay == today && !listed.contains($0.id) && !$0.type.isBlock && isOpen($0, today) && !$0.doneDates.contains(today) }
            .sorted { letterKey($0) < letterKey($1) }
            .map { it in
                var r = Row(item: it)
                r.label = it.priority?.rawValue ?? ""
                return r
            }
        return doRows(store.state.items, today) + added
    }
    /// The day in time order, from now on.
    private var column: [DayEntry] {
        let events = scheduleOn(store.state.items, today).filter { !$0.done && !$0.doneDates.contains(today) }
        let timed = store.state.todos.filter { !$0.done && $0.date == today && $0.time != nil }
        return dayColumn(events: events, rows: rows, todos: timed, settings: store.state.settings, nowMin: minute)
    }
    /// The next week's deadlines, exams and dated tasks not already on today's column, and every
    /// to-do due after today, soonest first.
    private func coming(besides column: [DayEntry]) -> [Upcoming] {
        let shown = Set(column.compactMap { e -> String? in
            if case .work(let r) = e.kind { return r.item.id }
            if case .over(let r) = e.kind { return r.item.id }
            return nil
        })
        let items = store.state.items.filter { it in
            guard !it.type.isBlock, it.recur == nil, it.priority != .E, isOpen(it, today), !shown.contains(it.id), let d = it.date else { return false }
            return (1...7).contains(diffDays(today, d))
        }
        .map { Upcoming(id: $0.id, date: $0.date!, time: $0.time, item: $0) }
        let todos = store.state.todos.filter { t in !t.done && t.date.map { diffDays(today, $0) > 0 } ?? false }
            .map { Upcoming(id: $0.id, date: $0.date!, time: $0.time, todo: $0) }
        return (items + todos).sorted { ($0.date, $0.time ?? "99:99") < ($1.date, $1.time ?? "99:99") }
    }

    var body: some View {
        let column = column
        let coming = coming(besides: column)
        // Only the line for now and the end of the day: nothing to show.
        let hasDay = column.contains { e in
            switch e.kind { case .now, .free, .endOfDay: false; default: true }
        }
        let planned = plannedFor == addDays(today, 1)
        // A new list has nothing to search or sort yet.
        let hasTools = !(store.state.todos.isEmpty && store.state.items.isEmpty)
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                // The date sits straight on the ground; everything under it is on cards.
                header(toDo: column.filter(\.isTask).count + open.count)
                    .padding(.bottom, 16)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                if hasDay {
                    Section { ForEach(column) { entry($0) } }
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
                if !coming.isEmpty {
                    Section {
                        ForEach(coming) { u in
                            if let t = u.todo { row(t) } else if let it = u.item { itemRow(it) }
                        }
                    } header: {
                        Text("Coming up").onGround()
                    }
                    .id("coming")
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
            #if DEBUG
            // `-scroll coming` on launch, for screenshots.
            .onAppear { UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) } }
            #endif
            }
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
            .onAppear { minute = nowMinutes() }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
                if nowMinutes() != minute { minute = nowMinutes() }
            }
        }
    }

    // MARK: header

    /// The date and how the day stands.
    private func header(toDo: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.long(today))
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(summary(toDo))
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

    /// A to-do; on the day's column (`at` its time), the time stands for its due date.
    private func row(_ todo: Todo, at: Int? = nil) -> some View {
        let checked = todo.done || ticking.contains(todo.id)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { todo.done ? untick(todo) : tick(todo) }
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .strikethrough(checked, color: .secondary)
                    .foregroundStyle(todo.done ? .secondary : .primary)
                if let meta = meta(todo, at: at) { meta.font(.subheadline) }
            }
            .rowWords { editing = todo.id }
            if !todo.done { PlayButton { store.startFocus(todo, minutes: $0) } }
            StarButton(on: Binding(get: { todo.starred }, set: { v in
                withAnimation(.snappy) { store.change { s in
                    if let i = s.todos.firstIndex(where: { $0.id == todo.id }) { s.todos[i].starred = v }
                } }
            }))
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
    }

    // MARK: the day

    @ViewBuilder private func entry(_ e: DayEntry) -> some View {
        switch e.kind {
        case .now: nowLine(e.start ?? minute)
        case .free: note("\(Fmt.minutes(e.minutes)) free")
        case .endOfDay: note("End of day, \(Fmt.span(e.start ?? 0, 0))")
        case .allDay(let it): blockRow(it, when: "All day", minutes: nil)
        case .block(let it): blockRow(it, when: Fmt.span(e.start ?? 0, e.minutes), minutes: e.minutes)
        case .work(let r):
            workRow(r, when: Text(Fmt.span(e.start ?? 0, e.minutes) + (e.part.map { ", part \($0)" } ?? "")).foregroundStyle(Color.secondary),
                    planned: r.session.map { _ in e.minutes })
        case .over(let r): workRow(r, when: Text("Won\u{2019}t fit today").foregroundStyle(Color.red), planned: r.session?.minutes)
        case .todo(let t): row(t, at: e.start)
        }
    }

    /// The line for now: a teal rule across the card, the time at its start.
    private func nowLine(_ at: Int) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color.brand).frame(width: 9, height: 9).frame(width: 44)
            Text("Now, \(Fmt.span(at, 0))")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandDeep)
                .fixedSize()
            Rectangle().fill(Color.brand).frame(height: 1.5)
        }
        .frame(minHeight: 32)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now, \(Fmt.span(at, 0))")
    }

    /// Free time and the end of the day: a quiet line in the words' column.
    private func note(_ words: String) -> some View {
        Text(words)
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 0, leading: 66, bottom: 0, trailing: 16))
    }

    /// Work from the plan at its time: tick it off, Play (a study session's time planned), its letter.
    private func workRow(_ r: Row, when: Text, planned: Int?) -> some View {
        let checked = ticking.contains(r.key)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { finish(r) }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.item.title).strikethrough(checked, color: .secondary)
                if let line = Fmt.meta([when, Fmt.detail(r, today, in: store.state, timed: true)?.foregroundStyle(r.overdue ? Color.red : Color.secondary)]
                                       + Fmt.marks(r.item.steps, remind: r.item.remindAt, today: false)) {
                    line.font(.subheadline)
                }
            }
            .rowWords { editingItem = r.item }
            PlayButton(planned: planned) { store.startFocus(r, minutes: $0) }
            MarkColumn { if r.priority != nil { LetterMark(letter: r.priority, label: r.label.isEmpty ? nil : r.label) } }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { finish(r) }.tint(.brand)
        }
        .swipeActions(edge: .trailing) {
            if r.item.myDay == today { removeFromToday(r.item) }
        }
    }

    /// A class, exam or study block at its time, a bar of its course's colour beside it. A study
    /// block is something to do, so it has a check and Play.
    private func blockRow(_ it: Item, when: String, minutes: Int?) -> some View {
        let study = it.type == .study, checked = ticking.contains(it.id)
        let colour = CourseColor.of(store.state.courseColor(it.course))
        let kind: String? = switch it.type {
        case .exam: "Exam"
        case .presentation: "Presenting"
        default: nil
        }
        return HStack(spacing: 10) {
            if study {
                CheckButton(done: checked) { finish(block: it) }
            } else {
                Capsule().fill(colour).frame(width: 4, height: 30).frame(width: 44).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(it.title).strikethrough(checked, color: .secondary)
                if let line = Fmt.meta([Text([kind, when].compactMap { $0 }.joined(separator: ", ")).foregroundStyle(Color.secondary),
                                        it.course.map { Text($0).foregroundStyle(colour) }]) {
                    line.font(.subheadline)
                }
            }
            .rowWords { editingItem = it }
            if study {
                PlayButton(planned: minutes ?? it.durationMin) { store.startFocus(it, minutes: $0) }
                MarkColumn {}
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
        .swipeActions(edge: .leading) {
            if study { Button("Done", systemImage: "checkmark") { finish(block: it) }.tint(.brand) }
        }
    }

    /// Something coming up: tick it off, Play, its letter.
    private func itemRow(_ it: Item) -> some View {
        let checked = ticking.contains(it.id)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { finish(block: it) }
            VStack(alignment: .leading, spacing: 2) {
                Text(it.title).strikethrough(checked, color: .secondary)
                if let sub = Fmt.subline(it, today, in: store.state) { sub.font(.subheadline).foregroundStyle(.secondary) }
            }
            .rowWords { editingItem = it }
            PlayButton(planned: it.sessions.first { !$0.done }?.minutes) { store.startFocus(it, minutes: $0) }
            MarkColumn { if it.priority != nil { LetterMark(letter: it.priority) } }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { finish(block: it) }.tint(.brand)
        }
    }

    private func removeFromToday(_ item: Item) -> some View {
        Button("Remove from Today", systemImage: "sun.max") {
            withAnimation { store.change { s in if let i = s.index(of: item.id) { s.items[i].myDay = nil } } }
        }
        .tint(.gray)
    }

    /// Ticks off a row of the day: its session, its occurrence, or the item.
    private func finish(_ r: Row) {
        tickOff(r.key, r.item.title) { s in
            if dayRows(s.items, today, realToday: today).contains(where: { $0.key == r.key }) {
                s.complete(r, today: today)
            } else {
                s.completeLater(r.item.id, today: today)
            }
        }
    }

    /// Ticks off a study block for today, or something coming up.
    private func finish(block it: Item) {
        tickOff(it.id, it.title) { $0.completeLater(it.id, today: today) }
    }

    /// The circle fills first, then the row glides away.
    private func tickOff(_ key: String, _ title: String, _ edit: @escaping (inout AppState) -> Void) {
        ticking.insert(key)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change(undo: "\u{201C}\(title)\u{201D} done", edit)
                ticking.remove(key)
            }
        }
    }

    /// The small line under a to-do: steps, due, reminder, repeat and note, only what it has.
    private func meta(_ t: Todo, at: Int? = nil) -> Text? {
        var parts: [Text] = []
        if let at {
            // Red once its time has passed.
            parts.append(Text(Fmt.span(at, 0)).foregroundStyle(at < minute ? Color.red : Color.secondary))
        }
        if !t.steps.isEmpty {
            parts.append(Text("\(t.steps.filter(\.done).count)\u{00A0}of\u{00A0}\(t.steps.count)").foregroundStyle(Color.secondary))
        }
        if at == nil, let due = Fmt.dueLine(t.date, t.time, today) {
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

/// A line of Coming up: an item or a to-do, by its date.
struct Upcoming: Identifiable {
    let id: String
    let date: Day
    let time: String?
    var item: Item?
    var todo: Todo?
}

extension DayEntry {
    /// Something to do, counted in Today's summary; work split over the day counts once.
    var isTask: Bool {
        switch kind {
        case .work: (part ?? 1) == 1
        case .over, .todo: true
        case .block(let it), .allDay(let it): it.type == .study
        case .now, .free, .endOfDay: false
        }
    }
}
