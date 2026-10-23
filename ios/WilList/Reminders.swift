import UserNotifications
import WilListCore

/// Notifications: the evening nudge to plan tomorrow, and a reminder for every to-do and item
/// with a "Remind me" time.
enum Reminders {
    static let category = "task"
    nonisolated static let planTomorrow = "plan-tomorrow"
    static let doneAction = "done"
    static let snoozeAction = "snooze"

    /// Asks once; false when notifications are turned off for WilList.
    static func allowed() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) == true
    }

    /// Schedules or clears the nudge. False when notifications are turned off for WilList.
    static func update(_ settings: Settings) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [planTomorrow])
        guard settings.notify else { return true }
        guard await allowed() else { return false }
        let m = timeToMin(settings.planTime) ?? 1230
        let content = UNMutableNotificationContent()
        content.title = "Plan tomorrow"
        content.body = "Two minutes: write down anything new and pick tomorrow’s A1."
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: m / 60, minute: m % 60), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: planTomorrow, content: content, trigger: trigger))
        return true
    }

    /// One pending reminder.
    struct Due: Equatable {
        let id: String, title: String, body: String, at: DateComponents
    }

    /// Every reminder still to come, soonest first.
    static func due(_ s: AppState, today: Day) -> [Due] {
        let todos = s.todos.filter { !$0.done }.compactMap { t in
            remind(t.remindAt).map { Due(id: t.id, title: t.title, body: Fmt.dueLine(t.date, t.time, today) ?? "Reminder", at: $0) }
        }
        let items = s.items.filter { !$0.done }.compactMap { it in
            remind(it.remindAt).map { Due(id: it.id, title: it.title, body: Fmt.when(it, today) ?? "Reminder", at: $0) }
        }
        let now = Date.now
        return (todos + items)
            .filter { (Calendar.current.date(from: $0.at) ?? .distantPast) > now }
            .sorted { (Calendar.current.date(from: $0.at) ?? .now) < (Calendar.current.date(from: $1.at) ?? .now) }
    }

    /// Makes the pending reminders match the plan. iOS keeps at most 64, so the soonest 60 go in;
    /// the rest follow as those pass, because this runs every time the app opens.
    /// Never asks: the question comes when someone first sets a reminder (see `ReminderRow`).
    static func sync(_ reminders: [Due]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let status = await center.notificationSettings().authorizationStatus
        guard !reminders.isEmpty, [.authorized, .provisional, .ephemeral].contains(status) else { return }
        center.setNotificationCategories([UNNotificationCategory(identifier: category, actions: [
            UNNotificationAction(identifier: doneAction, title: "Mark done", options: []),
            UNNotificationAction(identifier: snoozeAction, title: "Snooze 10 min", options: []),
        ], intentIdentifiers: [])])
        for r in reminders.prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = r.title
            content.body = r.body
            content.sound = .default
            content.categoryIdentifier = category
            content.userInfo = ["id": r.id]
            let trigger = UNCalendarNotificationTrigger(dateMatching: r.at, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminderPrefix + r.id, content: content, trigger: trigger))
        }
    }

    /// "2026-10-23T18:00" as calendar components, or nil.
    static func remind(_ at: String?) -> DateComponents? {
        guard let at, let t = at.firstIndex(of: "T") else { return nil }
        let day = String(at[..<t]), parts = day.split(separator: "-").compactMap { Int($0) }
        guard isValidDay(day), parts.count == 3, let m = timeToMin(String(at[at.index(after: t)...])) else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: m / 60, minute: m % 60)
    }

    /// The other way round: a date as "YYYY-MM-DDTHH:MM".
    static func stamp(_ date: Date) -> String {
        "\(WilListCore.today(date))T\(minToTime(nowMinutes(date)))"
    }
}

/// What the number on the app icon counts.
enum Badge: String, CaseIterable, Identifiable {
    case off, today, due
    var id: Self { self }

    var name: String {
        switch self {
        case .off: "Off"
        case .today: "Open on Today"
        case .due: "Due and overdue"
        }
    }

    func count(_ s: AppState, today: Day) -> Int {
        switch self {
        case .off:
            return 0
        case .today:
            return s.todos.filter { !$0.done }.count + s.items.filter { $0.myDay == today && !$0.done }.count
        case .due:
            let todos = s.todos.filter { !$0.done && ($0.date.map { diffDays(today, $0) <= 0 } ?? false) }.count
            let items = s.items.filter { it in
                !it.done && it.recur == nil && it.type != .event && (it.date.map { diffDays(today, $0) <= 0 } ?? false) && !isPast(it, today)
            }.count
            return todos + items
        }
    }
}
