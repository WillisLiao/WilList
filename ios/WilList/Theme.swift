import AudioToolbox
import SwiftUI
import WilListCore

// The app's shared pieces: letter menus, the check-off and its chime, toasts and the A1 card.
// Letter marks and wording live in ios/Shared, which the widgets use too.

/// The letters to choose from, each with its meaning. Used in menus and context menus.
struct LetterChoices: View {
    let suggested: Letter?
    var allowNone = false
    let choose: (Letter?) -> Void

    var body: some View {
        ForEach(Letter.allCases, id: \.self) { l in
            Button { choose(l) } label: {
                Text("\(l.rawValue)  \(l.name)\(l == suggested ? " (suggested)" : "")")
                Text(l.detail)
            }
        }
        if allowNone {
            Divider()
            Button("No letter") { choose(nil) }
        }
    }
}

/// The short chime for finishing something, unless it's turned off in More. It follows the
/// ring/silent switch, as system sounds do.
enum Chime {
    private static let sound: SystemSoundID? = {
        guard let url = Bundle.main.url(forResource: "done", withExtension: "wav") else { return nil }
        var id: SystemSoundID = 0
        return AudioServicesCreateSystemSoundID(url as CFURL, &id) == noErr ? id : nil
    }()

    static func play() {
        guard UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true, let sound else { return }
        AudioServicesPlaySystemSound(sound)
    }
}

/// The round check-off. Filling it plays a success tap.
struct CheckButton: View {
    let done: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                if !reduceMotion { TickBurst(done: done) }
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? Color.brand : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: done)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(trigger: done) { old, new in !old && new ? .success : nil }
        .accessibilityLabel(done ? "Done" : "Mark done")
    }
}

/// A ring and six sparks thrown off the box as it fills, gone before the row moves away. Drawn
/// larger when the card says the day's A's are done.
struct TickBurst: View {
    let done: Bool

    private struct Frame {
        var spread = 0.0
        var opacity = 0.0
    }

    var body: some View {
        KeyframeAnimator(initialValue: Frame(), trigger: done) { f in
            ZStack {
                Circle()
                    .stroke(Color.brand, lineWidth: 2 * (1 - f.spread) + 0.5)
                    .frame(width: 24 + 16 * f.spread, height: 24 + 16 * f.spread)
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 4 - 1.5 * f.spread, height: 4 - 1.5 * f.spread)
                        .offset(y: -(13 + 14 * f.spread))
                        .rotationEffect(.degrees(Double(i) * 60 + 30))
                }
            }
            // Unticking plays it too, unseen.
            .opacity(done ? f.opacity : 0)
        } keyframes: { _ in
            // MoveKeyframe starts each burst from the box; a zero-length keyframe before a spring is NaN.
            KeyframeTrack(\.spread) {
                MoveKeyframe(0)
                SpringKeyframe(1, duration: 0.42, spring: .snappy)
            }
            KeyframeTrack(\.opacity) {
                MoveKeyframe(1)
                LinearKeyframe(1, duration: 0.16)
                CubicKeyframe(0, duration: 0.28)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// The parts of Fmt that need the app's reminders.
extension Fmt {
    /// A reminder as people say it: "Today, 6:00 PM", "Fri, 9:00 AM".
    static func reminder(_ at: String?, _ today: Day) -> String? {
        guard let c = Reminders.remind(at), let d = Calendar.current.date(from: c) else { return nil }
        let dayPart = day(WilListCore.today(d), today)
        return "\(dayPart), \(d.formatted(date: .omitted, time: .shortened))"
    }

    /// Small marks for what a task has: "1 of 3" steps, a bell for a reminder to come, a sun when on Today.
    static func marks(_ steps: [Step], remind: String?, today onToday: Bool) -> [Text?] {
        let upcoming = Reminders.remind(remind).flatMap { Calendar.current.date(from: $0) }.map { $0 > .now } ?? false
        return [
            steps.isEmpty ? nil : Text("\(steps.filter(\.done).count) of \(steps.count)").foregroundStyle(Color.secondary),
            upcoming ? Text(Image(systemName: "bell")).foregroundStyle(Color.secondary) : nil,
            onToday ? Text(Image(systemName: "sun.max")).foregroundStyle(Color.secondary) : nil,
        ]
    }
}

extension EnvironmentValues {
    /// The room a tab's screen leaves at the bottom for WilList's own tab bar (`TabBar`).
    @Entry var tabBarRoom: CGFloat = 0
}

/// Shows the store's short messages ("Deleted…  Undo") above the tab bar.
struct ToastHost: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.tabBarRoom) private var tabBarRoom

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                // The toast's animation stays with the toast. On the whole screen it animated everything
                // that changed with it, and the list crossfaded Today's A1 card when Mark done said so.
                ZStack {
                    if let toast = store.toast {
                        HStack(spacing: 16) {
                            Text(toast.text).lineLimit(2)
                            Spacer(minLength: 0)
                            if toast.canUndo {
                                // Animated, unless it brings back another A1: the list would resize the A1's
                                // row slowly behind words already in place. The card brings its A in itself.
                                Button("Undo") { withAnimation(store.undoChangesA1 ? nil : .default) { store.undo() } }.bold()
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(minHeight: 50)
                        .floating()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: toast.id) {
                            // With VoiceOver, Undo stays until it's reached, however long that takes.
                            guard !(toast.canUndo && voiceOver) else { return }
                            try? await Task.sleep(for: toast.shownFor)
                            if store.toast?.id == toast.id { withAnimation { store.toast = nil } }
                        }
                    }
                }
                .animation(.snappy, value: store.toast)
                // Clear of the tab bar drawn over the screen, for the toast and the list's last rows.
                // Here, inside the screen's navigation stack: an inset outside it doesn't reach the list.
                Color.clear.frame(height: tabBarRoom)
            }
        }
    }
}

