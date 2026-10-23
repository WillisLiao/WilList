import SwiftUI
import WilListCore

// How dates, kinds and rows read everywhere, in the app and on the widgets.

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

    /// A title set large keeps its last two words on one line, so no word is left alone on the
    /// last line ("Write the / lab report", not "Write the lab / report"). Long endings stay free
    /// to wrap. VoiceOver reads the no-break space as a space.
    static func noWidow(_ title: String) -> String {
        let words = title.split(separator: " ")
        guard words.count >= 3, words.suffix(2).joined().count <= 15, let last = title.lastIndex(of: " ") else { return title }
        return title.replacingCharacters(in: last...last, with: "\u{00A0}")
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

    /// Parts of a line under a title, spaced apart; nil when there are none.
    static func meta(_ parts: [Text?]) -> Text? {
        let parts = parts.compactMap { $0 }
        guard var line = parts.first else { return nil }
        for p in parts.dropFirst() { line = Text("\(line)   \(p)") }
        return line
    }

    /// The grey line under an item's title.
    static func subline(_ it: Item, _ today: Day) -> String {
        [when(it, today), it.course].compactMap { $0 }.joined(separator: ", ")
    }

    /// The line under an item's title, its course in the course's colour. The course keeps to the
    /// word before it, so it never wraps onto a line alone.
    static func subline(_ it: Item, _ today: Day, in s: AppState) -> Text? {
        let course = it.course.map { Text($0.replacingOccurrences(of: " ", with: "\u{00A0}")).foregroundStyle(CourseColor.of(s.courseColor($0))) }
        switch (when(it, today).map { Text($0) }, course) {
        case let (when?, course?): return Text("\(when),\u{00A0}\(course)")
        case let (when, course): return when ?? course
        }
    }

    /// `detail`, its course in the course's colour; a study session names its course too, like
    /// the rows around it.
    static func detail(_ row: Row, _ today: Day, in s: AppState) -> Text? {
        if row.session == nil && !(row.item.priority == .D && !row.item.delegateTo.isEmpty) { return subline(row.item, today, in: s) }
        guard let session = row.session, let course = row.item.course else { return detail(row, today).map { Text($0) } }
        // The time and the course keep together: a line too long breaks before "50 min, MATH201",
        // not before the course alone.
        let together = { (words: String) in words.replacingOccurrences(of: " ", with: "\u{00A0}") }
        let time = together(minutes(session.minutes) + (row.extra > 0 ? " (+\(row.extra) more)" : ""))
        let name = Text(together(course)).foregroundStyle(CourseColor.of(s.courseColor(course)))
        return Text("\(session.label), \(time),\u{00A0}\(name)")
    }

    /// What a row of the day's list is about: the study session that is due, who has it, or when it is.
    static func detail(_ row: Row, _ today: Day) -> String? {
        if let s = row.session {
            let more = row.extra > 0 ? " (+\(row.extra) more)" : ""
            return "\(s.label), \(minutes(s.minutes))\(more)"
        }
        if row.item.priority == .D, !row.item.delegateTo.isEmpty { return "Ask \(row.item.delegateTo)" }
        let sub = subline(row.item, today)
        return sub.isEmpty ? nil : sub
    }
}
