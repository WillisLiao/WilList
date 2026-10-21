import Foundation

// Calendar files and feed links from Canvas, Moodle, Blackboard, Google or Outlook (.ics),
// turned into planner items, and merged so a feed read again updates instead of duplicating.

public struct ICSProp: Sendable {
    public var params: [String: String]
    public var value: String
}

public struct ICSComponent: Sendable {
    public var kind: String
    public var props: [String: [ICSProp]]
    func first(_ name: String) -> ICSProp? { props[name]?.first }
}

public func parseICS(_ text: String) -> [ICSComponent] {
    var comps: [ICSComponent] = []
    var cur: ICSComponent?
    for line in replacing(text, #"\r?\n[ \t]"#, with: "").components(separatedBy: .newlines) where !line.isEmpty {
        let upper = line.uppercased()
        if upper == "BEGIN:VEVENT" || upper == "BEGIN:VTODO" { cur = ICSComponent(kind: String(upper.dropFirst(6)), props: [:]); continue }
        if upper == "END:VEVENT" || upper == "END:VTODO" {
            if let c = cur { comps.append(c) }
            cur = nil
            continue
        }
        guard cur != nil else { continue }
        // NAME;PARAM=a;PARAM="b:c":VALUE. The first colon outside quotes ends the name part.
        var quoted = false
        guard let split = line.firstIndex(where: { ch in
            if ch == "\"" { quoted.toggle() }
            return ch == ":" && !quoted
        }) else { continue }
        let head = line[..<split].split(separator: ";", omittingEmptySubsequences: false)
        var params: [String: String] = [:]
        for p in head.dropFirst() {
            if let eq = p.firstIndex(of: "="), eq > p.startIndex {
                params[p[..<eq].uppercased()] = replacing(String(p[p.index(after: eq)...]), #"^"|"$"#, with: "")
            }
        }
        cur!.props[head[0].uppercased(), default: []].append(ICSProp(params: params, value: String(line[line.index(after: split)...])))
    }
    return comps
}

private func unescapeText(_ v: String) -> String {
    replacing(replacing(v, #"\\[nN]"#, with: "\n"), #"\\([,;\\])"#, with: "$1")
}

/// An ICS date or date-time as a local day and time (no time for all-day). UTC and named
/// zones are converted to `calendar`'s zone; floating times and unknown zones keep the wall time.
public func icsDateTime(_ prop: ICSProp?, calendar: Calendar = .current) -> (date: Day, time: String?)? {
    guard let prop, let m = match(prop.value.trimmingCharacters(in: .whitespaces), #"^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$"#),
          let day = makeDay(Int(m[1]!)!, Int(m[2]!)!, Int(m[3]!)!) else { return nil }
    guard let hh = m[4], prop.params["VALUE"] != "DATE" else { return (day, nil) }
    let (h, mi) = (Int(hh)!, Int(m[5]!)!)
    guard h < 24, mi < 60 else { return nil }
    let zone = m[7] != nil ? TimeZone(identifier: "UTC") : prop.params["TZID"].flatMap { TimeZone(identifier: $0) }
    var source = Calendar(identifier: .gregorian)
    guard let zone else { return (day, "\(pad(h)):\(pad(mi))") }
    source.timeZone = zone
    let p = dayParts(day)
    guard let instant = source.date(from: DateComponents(year: p.y, month: p.m, day: p.d, hour: h, minute: mi, second: Int(m[6] ?? "0"))) else { return nil }
    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
    return ("\(c.year!)-\(pad(c.month!))-\(pad(c.day!))", "\(pad(c.hour!)):\(pad(c.minute!))")
}

private func durationProp(_ v: String?) -> Int? {
    guard let v, let m = match(v, #"^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?"#) else { return nil }
    let n = (Int(m[1] ?? "0") ?? 0) * 1440 + (Int(m[2] ?? "0") ?? 0) * 60 + (Int(m[3] ?? "0") ?? 0)
    return n > 0 ? n : nil
}

private let byDay = ["SU": 0, "MO": 1, "TU": 2, "WE": 3, "TH": 4, "FR": 5, "SA": 6]

/// An RRULE as a WilList repeat, or nil for rules WilList can't show (yearly, every third week…).
public func mapRRule(_ value: String, start: Day, calendar: Calendar = .current) -> Recur? {
    var r: [String: String] = [:]
    for kv in value.split(separator: ";") {
        let p = kv.split(separator: "=", maxSplits: 1)
        if p.count == 2 { r[p[0].uppercased()] = String(p[1]) }
    }
    let interval = Int(r["INTERVAL"] ?? "1") ?? 1
    let until = r["UNTIL"].flatMap { icsDateTime(ICSProp(params: [:], value: $0), calendar: calendar)?.date }
    let days = (r["BYDAY"] ?? "").split(separator: ",").compactMap { byDay[String($0.suffix(2))] }
    var rec: Recur?
    if r["FREQ"] == "DAILY" && interval == 1 { rec = Recur(.daily) }
    if r["FREQ"] == "WEEKLY" && interval <= 2 {
        let set = Set(days.isEmpty ? [weekday(start)] : days).sorted()
        rec = interval == 1 && set == [1, 2, 3, 4, 5] ? Recur(.weekdays) : Recur(interval == 2 ? .biweekly : .weekly, days: set)
    }
    if r["FREQ"] == "MONTHLY" && interval == 1 && !matches(r["BYDAY"] ?? "", #"\d"#) { rec = Recur(.monthly) }
    guard var rec else { return nil }
    if let until {
        rec.until = until
    } else if let count = r["COUNT"].flatMap({ Int($0) }), count > 0 {
        // Last day that still holds the final occurrence.
        let span = switch rec.freq {
        case .daily: count - 1
        case .monthly: (count - 1) * 31 + 1
        default: 7 * interval * Int((Double(count) / Double(rec.days?.count ?? 5)).rounded(.up)) - 1
        }
        rec.until = addDays(start, span)
    }
    return rec
}

/// "MATH 201 Fall 2026" → "MATH201"; anything else is shortened.
public func courseCode(_ s: String?) -> String? {
    guard let s, !s.isEmpty else { return nil }
    if let m = match(s, #"\b([A-Z]{2,5})[\s-]?(\d{2,4}[A-Z]?)\b"#) { return m[1]! + m[2]! }
    let t = s.trimmingCharacters(in: .whitespaces)
    return t.count > 24 ? t.prefix(23) + "…" : t
}

private func stripHtml(_ s: String) -> String {
    var t = replacing(s, "<[^>]+>", with: " ")
    t = t.replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
    return replacing(t, #"[ \t]+"#, with: " ").trimmingCharacters(in: .whitespaces)
}

/// One calendar entry as an item draft, or why it was left out.
public enum ICSEntry: Sendable {
    public enum Skip: Sendable { case empty, noise, noDate, past, done }
    case item(Item)
    case skipped(Skip)
}

public func icsEntry(_ comp: ICSComponent, today: Day, calendar: Calendar = .current) -> ICSEntry {
    func skip(_ s: ICSEntry.Skip) -> ICSEntry { .skipped(s) }
    let summary = unescapeText(comp.first("SUMMARY")?.value ?? "").trimmingCharacters(in: .whitespaces)
    if summary.isEmpty { return skip(.empty) }
    // LMS noise: Moodle "Quiz 3 opens" and similar availability windows.
    if matches(summary, #"\b(opens|is open|available)$"#, ignoreCase: true) { return skip(.noise) }
    var title = summary
    var course: String?
    if let b = match(title, #"^(.*?)\s*\[([^\]]+)\]\s*$"#) { // Canvas: "Essay 2 [HIST 150 Fall]"
        title = b[1]!
        course = courseCode(b[2])
    }
    title = replacing(title, #"^(?:assignment|assessment)\s+due:\s*"#, with: "", ignoreCase: true)
    title = replacing(title, #"\s+(?:is due|closes|due)\.?$"#, with: "", ignoreCase: true).trimmingCharacters(in: .whitespaces)
    if course == nil, let cats = comp.first("CATEGORIES") {
        course = courseCode(unescapeText(cats.value).split(separator: ",").first.map(String.init))
    }

    guard let start = icsDateTime(comp.first("DUE"), calendar: calendar) ?? icsDateTime(comp.first("DTSTART"), calendar: calendar) else { return skip(.noDate) }
    let end = icsDateTime(comp.first("DTEND"), calendar: calendar)
    var durationMin = durationProp(comp.first("DURATION")?.value)
    if durationMin == nil, let s = timeToMin(start.time), let e = timeToMin(end?.time) {
        durationMin = diffDays(start.date, end!.date) * 1440 + e - s
    }
    let recur = comp.first("RRULE").flatMap { mapRRule($0.value, start: start.date, calendar: calendar) }
    let skips = (comp.props["EXDATE"] ?? []).flatMap { x in
        x.value.split(separator: ",").compactMap { icsDateTime(ICSProp(params: x.params, value: String($0)), calendar: calendar)?.date }
    }
    if let until = recur?.until, diffDays(today, until) < 0 { return skip(.past) }
    if recur == nil && diffDays(today, start.date) < 0 { return skip(.past) }
    if comp.kind == "VTODO" && matches(comp.first("STATUS")?.value ?? "", "COMPLETED", ignoreCase: true) { return skip(.done) }

    var type = detectType(title)
    let uid = comp.first("UID")?.value ?? ""
    let assignment = comp.kind == "VTODO" || matches(uid, "assignment|submission", ignoreCase: true)
    if assignment && (type == .task || type == .event) { type = .deadline }
    if type == .task {
        if recur != nil || (durationMin ?? 0) >= 15 { type = .event }
        else if start.time != nil { type = .deadline }
    }
    let desc = stripHtml(unescapeText(comp.first("DESCRIPTION")?.value ?? ""))
    var it = Item(id: "", title: title.isEmpty ? summary : title, type: type)
    it.externalId = uid.isEmpty ? nil : "ics:\(uid)"
    it.course = course
    it.date = start.date
    it.time = start.time
    it.durationMin = type == .event ? ((durationMin ?? 0) > 0 ? durationMin : 60) : nil
    it.recur = type == .event || type == .task ? recur : nil
    it.skips = skips
    it.notes = desc.count > 400 ? desc.prefix(400) + "…" : desc
    return .item(it)
}

public struct ICSImport: Sendable {
    public var items: [Item] = []
    /// Entries already over or ticked off.
    public var past = 0
    /// Entries WilList could not use.
    public var ignored = 0
}

public func importICS(_ text: String, today: Day, calendar: Calendar = .current) -> ICSImport {
    var out = ICSImport()
    for c in parseICS(text) {
        switch icsEntry(c, today: today, calendar: calendar) {
        case .item(let it): out.items.append(it)
        case .skipped(.past), .skipped(.done): out.past += 1
        case .skipped: out.ignored += 1
        }
    }
    return out
}

// MARK: merge

public struct ImportPlan: Equatable, Sendable {
    public struct Update: Equatable, Sendable {
        public enum Field: Sendable { case title, date, time, course, recur }
        public var id: String
        public var title: String
        public var incoming: Item
        public var fields: Set<Field>
    }
    public var adds: [Item] = []
    public var updates: [Update] = []
    public var same = 0
    public var isEmpty: Bool { adds.isEmpty && updates.isEmpty }
}

/// What an import would change, so it can be confirmed first. Calendar entries are matched on
/// their calendar ID, so reading a feed again updates them; anything else on title and date.
/// The calendar owns names and dates; your letter, type and plan stay yours.
public func planImport(_ items: [Item], _ incoming: [Item]) -> ImportPlan {
    var plan = ImportPlan()
    func key(_ t: String) -> String { t.trimmingCharacters(in: .whitespaces).lowercased() }
    for inc in incoming {
        let existing = inc.externalId != nil
            ? items.first { $0.externalId == inc.externalId }
            : items.first { $0.date == inc.date && key($0.title) == key(inc.title) }
        guard let existing else { plan.adds.append(inc); continue }
        var fields = Set<ImportPlan.Update.Field>()
        if inc.externalId != nil {
            if inc.title != existing.title { fields.insert(.title) }
            if inc.date != existing.date { fields.insert(.date) }
            if inc.time != existing.time { fields.insert(.time) }
            if inc.course != existing.course { fields.insert(.course) }
            if inc.recur != existing.recur { fields.insert(.recur) }
        }
        if fields.isEmpty { plan.same += 1 }
        else { plan.updates.append(.init(id: existing.id, title: existing.title, incoming: inc, fields: fields)) }
    }
    return plan
}

extension AppState {
    @discardableResult
    public mutating func applyImport(_ plan: ImportPlan, today: Day) -> Int {
        for u in plan.updates {
            guard let i = index(of: u.id) else { continue }
            for f in u.fields {
                switch f {
                case .title: items[i].title = u.incoming.title
                case .date: items[i].date = u.incoming.date
                case .time: items[i].time = u.incoming.time
                case .course: items[i].course = u.incoming.course
                case .recur: items[i].recur = u.incoming.recur
                }
            }
            if u.fields.contains(.date) && !items[i].done { replan(u.id, today: today) }
        }
        for f in plan.adds { items.append(makeItem(f, settings, today, items)) }
        return plan.adds.count + plan.updates.count
    }
}
