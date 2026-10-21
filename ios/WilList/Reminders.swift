import UserNotifications
import WilListCore

/// The evening nudge to plan tomorrow, at the time set in More.
enum Reminders {
    /// Schedules or clears the nudge. False when notifications are turned off for WilList.
    static func update(_ settings: Settings) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["plan-tomorrow"])
        guard settings.notify else { return true }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
        let m = timeToMin(settings.planTime) ?? 1230
        let content = UNMutableNotificationContent()
        content.title = "Plan tomorrow"
        content.body = "Two minutes now: give tomorrow's list its letters and pick your A1."
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: m / 60, minute: m % 60), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: "plan-tomorrow", content: content, trigger: trigger))
        return true
    }
}
