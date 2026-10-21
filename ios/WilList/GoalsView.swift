import SwiftUI
import WilListCore

/// Goals: your main goal, the one thing to do first, the rest of the day in ABCDE order and
/// anything still waiting for a letter. Tomorrow and the full list of goals are one tap away.
struct GoalsView: View {
    // `-open tomorrow` or `-open goals` on launch opens that screen (screenshots).
    @State private var path = UserDefaults.standard.string(forKey: "open").flatMap(GoalsPage.init).map { [$0] } ?? []

    var body: some View {
        NavigationStack(path: $path) {
            PlanList(tomorrow: false)
                .navigationDestination(for: GoalsPage.self) { page in
                    switch page {
                    case .tomorrow: PlanList(tomorrow: true)
                    case .goals: GoalsList()
                    }
                }
        }
    }
}

enum GoalsPage: String, Hashable { case tomorrow, goals }

/// One day in ABCDE order with its first thing on top. Goals shows today; Plan tomorrow shows tomorrow.
struct PlanList: View {
    @Environment(Store.self) private var store
    let tomorrow: Bool
    @State private var adding = false
    @State private var importing = false
    @State private var editing: Item?
    @State private var ticking: Set<String> = []
    @State private var searching = false

    private var today: Day { store.today }
    private var day: Day { tomorrow ? addDays(today, 1) : today }
    private var rows: [Row] { dayRows(store.state.items, day, realToday: today) }
    /// The first thing worth doing: never something to hand off or drop.
    private var first: Row? { rows.first { $0.priority == .A || $0.priority == .B || $0.priority == .C } }
    private var rest: [Row] { rows.filter { $0.key != first?.key } }
    private var waiting: [Item] { unsorted(store.state.items, today) }
    private var evening: Bool { nowMinutes() >= (timeToMin(store.state.settings.planTime) ?? 1230) }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !tomorrow { goalRow }
                Section {
                    if let first { firstCard(first) } else { emptyCard }
                    ForEach(rest) { itemRow($0) }
                        .onMove(perform: move)
                }
                if !waiting.isEmpty {
                    Section("Needs a letter") {
                        ForEach(waiting) { waitingRow($0) }
                    }
                    .id("letters")
                }
                if !tomorrow {
                    Section { planningRows }
                        .id("bottom")
                }
            }
            .listStyle(.plain)
            #if DEBUG
            // `-scroll letters` or `-sheet add|import` on launch, for screenshots.
            .onAppear {
                guard !tomorrow else { return }
                UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) }
                adding = UserDefaults.standard.string(forKey: "sheet") == "add"
                importing = UserDefaults.standard.string(forKey: "sheet") == "import"
            }
            #endif
        }
        .navigationTitle(tomorrow ? "Tomorrow" : "Goals")
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
        .onChange(of: store.incomingFile, initial: true) { if !tomorrow && store.incomingFile != nil { importing = true } }
        .onChange(of: store.opening, initial: true) {
            if !tomorrow, let id = store.opening, let it = store.state.items.first(where: { $0.id == id }) {
                store.opening = nil
                editing = it
            }
        }
        .sheet(item: $editing) { ItemEditor(item: $0) }
        .toastHost()
    }

    // MARK: rows

    private var goalRow: some View {
        let goal = store.state.mdp, others = store.state.goals.count
        return NavigationLink(value: GoalsPage.goals) {
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.isEmpty ? "Set your main goal" : goal)
                    .font(.headline)
                    .fontDesign(.serif)
                    .foregroundStyle(goal.isEmpty ? Color.accentColor : .primary)
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

    private func firstCard(_ row: Row) -> some View {
        let done = ticking.contains(row.key)
        let streak = tomorrow ? 0 : a1Streak(store.state.meta.firstDone, today)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                LetterMark(letter: row.priority, label: row.label, large: true)
                Text(tomorrow ? "First thing tomorrow" : "Do this first")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if row.overdue { Text("Overdue").font(.subheadline.weight(.medium)).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.item.title)
                    .font(.title2.weight(.semibold))
                    .fontDesign(.serif)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = detail(row) {
                    Text(detail).foregroundStyle(.secondary)
                }
                // A session is part of something bigger: say what it is for and when that is due.
                if row.session != nil, let due = Fmt.when(row.item, day) {
                    Text([due, row.item.course].compactMap { $0 }.joined(separator: ", ")).foregroundStyle(.secondary)
                }
            }
            Button {
                complete(row)
            } label: {
                Label(done ? "Done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: done) { _, new in new }
            .padding(.top, 6)
            if streak > 0 {
                Text("\(streak) \(streak == 1 ? "day" : "days") in a row you started with an A.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { editing = row.item }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
    }

    private var emptyCard: some View {
        Text(!waiting.isEmpty ? "Give the items below a letter. The most important one shows up here."
             : tomorrow ? "Nothing planned for tomorrow yet. Add what you'll do with +."
             : "Nothing on the list. Add what you need to do with +.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
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
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
            letterMenu(row.item) { LetterMark(letter: row.priority, label: row.label) }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.accentColor)
            if !tomorrow { addToToday(row.item) }
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
        .tint(.orange)
    }

    private func waitingRow(_ item: Item) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                let sub = Fmt.subline(item, today)
                if !sub.isEmpty { Text(sub).font(.subheadline).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editing = item }
            letterMenu(item) {
                Text("Letter")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 30)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 8))
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
            label().frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: item.priority)
        .accessibilityLabel(item.priority.map { "Letter \($0.rawValue), \($0.name). Change" } ?? "Give it a letter")
    }

    private var planningRows: some View {
        Group {
            NavigationLink(value: GoalsPage.tomorrow) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plan tomorrow")
                        if evening {
                            Text("It's evening. Pick tomorrow's first thing now.").font(.subheadline).foregroundStyle(.secondary)
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

    /// What this row is about: the study session that is due, or when the item is.
    private func detail(_ row: Row) -> String? {
        if let s = row.session {
            let more = row.extra > 0 ? " (+\(row.extra) more)" : ""
            return "\(s.label), \(Fmt.minutes(s.minutes))\(more)"
        }
        if row.item.priority == .D, !row.item.delegateTo.isEmpty { return "Ask \(row.item.delegateTo)" }
        let sub = Fmt.subline(row.item, today)
        return sub.isEmpty ? nil : sub
    }

    /// The line under a row: its detail, then small marks for steps, a reminder and Today.
    private func line(_ row: Row) -> Text? {
        Fmt.meta([detail(row).map { Text($0).foregroundStyle(row.overdue ? Color.red : Color.secondary) }]
                 + Fmt.marks(row.item.steps, remind: row.item.remindAt, today: day == today && row.item.myDay == today))
    }

    private func complete(_ row: Row) {
        ticking.insert(row.key)
        Chime.play()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change { $0.complete(row, today: today) }
                ticking.remove(row.key)
            }
        }
    }

    // Reordering only moves within a letter: A2 can become A1, not B1.
    private func move(from: IndexSet, to: Int) {
        let shown = rest
        guard let i = from.first else { return }
        let target = to > i ? to - 1 : to
        guard shown.indices.contains(target), shown[target].priority == shown[i].priority else { return }
        withAnimation {
            store.change { s in
                var current = dayRows(s.items, day, realToday: today)
                let key = shown[i].key
                for _ in 0..<abs(target - i) {
                    s.move(current, key: key, by: target > i ? 1 : -1)
                    current = dayRows(s.items, day, realToday: today)
                }
            }
        }
    }
}

