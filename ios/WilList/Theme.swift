import SwiftUI
import WilListCore

// Shared pieces: how letters, check-offs, dates and kinds of item look and read everywhere.

/// A letter mark. Letters differ by intensity, not by hue: A is the one filled in the accent,
/// B is outlined in ink, C is grey, D is dashed (someone else does it) and E is struck out.
struct LetterMark: View {
    let letter: Letter?
    var label: String?
    var large = false
    var suggested = false

    var body: some View {
        let text = label ?? letter?.rawValue ?? "–"
        Text(text)
            .font(large ? .headline : .footnote.weight(.semibold))
            .monospacedDigit()
            .strikethrough(letter == .E)
            .foregroundStyle(ink)
            .padding(.horizontal, text.count > 1 ? 6 : 0)
            .frame(minWidth: large ? 40 : 30, minHeight: large ? 32 : 26)
            .background(letter == .A ? Color.accentColor : Color.clear, in: Capsule())
            .overlay {
                if letter != .A {
                    Capsule().strokeBorder(stroke, style: StrokeStyle(lineWidth: suggested ? 2 : 1.25, dash: letter == .D ? [3, 2] : []))
                }
            }
            .accessibilityLabel(letter.map { "Priority \(label ?? $0.rawValue)" } ?? "No letter")
    }

    // Fixed colours, not hierarchical styles: inside a button those pick up the tint, and the
    // letters must read the same everywhere.
    private var ink: Color {
        switch letter {
        case .A: .white
        case .B: .primary
        default: .secondary
        }
    }

    private var stroke: Color {
        if suggested { return .accentColor }
        return letter == .B ? .primary : Color(.tertiaryLabel)
    }
}

extension Letter {
    /// Tracy's meaning of each letter, in plain words.
    var meaning: String {
        switch self {
        case .A: "Must do: serious consequences if it's not done."
        case .B: "Should do: mild consequences."
        case .C: "Nice to do: no consequences either way."
        case .D: "Delegate: someone else can do it."
        case .E: "Eliminate: drop it."
        }
    }
}

/// The round check-off. Filling it plays a success tap.
struct CheckButton: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(done ? Color.accentColor : Color(.tertiaryLabel))
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

    var symbol: String {
        switch self {
        case .task: "checkmark.circle"
        case .deadline: "flag"
        case .exam: "pencil.line"
        case .presentation: "person.wave.2"
        case .reading: "book"
        case .event: "calendar"
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
        let days = (r.days ?? []).map { names[$0] }.joined(separator: ", ")
        return switch r.freq {
        case .daily: "Every day"
        case .weekdays: "Every weekday"
        case .weekly: "Every \(days)"
        case .biweekly: "Every other \(days)"
        case .monthly: "Every month"
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
                .glassEffect(.regular, in: .capsule)
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

extension View {
    func toastHost() -> some View { modifier(ToastHost()) }
}
