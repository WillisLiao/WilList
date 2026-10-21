import SwiftUI
import WilListCore

/// Goals: the ABCDE list with the one thing to do first, the items still waiting for a letter,
/// the A1-first habit and the long-term goals behind it all.
struct GoalsView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var importing = false
    @State private var editing: Item?
    @State private var editingGoal: Goal?
    @State private var editingPurpose = false
    @State private var tomorrow = false
    @State private var ticking: Set<String> = []

    private var today: Day { store.today }
    private var day: Day { tomorrow ? addDays(today, 1) : today }
    private var rows: [Row] { dayRows(store.state.items, day, realToday: today) }
    /// The first thing worth doing: never something to hand off or drop.
    private var first: Row? { rows.first { $0.priority == .A || $0.priority == .B || $0.priority == .C } }
    private var rest: [Row] { rows.filter { $0.key != first?.key } }
    private var waiting: [Item] { unsorted(store.state.items, today) }
    private var evening: Bool { nowMinutes() >= (timeToMin(store.state.settings.planTime) ?? 1230) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section {
                    Picker("Day", selection: $tomorrow) {
                        Text("Today").tag(false)
                        Text("Tomorrow").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    if evening && !tomorrow {
                        Text("It's evening. Plan tomorrow now and wake up knowing your A1.")
                    }
                }

                Section(tomorrow ? "First thing tomorrow" : "Do this first") {
                    if let first {
                        firstBlock(first)
                    } else {
                        Text(waiting.isEmpty ? "Nothing on the list. Add what you need to do with +." : "Nothing lettered yet. Give the items below a letter and the most important one shows here.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !rest.isEmpty {
                    Section("Then") {
                        ForEach(rest) { itemRow($0) }
                            .onMove(perform: move)
                    }
                }

                if !waiting.isEmpty {
                    Section {
                        ForEach(waiting) { sortRow($0) }
                    } header: {
                        Text("Needs a letter")
                    } footer: {
                        Text(Letter.allCases.map { "\($0.rawValue): \($0.meaning)" }.joined(separator: "\n"))
                    }
                    .id("letters")
                }

                Section("21 days of A1 first") { StreakDots(firstDone: store.state.meta.firstDone, today: today) }
                    .id("streak")

                goalsSection

                Section {
                    Button { importing = true } label: {
                        Label("Bring in a schedule", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("A syllabus, a timetable, a project plan or a roster, from a file, a photo or a calendar link.")
                }
            }
            #if DEBUG
            // `-scroll streak` on launch, for screenshots of the lower sections.
            .onAppear { UserDefaults.standard.string(forKey: "scroll").map { proxy.scrollTo($0, anchor: .top) } }
            #endif
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $adding) { AddItemSheet() }
            .sheet(isPresented: $importing) { ImportSheet() }
            .onChange(of: store.incomingFile, initial: true) { if store.incomingFile != nil { importing = true } }
            .sheet(item: $editing) { ItemEditor(item: $0) }
            .sheet(item: $editingGoal) { GoalEditor(goal: $0) }
            .sheet(isPresented: $editingPurpose) { PurposeEditor() }
            .toastHost()
        }
    }

    // MARK: rows

    private func firstBlock(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LetterMark(letter: row.priority, label: row.label, large: true)
                Spacer()
                if row.overdue { Text("Overdue").font(.footnote.weight(.medium)).foregroundStyle(.red) }
            }
            Text(row.item.title)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = detail(row) {
                Text(detail).foregroundStyle(.secondary)
            }
            // A session is part of something bigger: say what it is for and when that is due.
            if row.session != nil, let due = Fmt.when(row.item, day) {
                Text([due, row.item.course].compactMap { $0 }.joined(separator: ", ")).foregroundStyle(.secondary)
            }
            Button {
                complete(row)
            } label: {
                Label(ticking.contains(row.key) ? "Done" : "Mark done", systemImage: ticking.contains(row.key) ? "checkmark.circle.fill" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: ticking.contains(row.key)) { _, new in new }
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { editing = row.item }
    }

    private func itemRow(_ row: Row) -> some View {
        HStack(spacing: 10) {
            CheckButton(done: ticking.contains(row.key)) { complete(row) }
            LetterMark(letter: row.priority, label: row.label)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.item.title)
                    .strikethrough(row.priority == .E || ticking.contains(row.key), color: .secondary)
                    .foregroundStyle(row.priority == .E ? .secondary : .primary)
                if let detail = detail(row) {
                    Text(detail).font(.subheadline).foregroundStyle(row.overdue ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editing = row.item }
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 16))
        .swipeActions(edge: .leading) {
            Button("Done", systemImage: "checkmark") { complete(row) }.tint(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(row.item.id) }
            Menu {
                letterButtons(row.item)
            } label: {
                Label("Letter", systemImage: "textformat.abc")
            }
        }
        .contextMenu { letterButtons(row.item) }
    }

    private func sortRow(_ item: Item) -> some View {
        let suggested = suggestedLetter(item.type, weightPct: item.weightPct)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                let sub = Fmt.subline(item, today)
                if !sub.isEmpty { Text(sub).font(.subheadline).foregroundStyle(.secondary) }
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = item }
            HStack(spacing: 8) {
                ForEach(Letter.allCases, id: \.self) { l in
                    Button {
                        withAnimation(.snappy) { store.change { $0.setLetter(item.id, l, today: today) } }
                    } label: {
                        LetterMark(letter: l, large: true, suggested: l == suggested)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(l.rawValue): \(l.meaning)")
                }
            }
            .sensoryFeedback(.selection, trigger: item.priority)
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(item.id) }
        }
    }

    @ViewBuilder private func letterButtons(_ item: Item) -> some View {
        ForEach(Letter.allCases, id: \.self) { l in
            Button("\(l.rawValue): \(l.meaning)") { withAnimation { store.change { $0.setLetter(item.id, l, today: today) } } }
        }
        Button("No letter") { withAnimation { store.change { $0.setLetter(item.id, nil, today: today) } } }
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

    private func complete(_ row: Row) {
        ticking.insert(row.key)
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

    // MARK: goals

    private var goalsSection: some View {
        Section {
            Button { editingPurpose = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Main goal").font(.subheadline).foregroundStyle(.secondary)
                    Text(store.state.mdp.isEmpty ? "What one goal would change the most for you? Write it here." : store.state.mdp)
                        .foregroundStyle(store.state.mdp.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }
            }
            .tint(.primary)
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
            Text("Goals")
        } footer: {
            Text("Written goals with a deadline get done. Break each one into items with a letter.")
        }
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
