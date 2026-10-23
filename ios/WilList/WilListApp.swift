import SwiftUI
import UserNotifications
import WilListCore

@main
struct WilListApp: App {
    @State private var store = Store.shared
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Screen titles in the look's face (New York for Meadow), like the date on Today. Set once the
    // app has launched: touching UIKit appearance any earlier (in App.init) loses the accent colour.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Self.titleFont(.largeTitle)]
        bar.titleTextAttributes = [.font: Self.titleFont(.headline)]
        UNUserNotificationCenter.current().delegate = self
        // Mark done on the focus Live Activity runs here, with the app in the background if need be.
        Focus.finish = { done in Store.shared.finishFocus(done: done) }
        if Store.shared.focus == nil { LiveFocus.end() }
        return true
    }

    // Home-screen quick actions arrive through the scene.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { SceneDelegate.perform(item) }
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Reminders show while WilList is open, too. The end of a focus session doesn't: the focus
    // screen says so itself.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.identifier == FocusNotice.id ? [] : [.banner, .list, .sound]
    }

    // Mark done, snooze, or open the task the reminder is about. The evening notice opens Plan tomorrow.
    // On the main actor from start to end: UIKit stops the app if the system's completion handler,
    // called when this returns, runs anywhere else (Mark done on a reminder crashed it).
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if response.notification.request.identifier == Reminders.planTomorrow {
            Store.shared.planningTomorrow = true
            return
        }
        guard let id = response.notification.request.content.userInfo["id"] as? String else { return }
        Store.shared.answerReminder(id, action: response.actionIdentifier)
    }

    private static func titleFont(_ style: UIFont.TextStyle) -> UIFont {
        let design: UIFontDescriptor.SystemDesign = switch Look.current.titles {
        case .serif: .serif
        case .rounded: .rounded
        default: .default
        }
        let base = UIFont.preferredFont(forTextStyle: style).fontDescriptor
        let d = (base.withDesign(design) ?? base).withSymbolicTraits(.traitBold) ?? base
        return UIFont(descriptor: d, size: 0)
    }
}

enum AppTab: String, Hashable { case today, plan, study, more }

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var phase
    // `-tab plan` on launch opens a tab directly (screenshots, Shortcuts debugging).
    @State private var tab = UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init) ?? .today
    @AppStorage("badge") private var badge = Badge.off
    @State private var welcoming = Store.shared.needsWelcome
    #if DEBUG
    @State private var gallery = UserDefaults.standard.object(forKey: "gallery") != nil
    #endif

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "checklist", value: .today) { TodayView() }
            Tab("Plan", systemImage: "list.number", value: .plan) { PlanView() }
            Tab("Study", systemImage: "book.closed", value: .study) { StudyView() }
            Tab("More", systemImage: "ellipsis", value: .more) { MoreView() }
        }
        .minimizingTabBar()
        .lookTint()
        // The first launch writes the first plan, then opens Today on its A1.
        .fullScreenCover(isPresented: $welcoming) {
            WelcomeView { tab = .today }.lookTint()
        }
        .fullScreenCover(isPresented: Binding(get: { store.planningTomorrow }, set: { store.planningTomorrow = $0 })) {
            PlanTomorrow().lookTint()
        }
        // A focus session covers everything until Mark done or Stop.
        .fullScreenCover(isPresented: Binding(get: { store.focus != nil }, set: { _ in })) {
            FocusView().lookTint()
        }
        #if DEBUG
        // `-gallery YES` on launch shows every widget at its real size (screenshots).
        .fullScreenCover(isPresented: $gallery) { WidgetGallery() }
        #endif
        .onOpenURL { url in
            // willist://today and willist://add come from the widgets; anything else is a file
            // shared to WilList.
            guard url.scheme == "willist" else {
                store.incomingFile = url
                tab = .plan
                return
            }
            if url.host() == "add" { store.quickAction = .add } else { tab = .today }
        }
        .onChange(of: phase, initial: true) {
            guard phase == .active else { return }
            store.reload()
            store.refreshDay()
            Task { await store.syncFeeds() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in store.refreshDay() }
        #if DEBUG
        // `-show <title>` on launch opens that to-do or item, `-focus YES` starts a focus session on
        // the A1 (`-focusSpent 30` with 30 minutes already spent), `-evening 1|2|3` opens Plan
        // tomorrow at that step (screenshots).
        .onAppear {
            store.planningTomorrow = UserDefaults.standard.integer(forKey: "evening") > 0
            if UserDefaults.standard.bool(forKey: "focus"), store.focus == nil, let a1 = doRows(store.state.items, store.today).first {
                store.startFocus(a1)
                store.focus?.banked = UserDefaults.standard.double(forKey: "focusSpent") * 60
            }
            guard let t = UserDefaults.standard.string(forKey: "show") else { return }
            store.opening = store.state.items.first { $0.title.hasPrefix(t) }?.id ?? store.state.todos.first { $0.title.hasPrefix(t) }?.id
        }
        #endif
        // A tapped reminder or search result opens its to-do in Today, or its item in Plan.
        .onChange(of: store.opening) {
            if let id = store.opening { tab = store.state.todos.contains { $0.id == id } ? .today : .plan }
        }
        .onChange(of: store.quickAction) { if store.quickAction != nil { tab = .today } }
        .task(id: badge.count(store.state, today: store.today)) {
            try? await UNUserNotificationCenter.current().setBadgeCount(badge.count(store.state, today: store.today))
        }
        .task(id: Reminders.due(store.state, today: store.today)) {
            await Reminders.sync(Reminders.due(store.state, today: store.today))
        }
        .task(id: store.state.settings) {
            if await !Reminders.update(store.state.settings) {
                store.change { $0.settings.notify = false }
                store.say("Notifications are off for WilList. Turn them on in the Settings app.")
            }
        }
    }
}

/// Carries out the home-screen quick actions ("New to-do", "Search").
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        Self.perform(shortcutItem)
        return true
    }

    static func perform(_ item: UIApplicationShortcutItem) {
        Store.shared.quickAction = Store.QuickAction(rawValue: item.type.components(separatedBy: ".").last ?? "")
    }
}
