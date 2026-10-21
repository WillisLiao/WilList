import AppIntents
import UserNotifications
import WilListCore

// Ticking off from a widget. Each intent changes the saved plan directly; the widget redraws when
// it returns, and the app takes the change in when it next comes to the front.

/// Marks a row of the day's list done: the A1, or one of the rows after it.
struct FinishRowIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark done"
    static let isDiscoverable = false

    @Parameter(title: "Row") var key: String

    init() {}
    init(key: String) { self.key = key }

    @MainActor func perform() async throws -> some IntentResult {
        let today = WilListCore.today()
        var finished: String?
        PlanFile.update { s in
            guard let row = dayRows(s.items, today).first(where: { $0.key == key }) else { return }
            if s.complete(row, today: today) { finished = row.item.id }
        }
        if let finished { forgetReminder(finished) }
        return .result()
    }
}

/// Ticks off one of Today's to-dos.
struct TickTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Tick off a to-do"
    static let isDiscoverable = false

    @Parameter(title: "To-do") var todo: String

    init() {}
    init(todo: String) { self.todo = todo }

    @MainActor func perform() async throws -> some IntentResult {
        let today = WilListCore.today()
        PlanFile.update { s in
            if s.todos.contains(where: { $0.id == todo && !$0.done }) { s.toggleTodo(todo, today: today) }
        }
        forgetReminder(todo)
        return .result()
    }
}

/// Pending reminders are named after their task: "remind-" and the task's id (`Reminders.sync`).
let reminderPrefix = "remind-"

/// A finished task's reminder shouldn't still go off. The app re-syncs every reminder when it
/// next opens; this only covers the time until then.
private func forgetReminder(_ id: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderPrefix + id])
}
