import ActivityKit
import SwiftUI
import UserNotifications
import WilListCore

/// Focus: one task, one timer, nothing else. The ring fills as the planned minutes pass, then it
/// says to take a break. The same timer runs on the Lock Screen and in the Dynamic Island.
struct FocusView: View {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let f = store.focus {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                page(f, left: f.remaining(at: context.date))
            }
            // The timer stays on screen on a desk.
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private func page(_ f: FocusSession, left: TimeInterval) -> some View {
        let over = left == 0
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { store.finishFocus(done: false) } label: { Text("Stop").tapArea() }
            }
            .font(.body.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            // The middle spreads out when it fits; at the largest text sizes it scrolls instead, so
            // no words are cut off and Stop stays clear of the status bar.
            ViewThatFits(in: .vertical) {
                middle(f, left: left, over: over).frame(maxHeight: .infinity)
                ScrollView { middle(f, left: left, over: over) }
            }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                if !over {
                    Button { f.paused ? store.resumeFocus() : store.pauseFocus() } label: {
                        Label(f.paused ? "Resume" : "Pause", systemImage: f.paused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button { store.finishFocus(done: true) } label: {
                    Label("Mark done", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("focusDone")
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .sensoryFeedback(.success, trigger: over) { was, now in !was && now }
        .onChange(of: over) { _, now in if now { Chime.play() } }
    }

    /// The letter and title, the ring, and a line under it.
    private func middle(_ f: FocusSession, left: TimeInterval, over: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                LetterMark(letter: Letter(rawValue: String(f.label.prefix(1))), label: f.label, large: true)
                Text(f.title)
                    .font(.title.bold())
                    .fontDesign(Look.current.titles)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 24)
            ring(f, left: left)
            Text(over ? "Take a 5 to 10 minute break." : f.paused ? "Paused" : "One thing. Stay with it until it's done.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func ring(_ f: FocusSession, left: TimeInterval) -> some View {
        let progress = 1 - left / f.total
        return ZStack {
            Circle().stroke(Color.brand.opacity(0.12), lineWidth: 16)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.brand, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            Text(left == 0 ? "Break" : Self.clock(left))
                .font(.system(size: 60, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(f.paused ? Color.secondary : Color.primary)
        }
        .frame(width: 260, height: 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(left == 0 ? "Time for a break" : "\(Fmt.minutes(Int((left / 60).rounded(.up)))) left\(f.paused ? ", paused" : "")")
    }

    /// 42:07
    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

extension Store {
    /// Starts a focus session on a row: the timer screen, a Live Activity, and a notice when the
    /// planned minutes are up. A study session's own length, or the usual task length.
    func startFocus(_ row: Row) {
        let f = FocusSession(key: row.key, itemId: row.item.id, type: row.item.type, title: row.item.title,
                             label: row.label, minutes: row.session?.minutes ?? state.settings.taskMin)
        keepFocus(f)
        LiveFocus.start(f)
    }

    func pauseFocus() {
        guard var f = focus, let since = f.since else { return }
        f.banked += Date.now.timeIntervalSince(since)
        f.since = nil
        keepFocus(f)
        LiveFocus.update(f)
    }

    func resumeFocus() {
        guard var f = focus, f.paused else { return }
        f.since = .now
        keepFocus(f)
        LiveFocus.update(f)
    }

    /// Ends the session and keeps its real minutes, as the website does; Done also ticks the row
    /// off. Mark done on the Live Activity comes here too, maybe with the app in the background.
    func finishFocus(done: Bool) {
        guard let f = focus else { LiveFocus.end(); return }
        reload() // a widget may have changed the plan meanwhile
        let today = today
        change(undo: done ? "Marked \u{201C}\(f.title)\u{201D} done" : nil) { s in
            if done, let row = dayRows(s.items, today, realToday: today).first(where: { $0.key == f.key }) {
                s.complete(row, today: today)
            }
            s.logFocus(itemId: f.itemId, type: f.type, title: f.title, minutes: f.elapsed() / 60, planned: f.minutes,
                       completed: done, today: today)
        }
        keepFocus(nil)
        LiveFocus.end()
    }

    private func keepFocus(_ f: FocusSession?) {
        focus = f
        FocusSession.saved = f
        FocusNotice.schedule(f)
    }
}

/// The Live Activity for a focus session: start, update on pause and resume, end.
enum LiveFocus {
    static func start(_ f: FocusSession) {
        end() // one at a time
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: FocusAttributes(title: f.title, label: f.label, minutes: f.minutes),
                                  content: content(f))
    }

    static func update(_ f: FocusSession) {
        let content = content(f)
        Task { for a in Activity<FocusAttributes>.activities { await a.update(content) } }
    }

    /// Stale at the end of the planned minutes, which is when its face says Break, with no
    /// update needed from the app.
    private static func content(_ f: FocusSession) -> ActivityContent<FocusAttributes.ContentState> {
        ActivityContent(state: FocusAttributes.state(f), staleDate: f.end)
    }

    /// Ends the ones running now, and not one requested after this call while it is still busy.
    static func end() {
        let now = Set(Activity<FocusAttributes>.activities.map(\.id))
        Task { for a in Activity<FocusAttributes>.activities where now.contains(a.id) { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}

/// The notice when the planned minutes are up, for when WilList isn't on screen.
enum FocusNotice {
    nonisolated static let id = "focus-end"

    static func schedule(_ f: FocusSession?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let f, let end = f.end, end > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time for a break"
        content.body = "\(Fmt.minutes(f.minutes)) on \u{201C}\(f.title)\u{201D}. Take 5 to 10 minutes, then come back to it."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
