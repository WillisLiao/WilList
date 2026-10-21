import AudioToolbox
import SwiftUI
import WilListCore

// Shared pieces: how letters, check-offs, dates and kinds of item look and read everywhere.

/// A letter mark. Letters differ by intensity, not by hue: A is the one filled in the accent,
/// B is outlined in ink, C is grey, D is dashed (someone else does it) and E is struck out.
struct LetterMark: View {
    let letter: Letter?
    var label: String?
    var large = false
    /// On a card filled with the brand colour, the A turns white with a green letter.
    var onBrand = false

    var body: some View {
        let text = label ?? letter?.rawValue ?? "–"
        Text(text)
            .font(large ? .headline : .footnote.weight(.semibold))
            .monospacedDigit()
            .strikethrough(letter == .E)
            .foregroundStyle(ink)
            .padding(.horizontal, text.count > 1 ? 6 : 0)
            .frame(minWidth: large ? 40 : 30, minHeight: large ? 32 : 26)
            .background(letter == .A ? (onBrand ? Color.white : Color.brand) : Color.clear, in: Capsule())
            .overlay {
                if letter != .A {
                    Capsule().strokeBorder(stroke, style: StrokeStyle(lineWidth: 1.25, dash: letter == .D || letter == nil ? [3, 2] : []))
                }
            }
            .accessibilityLabel(letter.map { "Priority \(label ?? $0.rawValue)" } ?? "No letter")
    }

    // Fixed colours, not hierarchical styles: inside a button those pick up the tint, and the
    // letters must read the same everywhere.
    private var ink: Color {
        switch letter {
        case .A: onBrand ? .brand : .white
        case .B: .primary
        default: .secondary
        }
    }

    private var stroke: Color { letter == .B ? .primary : Color(.tertiaryLabel) }
}

extension Letter {
    /// Tracy's name for each letter.
    var name: String {
        switch self {
        case .A: "Must do"
        case .B: "Should do"
        case .C: "Nice to do"
        case .D: "Delegate"
        case .E: "Eliminate"
        }
    }

    /// What the letter means, in plain words.
    var detail: String {
        switch self {
        case .A: "Serious consequences if it's not done"
        case .B: "Mild consequences"
        case .C: "No consequences either way"
        case .D: "Someone else can do it"
        case .E: "Drop it"
        }
    }

    var meaning: String { "\(name): \(detail.prefix(1).lowercased())\(detail.dropFirst())." }
}

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

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? Look.current.box.done : Look.current.box.empty)
                .font(.title2)
                .foregroundStyle(done ? Color.brand : Color(.tertiaryLabel))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: done)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(trigger: done) { old, new in !old && new ? .success : nil }
        .accessibilityLabel(done ? "Done" : "Mark done")
    }
}

extension ItemType {
    var name: String {
        switch self {
        case .task: "Task"
        case .deadline: "Deadline"
        case .exam: "Exam or test"
        case .presentation: "Presentation"
        case .reading: "Reading"
        case .event: "Class or event"
        }
    }
}