/// Your main goal, the other goals, and how often the day started with an A.
struct GoalsList: View {
    @Environment(Store.self) private var store
    @State private var editingGoal: Goal?
    @State private var editingPurpose = false

    var body: some View {
        List {
            Section {
                Button { editingPurpose = true } label: {
                    Text(store.state.mdp.isEmpty ? "What one goal would change the most for you?" : store.state.mdp)
                        .font(.title3)
                        .fontDesign(.serif)
                        .foregroundStyle(store.state.mdp.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 4)
                }
                .tint(.primary)
            } header: {
                Text("Main goal")
            } footer: {
                Text("The goal that would help you most if you reached it.")
            }

            Section {
                ForEach(store.state.goals) { goal in
                    Button { editingGoal = goal } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title)
                            if isValidDay(goal.deadline) {
                                Text("By \(Fmt.date(goal.deadline).formatted(.dateTime.day().month(.wide).year()))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { idx in
                    let ids = idx.map { store.state.goals[$0].id }
                    store.change(undo: "Deleted a goal") { s in s.goals.removeAll { ids.contains($0.id) } }
                }
                Button("Add a goal", systemImage: "plus") { editingGoal = Goal(id: "", title: "") }
            } header: {
                Text("Other goals")
            } footer: {
                Text("Give each goal a deadline, then break it into items with a letter.")
            }

            Section("Last 21 days") {
                StreakDots(firstDone: store.state.meta.firstDone, today: store.today)
            }
        }
        .navigationTitle("Your goals")
        .sheet(item: $editingGoal) { GoalEditor(goal: $0) }
        .sheet(isPresented: $editingPurpose) { PurposeEditor() }
        .toastHost()
    }
}

/// The last 21 days: filled where the first thing you finished was an A.
struct StreakDots: View {
    let firstDone: [Day: String]
    let today: Day

