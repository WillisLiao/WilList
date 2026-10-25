import ActivityKit
import SwiftUI
import UserNotifications
import WilListCore

/// Focus: one task, one timer, nothing else, on a field of its course's colour. The time spent
/// rises from the bottom in a deeper shade, like a glass filling, and reaches the top when the
/// planned minutes are up; then it says to take a break. The same timer runs on the Lock Screen
/// and in the Dynamic Island.
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
        let field = CourseColor.of(store.state.courseColor(store.state.items.first { $0.id == f.itemId }?.course))
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { store.finishFocus(done: false) } label: { Text("Stop").tapArea() }
                    .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .outlinedOnField()
                }
                Button { store.finishFocus(done: true) } label: {
                    Label("Mark done", systemImage: "checkmark")
                        .foregroundStyle(field)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("focusDone")
            }
            .controlSize(.large)
            .labelStyle(WordsWhenTight())
            .tint(.white)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity)
        .background { tide(field, progress: 1 - left / f.total) }
        .environment(\.field, field)
        .sensoryFeedback(.success, trigger: over) { was, now in !was && now }
        .onChange(of: over) { _, now in if now { Chime.play() } }
    }

    /// The letter and title, the ring, and a line under it.
    private func middle(_ f: FocusSession, left: TimeInterval, over: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            VStack(spacing: 12) {
                if let letter = Letter(rawValue: String(f.label.prefix(1))) {
                    LetterMark(letter: letter, label: f.label, large: true, onBrand: true)
                }
                Text(Fmt.noWidow(f.title))
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 24)
            Spacer(minLength: 24)
            clock(f, left: left)
            Text(over ? "Take 5 to 10 minutes." : f.paused ? "Paused" : "One thing until it’s done.")
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }

    /// The time left, large, in a thin ring of the time spent that closes when the minutes are up.
    private func clock(_ f: FocusSession, left: TimeInterval) -> some View {
        let spent = min(max(1 - left / f.total, 0), 1)
        return Text(left == 0 ? "Break" : Self.clock(left))
            .font(.system(size: 76, weight: .bold))
            .monospacedDigit()
            .tracking(-1)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(left == 0 ? "Time for a break" : "\(Fmt.minutes(Int((left / 60).rounded(.up)))) left\(f.paused ? ", paused" : "")")
            // Clear of the ring, which is at most 300 points across and narrower on a narrow screen.
            .padding(.horizontal, 36)
            .frame(maxWidth: 300, maxHeight: 300)
            .aspectRatio(1, contentMode: .fit)
            .background {
                ZStack {
                    Circle().stroke(.white.opacity(0.3), lineWidth: 8)
                    Circle().trim(from: 0, to: spent)
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 1), value: spent)
                }
                .padding(4)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
    }

    /// The field, and the time spent rising up it in a deeper shade of the same colour.
    private func tide(_ field: Color, progress: Double) -> some View {
        GeometryReader { geo in
            field.mix(with: .black, by: 0.24)
                .frame(height: geo.size.height * min(max(progress, 0), 1))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
        }
        .background(field)
        .ignoresSafeArea()
    }

    /// 42:07
    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

extension Store {
    /// Starts a focus session on a row: the timer screen, a Live Activity, and a notice when the
    /// minutes are up. The minutes chosen, or the usual task length.
    func startFocus(_ row: Row, minutes: Int? = nil) {
        begin(FocusSession(key: row.key, itemId: row.item.id, type: row.item.type, title: row.item.title,
                           label: row.label, minutes: minutes ?? state.settings.taskMin),
              course: row.item.course)
    }

    /// A focus session on an item off the day's list, or a study block.
    func startFocus(_ item: Item, minutes: Int) {
        begin(FocusSession(key: item.id, itemId: item.id, type: item.type, title: item.title,
                           label: item.priority?.rawValue ?? "", minutes: minutes), course: item.course)
    }

    /// A focus session on a to-do.
    func startFocus(_ todo: Todo, minutes: Int) {
        begin(FocusSession(key: todo.id, itemId: todo.id, type: .task, title: todo.title, label: "", minutes: minutes), course: nil)
    }

    private func begin(_ f: FocusSession, course: String?) {
        keepFocus(f)
        LiveFocus.start(f, color: state.courseColor(course))
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

    /// Ends the session and keeps its real minutes, as the website does; Done also ticks it off: the
    /// day's row, the to-do, or the item. Mark done on the Live Activity comes here too, maybe with
    /// the app in the background.
    func finishFocus(done: Bool) {
        guard let f = focus else { LiveFocus.end(); return }
        reload() // a widget may have changed the plan meanwhile
        let today = today
        change(undo: done ? "\u{201C}\(f.title)\u{201D} done" : nil) { s in
            if done {
                if let row = dayRows(s.items, today, realToday: today).first(where: { $0.key == f.key }) {
                    s.complete(row, today: today)
                } else if let t = s.todos.first(where: { $0.id == f.itemId }) {
                    if !t.done { s.toggleTodo(t.id, today: today) }
                } else if s.index(of: f.itemId) != nil {
                    s.completeLater(f.itemId, today: today)
                }
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

/// The Live Activity for a focus session: start, update on pause and resume, end. A Mac has none:
/// the session runs on the Focus screen alone.
enum LiveFocus {
    #if targetEnvironment(macCatalyst)
    static func start(_ f: FocusSession, color: Int?) {}
    static func update(_ f: FocusSession) {}
    static func end() {}
    #else
    static func start(_ f: FocusSession, color: Int?) {
        end() // one at a time
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        _ = try? Activity.request(attributes: FocusAttributes(title: f.title, label: f.label, minutes: f.minutes, color: color),
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
    #endif
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
