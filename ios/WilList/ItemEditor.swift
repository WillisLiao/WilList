import SwiftUI
import WilListCore

/// Everything about one item, with its study plan.
struct ItemEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: Item
    @State private var confirmDelete = false

    init(item: Item) { _item = State(initialValue: item) }

    private var planned: Bool { plannedTypes.contains(item.type) && item.recur == nil }

    private var dueWord: String {
        switch item.type {
        case .deadline, .reading: "Due"
        case .exam, .presentation, .event: "On"
        case .task: "Date"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $item.title, axis: .vertical).font(.title3)
                    Picker("Kind", selection: $item.type) {
                        ForEach(ItemType.allCases, id: \.self) { Text($0.name).tag($0) }
                    }
                    Picker("Letter", selection: $item.priority) {
                        Text("None").tag(Letter?.none)
                        ForEach(Letter.allCases, id: \.self) { Text("\($0.rawValue)  \($0.name)").tag(Letter?.some($0)) }
                    }
                    if item.priority == .D {
                        TextField("Who will do it?", text: $item.delegateTo)
                    }
                } footer: {
                    if let l = item.priority { Text(l.meaning) }
                }

                Section("Steps") {
                    StepsList(steps: $item.steps)
                }

                Section {
                    AddToTodayRow(myDay: $item.myDay, today: store.today)
                    ReminderRow(at: $item.remindAt, today: store.today)
                    DueRow(date: $item.date, time: $item.time, today: store.today,
                           title: dueWord, add: "Add a date")
                    RepeatRow(recur: $item.recur, date: $item.date, today: store.today)
                    if item.type == .event {
                        Stepper("Lasts \(Fmt.minutes(item.durationMin ?? 60))", value: Binding(get: { item.durationMin ?? 60 }, set: { item.durationMin = $0 }), in: 5...600, step: 5)
                    }
                    Label {
                        TextField("Course or project", text: Binding(get: { item.course ?? "" }, set: { item.course = $0.isEmpty ? nil : $0 }))
                    } icon: {
                        // In the course's colour, once it has one: a course already in the plan shows
                        // its colour as it's typed.
                        Image(systemName: "graduationcap").foregroundStyle(CourseColor.of(store.state.courseColor(item.course)))
                    }
                }

                if planned {
                    Section {
                        Stepper("Prep \(Fmt.minutes(item.effortMin))", value: $item.effortMin, in: 0...6000, step: 30)
                        if let w = item.weightPct { LabeledContent("Share of grade", value: "\(w.formatted())%") }
                        ForEach(item.sessions) { s in
                            HStack {
                                Image(systemName: s.done ? Look.current.box.done : Look.current.box.empty)
                                    .foregroundStyle(s.done ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.label)
                                    Text("\(Fmt.day(s.date, store.today)), \(Fmt.minutes(s.minutes))")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Study plan")
                    } footer: {
                        if item.shortfallMin > 0 {
                            Text("There isn’t enough time before it for all of this: \(Fmt.minutes(item.shortfallMin)) short. Start now, or raise your daily study time in More.")
                        } else if item.sessions.isEmpty && item.effortMin > 0 {
                            Text("Save to plan the study sessions.")
                        } else if !item.sessions.isEmpty {
                            Text("Spread back from the date, around everything else you have on.")
                        }
                    }
                }

                Section("Notes") {
                    TextField("Anything to remember", text: $item.notes, axis: .vertical).lineLimit(2...8)
                }

                Section {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle(item.type.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(item)
                        dismiss()
                    }
                    .disabled(item.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \u{201C}\(item.title)\u{201D}?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(item.id)
                    dismiss()
                }
            }
        }
    }
}