    var body: some View {
        let days = (0..<21).map { addDays(today, $0 - 20) }
        let streak = a1Streak(firstDone, today)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { d in
                    Circle()
                        .fill(firstDone[d] == "A" ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.systemFill)))
                        .overlay { if d == today { Circle().strokeBorder(.tint, lineWidth: 1.5) } }
                        .frame(width: 11, height: 11)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(days.filter { firstDone[$0] == "A" }.count) of the last 21 days started with an A")
            Text(streak == 0
                 ? "Finish an A before anything else today to start a streak. A habit takes about 21 days."
                 : "\(streak) \(streak == 1 ? "day" : "days") in a row your first finished thing was an A.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct PurposeEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Graduate with honours and land a design internship", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } footer: {
                    Text("Your one major definite purpose: the goal that would help you most if you reached it.")
                }
            }
            .navigationTitle("Main goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.change { $0.mdp = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                        dismiss()
                    }
                }
            }
            .onAppear { text = store.state.mdp }
        }
        .presentationDetents([.medium])
    }
}

struct GoalEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var goal: Goal
    @State private var hasDeadline = false
    @State private var deadline = Date.now.addingTimeInterval(90 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Goal", text: $goal.title, axis: .vertical)
                    Picker("Area", selection: $goal.area) {
                        Text("Study or work").tag(Goal.Area.academic)
                        Text("Personal").tag(Goal.Area.personal)
                        Text("Health and self").tag(Goal.Area.`self`)
                    }
                    Toggle("Deadline", isOn: $hasDeadline)
                    if hasDeadline { DatePicker("By", selection: $deadline, displayedComponents: .date) }
                }
                Section("Why you want it") { TextField("The reasons that will keep you going", text: $goal.why, axis: .vertical) }
                Section("The biggest obstacle") { TextField("The one thing most in the way", text: $goal.rock, axis: .vertical) }
                Section("What you'll need to learn") { TextField("Skills and knowledge", text: $goal.knowledge, axis: .vertical) }
                Section("Who can help") { TextField("People to ask", text: $goal.people, axis: .vertical) }
                Section("Your reward") { TextField("How you'll celebrate", text: $goal.reward, axis: .vertical) }
            }
            .navigationTitle(goal.id.isEmpty ? "New goal" : "Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(goal.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                hasDeadline = isValidDay(goal.deadline)
                if hasDeadline { deadline = Fmt.date(goal.deadline) }
            }
        }
    }

    private func save() {
        var g = goal
        g.deadline = hasDeadline ? WilListCore.today(deadline) : ""
        let today = store.today
        store.change { s in
            if let i = s.goals.firstIndex(where: { $0.id == g.id }) {
                s.goals[i] = g
            } else {
                g.id = newID()
                g.createdAt = today
                s.goals.append(g)
            }
        }
        dismiss()
    }
}
