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
    // Screen titles in bold, like the date on Today. Large titles are only on the tabs, so they
    // are white on the tabs' slate ground; sheets' titles stay small and dark on their light ground.
    // Set once the app has launched: touching UIKit appearance any earlier (in App.init) loses the
    // accent colour.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Self.titleFont(.largeTitle), .foregroundColor: UIColor.white]
        bar.titleTextAttributes = [.font: Self.titleFont(.headline)]
        UNUserNotificationCenter.current().delegate = self
        // Mark done on the focus Live Activity runs here, with the app in the background if need be.
        Focus.finish = { done in Store.shared.finishFocus(done: done) }
        if Store.shared.focus == nil { LiveFocus.end() }
        // iCloud wakes the app when another device changed the plan.
        CloudSync.shared.start()
        application.registerForRemoteNotifications()
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
        let base = UIFont.preferredFont(forTextStyle: style).fontDescriptor
        return UIFont(descriptor: base.withSymbolicTraits(.traitBold) ?? base, size: 0)
    }
}

enum AppTab: String, Hashable, CaseIterable {
    case today, plan, study, more

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .today: "checklist"
        case .plan: "list.number"
        case .study: "book.closed"
        case .more: "ellipsis"
        }
    }
}

/// The four tabs on a solid white capsule. The system's glass tab bar takes on the colour of
/// whatever is behind it (the slate, a card), turns it when pressed and can't be made solid on
/// iOS 26, so WilList draws its own; the system's stays hidden (`underTabBar()`).
struct TabBar: View {
    /// How much room a tab's content leaves for the bar.
    static let room: CGFloat = 76
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { item in
                let on = item == tab
                Button { tab = item } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 24)
                        Text(item.title).font(.caption2.weight(.semibold))
                    }
                    // The deeper teal on its pale pill: the teal itself reads at only 4.4:1 there.
                    .foregroundStyle(on ? Color.brandDeep : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.brand.opacity(on ? 0.12 : 0), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("tab-\(item.rawValue)")
            }
        }
        .padding(5)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .frame(maxWidth: 440)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: tab)
    }
}

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
            Tab("Today", systemImage: "checklist", value: .today) { TodayView().underTabBar() }
            Tab("Plan", systemImage: "list.number", value: .plan) { PlanView().underTabBar() }
            Tab("Study", systemImage: "book.closed", value: .study) { StudyView().underTabBar() }
            Tab("More", systemImage: "ellipsis", value: .more) { MoreView().underTabBar() }
        }
        // The keyboard covers the bar rather than lifting it.
        .overlay(alignment: .bottom) { TabBar(tab: $tab).ignoresSafeArea(.keyboard) }
        // The accent colour is the teal already; tinting with it too turns the toolbar buttons teal.
        .tint(.brand)
        // The first launch writes the first plan, then opens Today on its A1.
        .fullScreenCover(isPresented: $welcoming) {
            WelcomeView { tab = .today }.tint(.brand)
        }
        .fullScreenCover(isPresented: Binding(get: { store.planningTomorrow }, set: { store.planningTomorrow = $0 })) {
            PlanTomorrow().tint(.brand)
        }
        // A focus session covers everything until Mark done or Stop.
        .fullScreenCover(isPresented: Binding(get: { store.focus != nil }, set: { _ in })) {
            FocusView().tint(.brand)
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
                store.say("Turn on notifications for WilList in Settings.")
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