enum Fmt {
    static func date(_ d: Day) -> Date {
        let p = d.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return .now }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? .now
    }

    /// "Today", "Tomorrow", "Fri" within the week, otherwise "24 Oct" in the device's order.
    static func day(_ d: Day, _ today: Day, inSentence: Bool = false) -> String {
        let s: String = switch diffDays(today, d) {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        case 2...6: date(d).formatted(.dateTime.weekday(.abbreviated))
        default: date(d).formatted(.dateTime.month(.abbreviated).day())
        }
        return inSentence && ["Today", "Tomorrow", "Yesterday"].contains(s) ? s.lowercased() : s
    }

    static func long(_ d: Day) -> String { date(d).formatted(.dateTime.weekday(.wide).day().month(.wide)) }

    static func time(_ hhmm: String?) -> String? {
        guard let m = timeToMin(hhmm), let d = Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: .now) else { return nil }
        return d.formatted(date: .omitted, time: .shortened)
    }

    static func minutes(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        let (h, r) = (m / 60, m % 60)
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    static func recur(_ r: Recur) -> String {
        let names = Calendar.current.shortWeekdaySymbols
        let days = (r.days ?? []).sorted().map { names[$0] }.joined(separator: ", ")
        let n = r.every
        return switch r.freq {
        case .daily: n == 1 ? "Every day" : "Every \(n) days"
        case .weekdays: "Every weekday"
        case .weekly, .biweekly:
            n == 1 ? (days.isEmpty ? "Every week" : "Every \(days)")
            : n == 2 && !days.isEmpty ? "Every other \(days)"
            : "Every \(n) weeks" + (days.isEmpty ? "" : " on \(days)")
        case .monthly: n == 1 ? "Every month" : "Every \(n) months"
        case .yearly: n == 1 ? "Every year" : "Every \(n) years"
        }
    }

    /// When an item happens, worded for its kind: "Exam Fri, 9:00 AM", "Due tomorrow".
    static func when(_ it: Item, _ today: Day) -> String? {
        if let r = it.recur { return [recur(r), time(it.time)].compactMap { $0 }.joined(separator: ", ") }
        guard let d = it.date else { return nil }
        let at = [day(d, today, inSentence: true), time(it.time)].compactMap { $0 }.joined(separator: ", ")
        return switch it.type {
        case .exam: "Exam \(at)"
        case .deadline: "Due \(at)"
        case .presentation: "Presenting \(at)"
        case .reading: "Read by \(at)"
        case .task, .event: day(d, today) + (time(it.time).map { ", \($0)" } ?? "")
        }
    }

    /// A to-do's due date: "Due today", "Due Fri, 6:00 PM", "Overdue, Mon".
    static func dueLine(_ date: Day?, _ time: String?, _ today: Day) -> String? {
        guard let date else { return nil }
        let at = [day(date, today, inSentence: true), time.flatMap { self.time($0) }].compactMap { $0 }.joined(separator: ", ")
        return diffDays(today, date) < 0 ? "Overdue, \(at)" : "Due \(at)"
    }

    /// A reminder as people say it: "Today, 6:00 PM", "Fri, 9:00 AM".
    static func reminder(_ at: String?, _ today: Day) -> String? {
        guard let c = Reminders.remind(at), let d = Calendar.current.date(from: c) else { return nil }
        let dayPart = day(WilListCore.today(d), today)
        return "\(dayPart), \(d.formatted(date: .omitted, time: .shortened))"
    }

    /// Parts of a line under a title, spaced apart; nil when there are none.
    static func meta(_ parts: [Text?]) -> Text? {
        let parts = parts.compactMap { $0 }
        guard var line = parts.first else { return nil }
        for p in parts.dropFirst() { line = Text("\(line)   \(p)") }
        return line
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

    /// The grey line under an item's title.
    static func subline(_ it: Item, _ today: Day) -> String {
        [when(it, today), it.course].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Shows the store's short messages ("Deleted…  Undo") above the tab bar.
struct ToastHost: ViewModifier {
    @Environment(Store.self) private var store

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let toast = store.toast {
                HStack(spacing: 16) {
                    Text(toast.text).lineLimit(2)
                    Spacer(minLength: 0)
                    if toast.canUndo {
                        Button("Undo") { withAnimation { store.undo() } }.bold()
                    }
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
                .floating()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(4))
                    if store.toast?.id == toast.id { withAnimation { store.toast = nil } }
                }
            }
        }
        .animation(.snappy, value: store.toast)
    }
}

/// The ground of the A1 card in the current look: pale, filled solid, or outlined. An empty card
/// (nothing to do first yet) stays pale in every look.
struct HeroCard: ViewModifier {
    var empty = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let hero = empty ? .pale : Look.current.hero
        content
            .padding(18)
            .background(hero == .solid ? Color.brand : hero == .outline ? Color.white : Color.brand.opacity(empty ? 0.06 : 0.09), in: shape)
            .overlay { if hero == .outline { shape.strokeBorder(Color.brand, lineWidth: 1.5) } }
    }
}

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }

    func heroCard(empty: Bool = false) -> some View { modifier(HeroCard(empty: empty)) }

    /// Liquid Glass on iOS 26 and later; the system material before that.
    @ViewBuilder func floating() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: .capsule)
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }

    /// The tab bar shrinks while you scroll down, where the system supports it (iOS 26).
    @ViewBuilder func minimizingTabBar() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
