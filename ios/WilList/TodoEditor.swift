import SwiftUI
import WilListCore

/// Everything about one to-do: steps, a reminder, when it's due, a repeat and a note, and a letter
/// to move it into the plan. Changes save as you make them.
struct TodoEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("confirmDelete") private var confirmDelete = false
    let id: String
    @State private var asking = false

    var body: some View {
        NavigationStack {
            Group {
                if let todo = store.state.todos.first(where: { $0.id == id }) {
                    form(todo)
                } else {
                    ContentUnavailableView("Deleted", systemImage: "trash")
                }
            }
            .navigationTitle("To-do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func form(_ todo: Todo) -> some View {
        let today = store.today
        return Form {
            Section {
                HStack(spacing: 4) {
                    CheckButton(done: todo.done) {
                        if !todo.done { Chime.play() }
                        withAnimation(.snappy) { store.change { $0.toggleTodo(id, today: today) } }
                    }
                    TextField("Title", text: field(\.title), axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .strikethrough(todo.done, color: .secondary)
                    StarButton(on: field(\.starred))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                StepsList(steps: field(\.steps))
            }

            Section {
                ReminderRow(at: field(\.remindAt), today: today)
                DueRow(date: field(\.date), time: field(\.time), today: today)
                RepeatRow(recur: field(\.recur), date: field(\.date), today: today)
            }

            Section("Note") {
                TextField("Add a note", text: field(\.notes), axis: .vertical).lineLimit(3...12)
            }

            // A to-do that turned out to matter: into the plan, where it can be the A1.
            if !todo.done {
                Section {
                    Menu {
                        LetterChoices { letter in letter.map { give(todo, $0) } }
                    } label: {
                        Label("Give it a letter", systemImage: "list.number").fillsRow()
                    }
                }
            }

            Section {
                Button("Delete", role: .destructive) {
                    if confirmDelete { asking = true } else { delete(todo) }
                }
            } footer: {
                Text(created(todo))
            }
        }
        .sheetGround()
        .confirmationDialog("Delete \u{201C}\(todo.title)\u{201D}?", isPresented: $asking, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete(todo) }
        }
    }

    /// A field of this to-do, saved as it changes.
    private func field<T>(_ path: WritableKeyPath<Todo, T>) -> Binding<T> {
        Binding(
            get: { store.state.todos.first { $0.id == id }.map { $0[keyPath: path] } ?? Todo(id: id, title: "")[keyPath: path] },
            set: { v in store.change { s in
                if let i = s.todos.firstIndex(where: { $0.id == id }) { s.todos[i][keyPath: path] = v }
            } }
        )
    }

    private func created(_ todo: Todo) -> String {
        let f = { (d: Day) in Fmt.date(d).formatted(.dateTime.weekday(.wide).day().month(.wide)) }
        if todo.done, let d = todo.doneAt { return "Completed \(f(d))" }
        return todo.createdAt.map { "Created \(f($0))" } ?? ""
    }

    private func give(_ todo: Todo, _ letter: Letter) {
        let today = store.today
        dismiss()
        withAnimation {
            store.change(undo: "Moved \u{201C}\(todo.title)\u{201D} to Plan as \(letter.rawValue)") { $0.letterTodo(todo.id, letter, today: today) }
        }
    }

    private func delete(_ todo: Todo) {
        dismiss()
        withAnimation { store.change(undo: "Deleted \u{201C}\(todo.title)\u{201D}") { $0.removeTodo(todo.id) } }
    }
}
