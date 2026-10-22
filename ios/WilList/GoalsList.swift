import SwiftUI
import WilListCore

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
                        .fontDesign(Look.current.titles)
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
        .readableColumn()
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
        .accessibilityElement(children: .combine)
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
                    Toggle("Deadline", isOn: $hasDeadline).tint(.brand)
                    if hasDeadline { DatePicker("By", selection: $deadline, displayedComponents: .date) }
                }
                Section("Why you want it") { TextField("The reasons that will keep you going", text: $goal.why, axis: .vertical) }
                Section("The biggest obstacle") { TextField("The one thing most in the way", text: $goal.rock, axis: .vertical) }
                Section("What you’ll need to learn") { TextField("Skills and knowledge", text: $goal.knowledge, axis: .vertical) }
                Section("Who can help") { TextField("People to ask", text: $goal.people, axis: .vertical) }
                Section("Your reward") { TextField("How you’ll celebrate", text: $goal.reward, axis: .vertical) }
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
