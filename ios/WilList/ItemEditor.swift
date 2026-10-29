import SwiftUI
import WilListCore

/// Everything about one item.
struct ItemEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: Item
    @State private var confirmDelete = false

    init(item: Item) { _item = State(initialValue: item) }

    /// Adding to Today, or taking it off, happens at once, not at Save: it isn't an edit to the
    /// task, just where it shows. Everything else waits for Save.
    private var addedToToday: Binding<Day?> {
        Binding(get: { item.myDay }, set: { day in
            item.myDay = day
            store.change { s in if let i = s.index(of: item.id) { s.items[i].myDay = day } }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $item.title, axis: .vertical).font(.hand(.title3))
                }

                // A study block has its time instead of a letter. A row of the five, as when adding
                // a task; tapping the chosen one clears it.
                if item.type != .study {
                    Section {
                        LetterChips(letter: item.priority) { item.priority = $0 }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        if item.priority == .D {
                            TextField("Who will do it?", text: $item.delegateTo)
                        }
                    } footer: {
                        if let l = item.priority { Text(l.meaning) }
                    }
                }

                Section("Steps") {
                    StepsList(steps: $item.steps)
                }

                Section {
                    if item.type != .study { AddToTodayRow(myDay: addedToToday, today: store.today) }
                    ReminderRow(at: $item.remindAt, today: store.today)
                    DueRow(date: $item.date, time: $item.time, today: store.today,
                           title: item.type.dueWord, add: "Add a date")
                    RepeatRow(recur: $item.recur, date: $item.date, today: store.today)
                    if item.type == .study {
                        Stepper("Lasts \(Fmt.minutes(item.durationMin ?? 60))", value: Binding(get: { item.durationMin ?? 60 }, set: { item.durationMin = $0 }), in: 5...600, step: 5)
                    }
                    Label {
                        TextField("Course", text: Binding(get: { item.course ?? "" }, set: { item.course = $0.isEmpty ? nil : $0 }))
                    } icon: {
                        // In the course's colour, once it has one: a course already in the plan shows
                        // its colour as it's typed.
                        SketchIcon(glyph: .cap, size: 19).foregroundStyle(CourseColor.of(store.state.courseColor(item.course)))
                    }
                }

                Section("Notes") {
                    TextField("Add a note", text: $item.notes, axis: .vertical).lineLimit(2...8)
                }

                Section {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
            }
            .sheetGround()
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
