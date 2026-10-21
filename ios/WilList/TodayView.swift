import SwiftUI
import WilListCore

/// Today: a plain checklist. No letters, no dates; write it down, tick it off.
struct TodayView: View {
    @Environment(Store.self) private var store
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var ticking: Set<String> = []

    private var open: [Todo] { store.state.todos.filter { !$0.done } }
    private var doneToday: [Todo] { store.state.todos.filter { $0.done && $0.doneAt == store.today } }

    var body: some View {
        NavigationStack {
            List {
                header
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 16, trailing: 20))
                Section {
                    addRow
                    ForEach(open) { todo in
                        row(todo)
                            .swipeActions(edge: .leading) {
                                Button("Done", systemImage: "checkmark") { tick(todo) }.tint(.accentColor)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(todo) }
                            }
                    }
                    .onMove { from, to in
                        var list = open
                        list.move(fromOffsets: from, toOffset: to)
                        store.change { s in s.todos = list + s.todos.filter(\.done) }
                    }
                }
                if !doneToday.isEmpty {
                    Section {
                        ForEach(doneToday) { todo in
                            row(todo)
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", systemImage: "trash", role: .destructive) { delete(todo) }
                                }
                        }
                    } header: {
                        Text("Done today")
                    }
                }
            }
            .listStyle(.plain)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .toastHost()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Fmt.long(store.today))
                .font(.largeTitle.bold())
                .fontDesign(.serif)
                .accessibilityAddTraits(.isHeader)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        switch (open.count, doneToday.count) {
        case (0, 0): "Write down what's on your mind, one line each."
        case (0, let d): "All clear. \(d) done today."
        case (let n, 0): "\(n) to do."
        case (let n, let d): "\(n) to do, \(d) done."
        }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            TextField("Add a to-do", text: $draft)
                .focused($typing)
                .submitLabel(.done)
                .onSubmit(add)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 20))
    }

    private func row(_ todo: Todo) -> some View {
        let checked = todo.done || ticking.contains(todo.id)
        return HStack(spacing: 10) {
            CheckButton(done: checked) { todo.done ? untick(todo) : tick(todo) }
            Text(todo.title)
                .strikethrough(checked, color: .secondary)
                .foregroundStyle(todo.done ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 20))
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { typing = false; return }
        withAnimation(.snappy) { store.change { $0.addTodo(text) } }
        draft = ""
        typing = true // keep the keyboard up for the next one
    }

    // The circle fills first, then the row glides down to Done.
    private func tick(_ todo: Todo) {
        ticking.insert(todo.id)
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.snappy) {
                store.change { $0.toggleTodo(todo.id, today: store.today) }
                ticking.remove(todo.id)
            }
        }
    }

    private func untick(_ todo: Todo) {
        withAnimation(.snappy) { store.change { $0.toggleTodo(todo.id, today: store.today) } }
    }

    private func delete(_ todo: Todo) {
        withAnimation { store.change(undo: "Deleted \u{201C}\(todo.title)\u{201D}") { $0.removeTodo(todo.id) } }
    }
}
