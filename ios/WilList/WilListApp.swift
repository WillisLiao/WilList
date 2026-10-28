import Security
import SwiftUI
import UserNotifications
import WilListCore

@main
struct WilListApp: App {
    @State private var store = Store.shared
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(Account.shared)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Screen titles in bold, like the date on Today. Large titles are only on the tabs, in the
    // ground's deep ink; sheets' titles stay small and dark on their light ground.
    // Set once the app has launched: touching UIKit appearance any earlier (in App.init) loses the
    // accent colour.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Self.titleFont(.largeTitle), .foregroundColor: UIColor(Color.groundInk)]
        bar.titleTextAttributes = [.font: Self.titleFont(.headline)]
        UNUserNotificationCenter.current().delegate = self
        // The Claude key students once typed into More is no longer used: the Agent runs on
        // WilList's own server. Leave no secret behind.
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "anthropic-api-key"] as CFDictionary)
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
        let base = UIFont.preferredFont(forTextStyle: style).fontDescriptor
        return UIFont(descriptor: base.withSymbolicTraits(.traitBold) ?? base, size: 0)
    }
}

enum AppTab: String, Hashable, CaseIterable {
    case today, plan, progress, goals, agent

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .today: "checklist"
        case .plan: "list.number"
        case .progress: "chart.bar.xaxis"
        case .goals: "target"
        case .agent: "sparkles"
        }
    }
}

/// The five tabs on a solid white capsule. The system's glass tab bar takes on the colour of
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
                            // The tab you are in is circled by hand, as the A1 is: the same pen
                            // saying "this one". It replaces the pale pill that said it before.
                            // Wide enough to go round the widest symbol, not through it.
                            .frame(width: 42, height: 32)
                            .overlay {
                                if on {
                                    SketchCircle()
                                        .stroke(Color.brandDeep, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                                }
                            }
                        Text(item.title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    // The deeper teal: the teal itself reads at only 4.4:1 on a pale ground.
                    .foregroundStyle(on ? Color.brandDeep : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 52)
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
    @State private var keyboardUp = false
    #if DEBUG
    @State private var gallery = UserDefaults.standard.object(forKey: "gallery") != nil
    #endif

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "checklist", value: .today) { TodayView().underTabBar() }
            Tab("Plan", systemImage: "list.number", value: .plan) { PlanView().underTabBar() }
            Tab("Progress", systemImage: "chart.bar.xaxis", value: .progress) { ProgressTab().underTabBar() }
            Tab("Goals", systemImage: "target", value: .goals) { NavigationStack { GoalsList() }.underTabBar() }
            Tab("Agent", systemImage: "sparkles", value: .agent) { AgentView().underTabBar() }
        }
        // The keyboard covers the bar rather than lifting it: `ignoresSafeArea(.keyboard)` alone
        // let the bar ride on the keyboard over Today's add line, so it goes while the keyboard is up
        // (a bottom safe area over 150 points, pitfall 29).
        .overlay(alignment: .bottom) { if !keyboardUp { TabBar(tab: $tab).ignoresSafeArea(.keyboard) } }
        .onGeometryChange(for: Bool.self) { $0.safeAreaInsets.bottom > 150 } action: { keyboardUp = $0 }
        // The accent colour is the teal already; tinting with it too turns the toolbar buttons teal.
        .tint(.brand)
        .sheet(isPresented: Binding(get: { store.showingSettings }, set: { store.showingSettings = $0 })) {
            SettingsView().tint(.brand)
        }
        .fullScreenCover(isPresented: Binding(get: { store.planningTomorrow }, set: { store.planningTomorrow = $0 })) {
            PlanTomorrow().tint(.brand)
        }
        // A focus session covers everything until it is lowered with the chevron or closed at Break.
        .fullScreenCover(isPresented: Binding(get: { store.focus != nil && store.focusOpen }, set: { _ in })) {
            FocusView().tint(.brand)
        }
        #if DEBUG
        // `-gallery YES` on launch shows every widget at its real size (screenshots).
        .fullScreenCover(isPresented: $gallery) { WidgetGallery() }
        #endif
        .onOpenURL { url in
            // willist://today and willist://add come from the widgets; anything else is a file
            // shared to WilList, for the Agent to read.
            guard url.scheme == "willist" else {
                store.incomingFile = url
                tab = .agent
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
        // tomorrow at that step, `-open settings` opens Settings (screenshots).
        .onAppear {
            store.planningTomorrow = UserDefaults.standard.integer(forKey: "evening") > 0
            store.showingSettings = UserDefaults.standard.string(forKey: "open") != nil
            if UserDefaults.standard.bool(forKey: "focus"), store.focus == nil, let a1 = doRows(store.state.items, store.today).first {
                store.startFocus(a1)
                store.focus?.banked = UserDefaults.standard.double(forKey: "focusSpent") * 60
            }
            if let t = UserDefaults.standard.string(forKey: "show") {
                store.opening = store.state.items.first { $0.title.hasPrefix(t) }?.id ?? store.state.todos.first { $0.title.hasPrefix(t) }?.id
            }
        }
        // `-snapshot <path>`: the window as a PNG four seconds in, for the Mac app, whose window
        // can't be captured from outside without screen recording access.
        .task {
            guard let path = UserDefaults.standard.string(forKey: "snapshot") else { return }
            try? await Task.sleep(for: .seconds(4))
            guard let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try? image.pngData()?.write(to: URL(filePath: path))
        }
        #endif
        // A tapped reminder or search result opens its to-do in Today, or its item in Plan.
        .onChange(of: store.opening) {
            if let id = store.opening { tab = store.state.todos.contains { $0.id == id } ? .today : .plan }
        }
        .onChange(of: store.quickAction) { if store.quickAction != nil { tab = .today } }
        // Subscription changes (a renewal, a refund) can arrive at any time.
        .task { await AgentPass.shared.watch() }
        .task { await Account.shared.check() }
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
