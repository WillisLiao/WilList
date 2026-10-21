import SwiftUI
import WilListCore

@main
struct WilListApp: App {
    @State private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
        }
    }
}

enum AppTab: String, Hashable { case today, goals, study, more }

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var phase
    // `-tab goals` on launch opens a tab directly (screenshots, Shortcuts debugging).
    @State private var tab = UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init) ?? .today

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "checklist", value: .today) { TodayView() }
            Tab("Goals", systemImage: "target", value: .goals) { GoalsView() }
            Tab("Study", systemImage: "book.closed", value: .study) { StudyView() }
            Tab("More", systemImage: "ellipsis", value: .more) { MoreView() }
        }
        .minimizingTabBar()
        .onOpenURL { url in
            store.incomingFile = url
            tab = .goals
        }
        .onChange(of: phase, initial: true) {
            guard phase == .active else { return }
            store.refreshDay()
            Task { await store.syncFeeds() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in store.refreshDay() }
        .task(id: store.state.settings) {
            if await !Reminders.update(store.state.settings) {
                store.change { $0.settings.notify = false }
                store.say("Notifications are off for WilList. Turn them on in the Settings app.")
            }
        }
    }
}
