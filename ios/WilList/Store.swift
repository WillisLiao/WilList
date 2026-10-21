import Foundation
import Observation
import WilListCore

/// The planner on this device. Every change goes through `change`, which saves it and can
/// offer an undo.
@Observable
final class Store {
    private(set) var state: AppState
    private(set) var today: Day = WilListCore.today()
    var toast: Toast?
    /// A file shared to WilList from another app, waiting to be read.
    var incomingFile: URL?
    private(set) var syncing = false
    private var undoState: AppState?
    private let file: URL
    private let writer = DispatchQueue(label: "willist.save")

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var canUndo = false
    }

    /// One planner per app, shared by the screens and by Siri and Shortcuts.
    static let shared = Store()

    /// The same file the first, web-based version of the app kept, so nobody loses a plan.
    static let defaultFile: URL = {
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        return URL.applicationSupportDirectory.appending(path: "willist.v1.json")
    }()

    init(file: URL = Store.defaultFile) {
        self.file = file
        guard let data = try? Data(contentsOf: file) else { state = AppState(); return }
        if let saved = try? JSONDecoder().decode(AppState.self, from: data) {
            state = saved
        } else {
            // Never write over a plan we couldn't read: keep it aside so it can be recovered.
            let aside = file.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: file, to: aside)
            state = AppState()
        }
    }

    func change(undo label: String? = nil, _ edit: (inout AppState) -> Void) {
        let before = state
        edit(&state)
        if let label {
            undoState = before
            toast = Toast(text: label, canUndo: true)
        }
        let data = try? JSONEncoder().encode(state), url = file
        writer.async { try? data?.write(to: url, options: .atomic) }
    }

    func undo() {
        guard let before = undoState else { return }
        change { $0 = before }
        undoState = nil
        toast = nil
    }

    func say(_ text: String) { toast = Toast(text: text) }

    /// Called when the app comes to the front and at midnight.
    func refreshDay() {
        today = WilListCore.today()
        // Ticked-off to-dos fade from Today; keep a month of them, then let go.
        let cutoff = addDays(today, -30)
        if state.todos.contains(where: { $0.done && ($0.doneAt ?? today) < cutoff }) {
            change { s in s.todos.removeAll { $0.done && ($0.doneAt ?? cutoff) < cutoff } }
        }
    }

    var dateOrder: String {
        state.settings.dateOrder ?? (DateFormatter.dateFormat(fromTemplate: "dM", options: 0, locale: .current)?.first == "d" ? "dmy" : "mdy")
    }

    // MARK: items

    func add(_ draft: Item) {
        change { s in s.items.append(makeItem(draft, s.settings, today, s.items)) }
    }

    /// Saves an edited item and plans it again when what the plan depends on changed.
    func save(_ item: Item) {
        change { s in
            guard let i = s.index(of: item.id) else { return }
            let old = s.items[i]
            s.items[i] = item
            if old.priority != item.priority {
                s.items[i].priority = old.priority
                s.setLetter(item.id, item.priority, today: today)
            }
            if old.date != item.date || old.effortMin != item.effortMin || old.type != item.type || old.recur != item.recur {
                s.replan(item.id, today: today)
            }
        }
    }

    func delete(_ id: String) {
        let title = state.items.first { $0.id == id }?.title ?? "item"
        change(undo: "Deleted \u{201C}\(title)\u{201D}") { s in s.items.removeAll { $0.id == id } }
    }

    // MARK: calendar links

    func addFeed(_ url: String, name: String) async {
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !state.feeds.contains(where: { $0.url == url }) else { return }
        change { $0.feeds.append(Feed(url: url, name: name)) }
        await sync([url])
    }

    func removeFeed(_ url: String) {
        change { $0.feeds.removeAll { $0.url == url } }
    }

    /// Reads every calendar link that hasn't been read in the last half hour (or all of them).
    func syncFeeds(force: Bool = false) async {
        let due = state.feeds.filter { f in force || (f.syncedAt.map { Date.now.timeIntervalSince($0) > 1800 } ?? true) }
        await sync(due.map(\.url))
    }

    private func sync(_ urls: [String]) async {
        guard !syncing, !urls.isEmpty else { return }
        syncing = true
        defer { syncing = false }
        for url in urls {
            var problem: String?
            do {
                let text = try await Self.fetchCalendar(url)
                let found = importICS(text, today: today)
                change { s in s.applyImport(planImport(s.items, found.items), today: today) }
            } catch {
                problem = (error as? LocalizedError)?.errorDescription ?? "Couldn't read this calendar."
            }
            change { s in
                guard let i = s.feeds.firstIndex(where: { $0.url == url }) else { return }
                s.feeds[i].error = problem
                if problem == nil { s.feeds[i].syncedAt = .now }
            }
        }
    }

    struct FeedError: LocalizedError {
        var errorDescription: String?
    }

    private static func fetchCalendar(_ link: String) async throws -> String {
        var link = link
        if link.lowercased().hasPrefix("webcal://") { link = "https://" + link.dropFirst(9) }
        guard let url = URL(string: link), url.scheme?.hasPrefix("http") == true else {
            throw FeedError(errorDescription: "That isn't a web link.")
        }
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(from: url) } catch {
            throw FeedError(errorDescription: "Couldn't reach it. Check your connection.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw FeedError(errorDescription: "The calendar answered with an error (\(status)). The link may have been reset.") }
        let text = String(decoding: data, as: UTF8.self)
        guard text.contains("BEGIN:VCALENDAR") else { throw FeedError(errorDescription: "That link isn't a calendar feed.") }
        return text
    }
}