struct ReadableColumn: ViewModifier {
    @State private var width: CGFloat = 0
    /// nil on a phone: the system's own margins, which keep a grouped list's cards inset.
    private var margin: CGFloat? { width > 700 ? (width - 700) / 2 : nil }

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, margin, for: .scrollContent)
            .toolbarTitleDisplayMode(margin == nil ? .automatic : .inline)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// Cards scrolled under a tab's title are hidden behind a solid edge, not blurred under it.
struct HardTopEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) { content.scrollEdgeEffectStyle(.hard, for: .top) } else { content }
    }
}

/// The A1 card's ground: a pale wash of its colour (the teal, or the night for the evening's
/// question) on white, paler still for an empty card, so it floats on the ground like the A1 widget.
struct HeroCard: ViewModifier {
    var color: Color = .brand
    var empty = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .padding(18)
            .background(color.opacity(empty ? 0.06 : 0.09), in: shape)
            .background(Color.white, in: shape)
    }
}

/// A big button's icon and words; at the largest text sizes only the words, which the icon and
/// the round ends would otherwise squeeze until a word breaks.
struct WordsWhenLarge: LabelStyle {
    @Environment(\.dynamicTypeSize) private var typeSize

    func makeBody(configuration: Configuration) -> some View {
        if typeSize.isAccessibilitySize { configuration.title } else { Label(configuration) }
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }

    /// A tab's cards on the slate ground (`LinearGradient.ground`), as the widgets sit on a Home Screen.
    /// `barless` for a screen without a navigation bar (Today): nothing scrolls under the clock.
    func ground(barless: Bool = false) -> some View {
        scrollContentBackground(.hidden)
            .mask {
                VStack(spacing: 0) {
                    // A short fade, so a card slides away under the clock rather than being cut.
                    if barless { LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 10) }
                    Rectangle()
                }
                .ignoresSafeArea(edges: barless ? .bottom : .all)
            }
            .background(LinearGradient.ground)
            .modifier(HardTopEdge())
    }

    /// A sheet's cards on its light ground (`Color.sheet`).
    func sheetGround() -> some View { scrollContentBackground(.hidden).background(Color.sheet) }

    /// The second button on a field of colour (Focus, Plan tomorrow's last page): a white outline
    /// and no wash, so its white words keep the field's own contrast; on the system's white wash
    /// they fell to 3.9:1.
    func outlinedOnField() -> some View {
        buttonStyle(.bordered)
            .tint(.clear)
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
    }

    /// Words straight on a tab's slate ground (a section's title, its footer): white, as words on
    /// a field of colour always are.
    func onGround() -> some View { foregroundStyle(.white) }

    func heroCard(_ color: Color = .brand, empty: Bool = false) -> some View { modifier(HeroCard(color: color, empty: empty)) }

    /// On a wide screen (iPad), a list keeps to a readable column in the middle, and its title
    /// moves up beside the tabs, out of the column's way.
    func readableColumn() -> some View { modifier(ReadableColumn()) }

    /// A bare button's label answers taps across at least 44 by 44 points. Put it inside the label:
    /// a frame outside a button looks the same but doesn't widen what it answers to.
    func tapArea() -> some View { frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }

    /// A menu's label in a form row answers a tap anywhere on the row, not only on its words.
    func fillsRow() -> some View { frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }

    /// Liquid Glass on iOS 26 and later; the system material before that.
    @ViewBuilder func floating() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: .capsule)
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }

    /// A tab's screen under WilList's own white tab bar (`TabBar`): the system's glass one is
    /// hidden, and the screen's toast host leaves room for ours.
    func underTabBar() -> some View {
        toolbar(.hidden, for: .tabBar).environment(\.tabBarRoom, TabBar.room)
    }
}
