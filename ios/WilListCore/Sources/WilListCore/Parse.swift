import Foundation

// Quick add: turns "Calc midterm fri 2pm #math" into a structured item. It is forgiving on
// purpose: anything it does not understand stays in the title.

public enum YearMode: Sendable { case future, nearest }

/// Victim language worth a gentle nudge ("I'll try to…", "I have to…").
public enum Hint: String, Sendable { case tryTo, wish, haveTo, problem }

public struct Parsed: Equatable, Sendable {
    public var title = ""
    public var type: ItemType = .task
    public var date: Day?
    public var time: String?
    public var durationMin: Int?
    public var recur: Recur?
    public var course: String?
    public var priority: Letter?
    public var rank: Int?
    public var weightPct: Double?
    public var hints: [Hint] = []
    /// The text was nothing but dates, times and tags.
    public var bare = false
}

private let weekdays: [String: Int] = [
    "sun": 0, "sunday": 0, "mon": 1, "monday": 1, "tue": 2, "tues": 2, "tuesday": 2,
    "wed": 3, "weds": 3, "wednesday": 3, "thu": 4, "thur": 4, "thurs": 4, "thursday": 4,
    "fri": 5, "friday": 5, "sat": 6, "saturday": 6,
]
private let months: [String: Int] = [
    "jan": 1, "january": 1, "feb": 2, "february": 2, "mar": 3, "march": 3, "apr": 4, "april": 4,
    "may": 5, "jun": 6, "june": 6, "jul": 7, "july": 7, "aug": 8, "august": 8, "sep": 9, "sept": 9,
    "september": 9, "oct": 10, "october": 10, "nov": 11, "november": 11, "dec": 12, "december": 12,
]
// Student timetable shorthand. "tr" is only trusted after "every".
private let shortDays: [String: [Int]] = ["mwf": [1, 3, 5], "mw": [1, 3], "wf": [3, 5], "tth": [2, 4], "tuth": [2, 4], "mtwtf": [1, 2, 3, 4, 5]]
private let counters: Set<String> = ["week", "wk", "unit", "chapter", "chapters", "ch", "lecture", "module", "part", "session", "day", "lab", "quiz", "set", "hw", "test", "exam", "assignment", "problem", "no", "#"]
private let connectors: Set<String> = ["due", "by", "on", "at", "@", "before", "from", "for", "this", "starting", "every", "each"]

