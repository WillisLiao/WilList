import SwiftUI
import WilListCore

/// Search across every tab: to-dos, and the items in Plan and Study, by title, step, note or course.
struct SearchView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var todo: String?
    @State private var item: Item?
    /// Opening Search means typing: the field starts focused, with the keyboard up.
    @FocusState private var typing: Bool

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
                    Section("Plan") {
                        ForEach(items) { it in
                            Button { item = it } label: {
                                result(it.title, Fmt.subline(it, store.today), done: it.done, letter: it.priority)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheetGround()
            .background(CloseWhenCancelled())
            .overlay {
                if !words.isEmpty && todos.isEmpty && items.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "To-dos, plan, study, notes")
            .searchFocused($typing)
            .onAppear { typing = true }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: Binding(get: { todo.map(Opened.init) }, set: { todo = $0?.id })) { TodoEditor(id: $0.id) }
            .sheet(item: $item) { ItemEditor(item: $0) }
        }
    }

    /// While the field is active the system swaps the title bar for an X that only ends the search;
    /// in a sheet that is only for searching, it closes the sheet instead of leaving Done one tap away.
    private struct CloseWhenCancelled: View {
        @Environment(\.isSearching) private var searching
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            Color.clear.onChange(of: searching) { _, now in if !now { dismiss() } }
        }
    }

    private func result(_ title: String, _ sub: String?, done: Bool, letter: Letter? = nil) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                if let sub, !sub.isEmpty { Text(sub).font(.footnote).foregroundStyle(Color.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if letter != nil { LetterMark(letter: letter) }
        }
    }
}
