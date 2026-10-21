import SwiftUI
import WilListCore

/// Search across every tab: to-dos, and the items in Goals and Study, by title, step, note or course.
struct SearchView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var todo: String?
    @State private var item: Item?

    private var words: [String] { query.lowercased().split(separator: " ").map(String.init) }

    private func matches(_ texts: [String]) -> Bool {
        let all = texts.joined(separator: " ").lowercased()
        return !words.isEmpty && words.allSatisfy(all.contains)
    }

    private var todos: [Todo] {
        store.state.todos.filter { matches([$0.title, $0.notes] + $0.steps.map(\.title)) }.sorted { !$0.done && $1.done }
    }

    private var items: [Item] {
        store.state.items.filter { matches([$0.title, $0.notes, $0.course ?? "", $0.delegateTo] + $0.steps.map(\.title)) }
            .sorted { !$0.done && $1.done }
    }

    var body: some View {
        NavigationStack {
            List {
                if !todos.isEmpty {
                    Section("To-dos") {
                        ForEach(todos) { t in
                            Button { todo = t.id } label: {
                                result(t.title, Fmt.dueLine(t.date, t.time, store.today), done: t.done)
                            }
                        }
                    }
                }
                if !items.isEmpty {
                    Section("Goals and study") {
                        ForEach(items) { it in
                            Button { item = it } label: {
                                result(it.title, Fmt.subline(it, store.today), done: it.done, letter: it.priority)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if !words.isEmpty && todos.isEmpty && items.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "To-dos, goals, study, notes")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: Binding(get: { todo.map(Opened.init) }, set: { todo = $0?.id })) { TodoEditor(id: $0.id) }
            .sheet(item: $item) { ItemEditor(item: $0) }
        }
    }

    private func result(_ title: String, _ sub: String?, done: Bool, letter: Letter? = nil) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                if let sub, !sub.isEmpty { Text(sub).font(.subheadline).foregroundStyle(Color.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if letter != nil { LetterMark(letter: letter) }
        }
    }
}