public func detectType(_ text: String) -> ItemType {
    let t = text.lowercased()
    func has(_ p: String) -> Bool { matches(t, p) }
    if has(#"\b(present|presentation|presenting|talk|pitch|defen[cs]e|demo|speech|slides|poster session)\b"#) { return .presentation }
    let deliverable = #"\b(report|essay|project|paper|thesis|draft|assignment|portfolio)\b"#
    if has(#"\b(exams?|midterms?|quiz(zes)?|tests?|finals?|oral exam|mock exam)\b"#) && !has(deliverable) { return .exam }
    if has(#"\b(read|reading|skim|chapters?|ch\.?\s?\d+|textbook|article|literature)\b"#) { return .reading }
    if has(#"\b(hw\d*|homework|assignment|essay|project|report|psets?|problem sets?|worksheet|paper|thesis|draft|submit|submission|application|apply|due|portfolio|lab report)\b"#) { return .deadline }
    if has(#"\b(meeting|meet|class|lecture|seminar|tutorial|lab|office hours?|club|practice|rehearsal|call|sync|standup|appointment|interview|recitation|discussion section|study group|training|shift|game)\b"#) { return .event }
    return .task
}

private func clean(_ tok: String) -> String {
    replacing(tok.lowercased(), #"^[("'\[]+|[)"'\].,;:!?]+$"#, with: "")
}

private func int(_ s: String?) -> Int { s.flatMap { Int($0) } ?? 0 }

func upcomingWeekday(_ today: Day, _ wd: Int) -> Day {
    addDays(today, (wd - weekday(today) + 7) % 7)
}

// A year-less date: in quick add, one that already passed means next year. In a pasted
// syllabus ("nearest"), pick whichever year is closest to today, so September dates pasted in
// October stay in the past and get skipped.
func resolveYearless(_ m: Int, _ d: Int, _ today: Day, _ mode: YearMode) -> Day? {
    let y = dayParts(today).y
    guard let iso = makeDay(y, m, d) else { return nil }
    if mode == .nearest {
        return [makeDay(y - 1, m, d), iso, makeDay(y + 1, m, d)].compactMap { $0 }
            .min { abs(diffDays(today, $0)) < abs(diffDays(today, $1)) }
    }
    return diffDays(today, iso) < -7 ? makeDay(y + 1, m, d) : iso
}

private func to24(_ hour: Int, _ min: Int, _ mer: String?) -> String? {
    var h = hour
    if h > 23 || min > 59 { return nil }
    if let mer {
        if h < 1 || h > 12 { return nil }
        if mer == "pm" && h != 12 { h += 12 }
        if mer == "am" && h == 12 { h = 0 }
    }
    return "\(pad(h)):\(pad(min))"
}

// Bare hours without am/pm: 1-6 are almost always afternoon on a student's day.
private func guessHour(_ h: Int) -> Int { h >= 1 && h <= 6 ? h + 12 : h }

private func normMer(_ s: String?) -> String? {
    guard let s, let c = s.first else { return nil }
    return c == "p" ? "pm" : "am"
}

// 2pm, 2:30pm, 11:59pm, 14:00, 9:30
private func parseClock(_ s: String) -> String? {
    if let m = match(s, #"^(\d{1,2})(?::(\d{2}))?(am|pm|a|p)$"#) { return to24(int(m[1]), int(m[2]), normMer(m[3])) }
    if let m = match(s, #"^(\d{1,2}):(\d{2})$"#) {
        let h = int(m[1])
        return to24(h < 13 && m[1]!.count == 1 ? guessHour(h) : h, int(m[2]), nil)
    }
    if s == "noon" { return "12:00" }
    if s == "midnight" { return "23:59" }
    return nil
}

// 2-5pm, 10-10:50am, 3pm-5pm, 15:00-17:00, 11-1pm
private func parseRange(_ s: String) -> (time: String, durationMin: Int)? {
    guard let m = match(s, #"^(\d{1,2})(?::(\d{2}))?(am|pm|a|p)?[-–](\d{1,2})(?::(\d{2}))?(am|pm|a|p)?$"#) else { return nil }
    let a1 = normMer(m[3]), a2 = normMer(m[6])
    if a1 == nil && a2 == nil && m[2] == nil && m[5] == nil { return nil } // "3-5" is probably not a time
    let h1 = int(m[1]), m1 = int(m[2]), h2 = int(m[4]), m2 = int(m[5])
    var start: String?
    var end: String?
    if let a2, a1 == nil {
        end = to24(h2, m2, a2)
        // "11-1pm" starts in the morning; "2-5pm" starts in the afternoon.
        if let tryStart = to24(h1, m1, a2), let end, tryStart <= end { start = tryStart }
        else { start = to24(h1, m1, a2 == "pm" ? "am" : "pm") }
    } else if a1 != nil || a2 != nil {
        start = to24(h1, m1, a1 ?? a2)
        end = to24(h2, m2, a2 ?? a1)
    } else {
        start = to24(h1 < 13 && h1 <= 6 ? h1 + 12 : h1, m1, nil)
        end = to24(h2 < 13 && h2 <= 7 ? h2 + 12 : h2, m2, nil)
    }
    guard let start, let end else { return nil }
    var dur = timeToMin(end)! - timeToMin(start)!
    if dur <= 0 { dur += 1440 }
    return (start, dur)
}

private func minutes(_ amount: String, _ unit: String) -> Int? {
    guard let v = Double(amount), v < 100_000 else { return nil }
    return Int((v * (unit.hasPrefix("h") ? 60 : 1)).rounded())
}

private func parseDuration(_ s: String, _ next: String?) -> (min: Int, used: Int)? {
    if let m = match(s, #"^~?(\d+(?:\.\d+)?)(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)$"#) {
        return minutes(m[1]!, m[2]!).map { ($0, 1) }
    }
    if let m = match(s, #"^~?(\d+(?:\.\d+)?)$"#), let next, matches(next, #"^(h|hr|hrs|hour|hours|min|mins|minutes?)$"#) {
        return minutes(m[1]!, next).map { ($0, 2) }
    }
    return nil
}

private func weekdayOf(_ t: String) -> Int? {
    if let d = weekdays[t] { return d }
    if t.hasSuffix("s") { return weekdays[String(t.dropLast())] }
    return nil
}

public func quickAdd(_ text: String, today: Day, minute: Int = 0, dateOrder: String = "mdy", yearMode: YearMode = .future) -> Parsed {
    let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let orig = raw.split(whereSeparator: \.isWhitespace).map(String.init)
    let norm = orig.map(clean)
    var used = [Bool](repeating: false, count: orig.count)
    var out = Parsed()

    func at(_ k: Int) -> String? { k >= 0 && k < norm.count ? norm[k] : nil }
    // Marks k words from i as understood, with the connector words right in front of them
    // ("due by fri", "at 3pm").
    func take(_ i: Int, _ k: Int) {
        for j in i..<min(i + k, used.count) { used[j] = true }
        var p = i - 1
        while p >= 0, !used[p], connectors.contains(norm[p]) {
            used[p] = true
            p -= 1
        }
    }
    func setDate(_ d: Day?) { if let d, out.date == nil { out.date = d } }

    var i = -1
    while true {
        i += 1
        guard i < orig.count else { break }
        if used[i] { continue }
        let rawTok = orig[i], t = norm[i], n1 = at(i + 1), n2 = at(i + 2)

        if let m = match(rawTok, #"^!([a-e])([1-9])?[.,;]?$"#, ignoreCase: true) {
            out.priority = Letter(rawValue: m[1]!.uppercased())
            out.rank = m[2].flatMap { Int($0) }
            take(i, 1)
            continue
        }
        if let m = match(rawTok, #"^#([\p{L}\p{N}_-]+)[.,;]?$"#) { out.course = m[1]; take(i, 1); continue }

        // Repeats
        switch t {
        case "daily", "everyday": out.recur = Recur(.daily); take(i, 1); continue
        case "weekdays": out.recur = Recur(.weekdays); take(i, 1); continue
        case "weekly": out.recur = Recur(.weekly, days: []); take(i, 1); continue
        case "biweekly", "fortnightly": out.recur = Recur(.biweekly, days: []); take(i, 1); continue
        case "monthly": out.recur = Recur(.monthly); take(i, 1); continue
        default: break
        }
        if t == "every" || t == "each" {
            var j = i + 1
            var other = false
            if at(j) == "other" { other = true; j += 1 }
            var days: [Int] = []
            var k = j
            while k < orig.count {
                let tk = norm[k]
                if let wd = weekdayOf(tk) { days.append(wd); k += 1; continue }
                if let s = shortDays[tk] ?? (tk == "tr" ? [2, 4] : nil) { days += s; k += 1; continue }
                let parts = tk.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                if tk.contains("/"), parts.allSatisfy({ weekdayOf($0) != nil }) { days += parts.compactMap(weekdayOf); k += 1; continue }
                if ["and", "&", ","].contains(tk), !days.isEmpty, let next = at(k + 1), weekdayOf(next) != nil { k += 1; continue }
                break
            }
            if !days.isEmpty {
                out.recur = Recur(other ? .biweekly : .weekly, days: Set(days).sorted())
                take(i, k - i)
                i = k - 1
                continue
            }
            let unitRecur: Recur? = switch at(j) {
            case "day": Recur(.daily)
            case "weekday", "weekdays": Recur(.weekdays)
            case "week": Recur(other ? .biweekly : .weekly, days: [])
            case "month": Recur(.monthly)
            default: nil
            }
            if let unitRecur { out.recur = unitRecur; take(i, j - i + 1); i = j; continue }
        }
        // "tuesdays" repeats; "tues" and "thurs" are just short for the day.
        if weekdays[t] == nil, t.hasSuffix("s"), let wd = weekdays[String(t.dropLast())] {
            out.recur = Recur(.weekly, days: [wd])
            take(i, 1)
            continue
        }
        if let s = shortDays[t] { out.recur = Recur(.weekly, days: s); take(i, 1); continue }

        // Relative dates
        if t == "today" || t == "tonight" {
            setDate(today)
            if t == "tonight" && out.time == nil { out.time = "20:00" }
            take(i, 1)
            continue
        }
        if ["tomorrow", "tmr", "tmrw", "tmw", "tomorow", "tommorow"].contains(t) { setDate(addDays(today, 1)); take(i, 1); continue }
        if t == "next", let n1 {
            // "next fri" is Friday of next week (Monday to Sunday), never tomorrow.
            let nextMonday = upcomingWeekday(addDays(today, 1), 1)
            if let wd = weekdayOf(n1) { setDate(addDays(nextMonday, (wd + 6) % 7)); take(i, 2); i += 1; continue }
            if n1 == "week" { setDate(nextMonday); take(i, 2); i += 1; continue }
        }
        if t == "this" && n1 == "weekend" { setDate(upcomingWeekday(today, 6)); take(i, 2); i += 1; continue }
        if t == "in", let n1, let unit = n2, matches(unit, #"^(days?|weeks?)$"#),
           let num = n1 == "a" || n1 == "an" ? 1 : Int(n1), (1...9999).contains(num) {
            setDate(addDays(today, unit.hasPrefix("week") ? num * 7 : num))
            take(i, 3)
            i += 2
            continue
        }
        if let wd = weekdays[t], out.date == nil { setDate(upcomingWeekday(today, wd)); take(i, 1); continue }

        // Absolute dates
        if let m = match(t, #"^(\d{4})-(\d{1,2})-(\d{1,2})$"#) { setDate(makeDay(int(m[1]), int(m[2]), int(m[3]))); take(i, 1); continue }
        if let m = match(t, #"^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$"#) {
            let (a, b) = (int(m[1]), int(m[2]))
            let (mo, d) = dateOrder == "dmy" ? (b, a) : (a, b)
            let iso = m[3].map { y in makeDay(y.count == 2 ? 2000 + int(y) : int(y), mo, d) } ?? resolveYearless(mo, d, today, yearMode)
            if let iso { setDate(iso); take(i, 1); continue }
        }
        if let mo = months[t], let n1, let dm = match(n1, #"^(\d{1,2})(st|nd|rd|th)?$"#) {
            let year = n2.flatMap { matches($0, #"^\d{4}$"#) ? Int($0) : nil }
            let iso = year != nil ? makeDay(year!, mo, int(dm[1])) : resolveYearless(mo, int(dm[1]), today, yearMode)
            if let iso {
                setDate(iso)
                take(i, year != nil ? 3 : 2)
                i += year != nil ? 2 : 1
                continue
            }
        }
        // "3 sep" is a date, but not in "week 3 sep 15" (counter, then month-day) or "chapter 3 sep…".
        let afterCounter = i > 0 && counters.contains(norm[i - 1])
        let monthDayNext = n2.map { matches($0, #"^\d{1,2}(st|nd|rd|th)?$"#) } ?? false
        if let m = match(t, #"^(\d{1,2})(st|nd|rd|th)?$"#), let n1, let mo = months[n1], !afterCounter, !monthDayNext,
           let iso = resolveYearless(mo, int(m[1]), today, yearMode) {
            setDate(iso)
            take(i, 2)
            i += 1
            continue
        }

        // Times
        if let r = parseRange(t) { out.time = r.time; out.durationMin = r.durationMin; take(i, 1); continue }
        if let c = parseClock(t), out.time == nil { out.time = c; take(i, 1); continue }
        if matches(t, #"^\d{1,2}(?::\d{2})?$"#), let n1, n1 == "am" || n1 == "pm", let c = parseClock(t + n1) {
            out.time = c
            take(i, 2)
            i += 1
            continue
        }
        if matches(t, #"^\d{1,2}$"#), i > 0, norm[i - 1] == "at" || norm[i - 1] == "@", out.time == nil, let h = Int(t), (1...12).contains(h) {
            out.time = "\(pad(guessHour(h))):00"
            take(i, 1)
            continue
        }

        // Share of the final grade: "25%", "(worth 20%)"
        if let m = match(t, #"^(\d{1,3}(?:\.\d+)?)%$"#), let w = Double(m[1]!), w > 0, w <= 100 {
            out.weightPct = w
            take(i, 1)
            if i > 0, !used[i - 1], norm[i - 1] == "worth" { used[i - 1] = true }
            continue
        }

        // Duration, or effort for planned work
        if let d = parseDuration(t, n1), d.min > 0 { out.durationMin = d.min; take(i, d.used); i += d.used - 1; continue }
    }

    // Leftover connector words at the end ("Lab report due") are noise.
    var k = orig.count - 1
    while k >= 0, !used[k], connectors.contains(norm[k]), norm[k] != "for" {
        used[k] = true
        k -= 1
    }

    let title = replacing(zip(orig, used).filter { !$0.1 }.map(\.0).joined(separator: " "), #"^[\s,;:–-]+|[\s,;:–-]+$"#, with: "")
    out.bare = title.isEmpty
    out.title = title.isEmpty ? raw : title
    out.type = detectType(raw)

    if var r = out.recur {
        if (r.freq == .weekly || r.freq == .biweekly) && (r.days ?? []).isEmpty { r.days = [weekday(out.date ?? today)] }
        if out.date == nil {
            if let days = r.days {
                out.date = days.map { upcomingWeekday(today, $0) }.min()
            } else if r.freq == .weekdays {
                var d = today
                while weekday(d) == 0 || weekday(d) == 6 { d = addDays(d, 1) }
                out.date = d
            } else {
                out.date = today
            }
        }
        out.recur = r
        // Repeating things with a time are almost always classes or meetings.
        if out.type == .task && out.time != nil { out.type = .event }
    }
    if let time = out.time, out.date == nil { out.date = timeToMin(time)! >= minute ? today : addDays(today, 1) }

    let low = raw.lowercased()
    if matches(low, #"\b(i[’']?ll try|try to|trying to|attempt to)\b"#) { out.hints.append(.tryTo) }
    if matches(low, #"\b(i wish|wish i)\b"#) { out.hints.append(.wish) }
    if matches(low, #"\b(have to|gotta|got to)\b"#) { out.hints.append(.haveTo) }
    if matches(low, #"\bproblems?\b"#) && !matches(low, "problem sets?") { out.hints.append(.problem) }
    return out
}
